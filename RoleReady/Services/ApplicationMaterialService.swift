import Foundation
import SwiftData

struct JobRequirementSnapshot: Hashable, Sendable {
    let id: UUID
    let text: String
    let keywords: [String]
    let capabilities: [String]
    let importance: Int
}

struct CareerEvidenceSnapshot: Hashable, Sendable {
    let id: UUID
    let title: String
    let organisation: String
    let bullets: [String]
    let skills: [String]
    let capabilities: [String]

    var searchableText: String {
        ([title, organisation] + bullets + skills + capabilities).joined(separator: " ")
    }
}

struct TailoringRequest: Hashable, Sendable {
    let jobTitle: String
    let organisation: String
    let requirements: [JobRequirementSnapshot]
    let evidence: [CareerEvidenceSnapshot]
    let baseline: ResumeDocument
}

struct TailoringResult: Hashable, Sendable {
    let document: ResumeDocument
    let report: TailoringReport
}

struct TruthfulTailoringService: Sendable {
    func tailor(_ request: TailoringRequest) -> TailoringResult {
        let matches = request.requirements
            .sorted { $0.importance > $1.importance }
            .map { match($0, evidence: request.evidence) }
        let weights = Dictionary(matches.flatMap { match in
            match.sourceEntityIDs.map { ($0, weight(match.classification)) }
        }, uniquingKeysWith: max)

        var document = request.baseline
        if let experienceIndex = document.sections.firstIndex(where: { $0.kind == .experience }) {
            document.sections[experienceIndex].items.sort { lhs, rhs in
                itemWeight(lhs, weights: weights) > itemWeight(rhs, weights: weights)
            }
            for itemIndex in document.sections[experienceIndex].items.indices {
                document.sections[experienceIndex].items[itemIndex].bullets.sort { lhs, rhs in
                    bulletWeight(lhs, matches: matches) > bulletWeight(rhs, matches: matches)
                }
            }
        }
        if !request.jobTitle.isEmpty {
            document.headline = request.baseline.headline
        }

        let directCount = matches.filter { $0.classification == .direct }.count
        let transferableCount = matches.filter { $0.classification == .transferable }.count
        let unsupportedCount = matches.filter { $0.classification == .noEvidence }.count
        var changes = [
            "Prioritised approved experience using \(directCount) direct and \(transferableCount) transferable evidence matches.",
            "Reordered existing approved bullets; no employer, date, tool, metric or outcome was added."
        ]
        if unsupportedCount > 0 {
            changes.append("Left \(unsupportedCount) requirement\(unsupportedCount == 1 ? "" : "s") unsupported and created follow-up questions instead of forcing a match.")
        }
        let report = TailoringReport(
            matches: matches,
            changeSummary: changes,
            validationWarnings: matches.compactMap { match in
                match.classification == .noEvidence ? "No approved evidence for: \(match.requirement)" : nil
            },
            generator: "RoleReady deterministic tailoring v1",
            generatedAt: Date()
        )
        return TailoringResult(document: document, report: report)
    }

    private func match(
        _ requirement: JobRequirementSnapshot,
        evidence: [CareerEvidenceSnapshot]
    ) -> TailoringEvidenceMatch {
        let requirementTokens = tokens(([requirement.text] + requirement.keywords).joined(separator: " "))
        let ranked = evidence.map { item -> (CareerEvidenceSnapshot, Int, Bool, Bool) in
            let itemTokens = tokens(item.searchableText)
            let overlap = requirementTokens.intersection(itemTokens).count
            let exactSkill = item.skills.contains { skill in
                let lower = skill.lowercased()
                return requirement.text.lowercased().contains(lower)
                    || requirement.keywords.contains { $0.localizedCaseInsensitiveCompare(skill) == .orderedSame }
            }
            let transferable = !Set(requirement.capabilities).isDisjoint(with: Set(item.capabilities))
            return (item, overlap, exactSkill, transferable)
        }.sorted { lhs, rhs in
            let left = lhs.1 + (lhs.2 ? 4 : 0) + (lhs.3 ? 2 : 0)
            let right = rhs.1 + (rhs.2 ? 4 : 0) + (rhs.3 ? 2 : 0)
            return left > right
        }
        guard let best = ranked.first else {
            return unsupported(requirement)
        }
        let classification: EvidenceClassification
        if best.2 || best.1 >= 3 {
            classification = .direct
        } else if best.3 {
            classification = .transferable
        } else if best.1 >= 1 {
            classification = .partial
        } else {
            return unsupported(requirement)
        }

        let excerpts = best.0.bullets.filter { bullet in
            !requirementTokens.isDisjoint(with: tokens(bullet))
        }
        let selectedExcerpts = Array((excerpts.isEmpty ? best.0.bullets : excerpts).prefix(3))
        let reason: String
        switch classification {
        case .direct:
            reason = "Approved evidence uses the same skill or responsibility language."
        case .transferable:
            reason = "Approved evidence demonstrates a closely related capability, but not the exact context."
        case .partial:
            reason = "There is limited overlap. Keep the wording narrow and verify the connection yourself."
        case .noEvidence:
            reason = "No approved evidence supports this requirement."
        }
        return TailoringEvidenceMatch(
            requirementID: requirement.id,
            requirement: requirement.text,
            classification: classification,
            sourceEntityIDs: [best.0.id],
            sourceExcerpts: selectedExcerpts,
            reason: reason,
            followUpQuestion: classification == .partial
                ? "Have you used this skill in another role, project, study or volunteer setting? What did you personally do?"
                : nil
        )
    }

    private func unsupported(_ requirement: JobRequirementSnapshot) -> TailoringEvidenceMatch {
        TailoringEvidenceMatch(
            requirementID: requirement.id,
            requirement: requirement.text,
            classification: .noEvidence,
            sourceEntityIDs: [],
            sourceExcerpts: [],
            reason: "No approved career record supports this requirement.",
            followUpQuestion: "Have you done anything comparable at work, in a project, through study or volunteering? Describe only what you personally did."
        )
    }

    private func tokens(_ value: String) -> Set<String> {
        let stop: Set<String> = ["and", "the", "with", "for", "from", "that", "this", "you", "your", "our", "will", "have", "has", "into", "using", "role", "work", "experience", "ability", "skills", "strong"]
        let values = value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stop.contains($0) }
            .map(stem)
        return Set(values)
    }

    private func stem(_ value: String) -> String {
        for suffix in ["ing", "ed", "es", "s"] where value.count > suffix.count + 3 && value.hasSuffix(suffix) {
            return String(value.dropLast(suffix.count))
        }
        return value
    }

    private func weight(_ classification: EvidenceClassification) -> Int {
        switch classification {
        case .direct: 4
        case .transferable: 3
        case .partial: 1
        case .noEvidence: 0
        }
    }

    private func itemWeight(_ item: ResumeItem, weights: [UUID: Int]) -> Int {
        item.sourceEntityIDs.map { weights[$0, default: 0] }.max() ?? 0
    }

    private func bulletWeight(_ bullet: ResumeBullet, matches: [TailoringEvidenceMatch]) -> Int {
        matches.filter { match in
            !Set(match.sourceEntityIDs).isDisjoint(with: Set(bullet.sourceEntityIDs))
                && match.sourceExcerpts.contains(where: { $0.localizedCaseInsensitiveContains(bullet.text) || bullet.text.localizedCaseInsensitiveContains($0) })
        }.map { weight($0.classification) }.max() ?? 0
    }
}

struct CoverLetterDraftRequest: Hashable, Sendable {
    let candidateName: String
    let roleTitle: String
    let organisation: String
    let motivation: String
    let tone: String
    let targetWords: Int
    let requirements: [JobRequirementSnapshot]
    let evidence: [CareerEvidenceSnapshot]
}

struct GroundedCoverLetterResult: Hashable, Sendable {
    let body: String
    let grounding: CoverLetterGrounding
    let sourceEntityIDs: [UUID]
}

struct GroundedCoverLetterService: Sendable {
    func generate(_ request: CoverLetterDraftRequest) -> GroundedCoverLetterResult {
        let target = min(max(request.targetWords, 250), 400)
        var paragraphs: [GroundedParagraph] = []
        let introduction = introductionText(request)
        paragraphs.append(GroundedParagraph(text: introduction, claimType: "motivation"))

        let relevant = rankedEvidence(request.evidence, requirements: request.requirements)
        for item in relevant.prefix(3) {
            guard !item.bullets.isEmpty else { continue }
            var sentences = ["In my work as \(item.title) at \(item.organisation), I \(lowercasedOpening(item.bullets[0]))"]
            for bullet in item.bullets.dropFirst().prefix(2) {
                sentences.append("I also \(lowercasedOpening(bullet))")
            }
            if let requirement = closestRequirement(to: item, requirements: request.requirements) {
                sentences.append("That approved experience is relevant to your need for \(lowercasedOpening(requirement.text))")
            }
            paragraphs.append(GroundedParagraph(
                text: sentences.map(ensureSentence).joined(separator: " "),
                sourceEntityIDs: [item.id],
                claimType: "career evidence"
            ))
            if wordCount(paragraphs.map(\.text).joined(separator: "\n\n")) >= target - 45 { break }
        }

        let closing = "I would welcome the opportunity to discuss how this verified experience could help \(request.organisation.isEmpty ? "your team" : request.organisation). Thank you for considering my application for \(request.roleTitle.isEmpty ? "the role" : "the \(request.roleTitle) role")."
        paragraphs.append(GroundedParagraph(text: closing, claimType: "closing"))
        let body = paragraphs.map(\.text).joined(separator: "\n\n")
        var warnings = ClaimValidationService().validate(
            generatedText: body,
            approvedSources: request.evidence.flatMap { [$0.title, $0.organisation] + $0.bullets + $0.skills },
            allowedContext: [request.roleTitle, request.organisation, request.motivation] + request.requirements.map(\.text)
        )
        let count = wordCount(body)
        if count < 230 {
            warnings.append("The letter is \(count) words because there is not enough approved evidence for a safe 250-word draft. Add or approve more career detail rather than padding it.")
        }
        let grounding = CoverLetterGrounding(
            paragraphs: paragraphs,
            generator: "RoleReady deterministic cover letter v1",
            generatedAt: Date(),
            validationWarnings: warnings
        )
        return GroundedCoverLetterResult(
            body: body,
            grounding: grounding,
            sourceEntityIDs: Array(Set(paragraphs.flatMap(\.sourceEntityIDs)))
        )
    }

    private func introductionText(_ request: CoverLetterDraftRequest) -> String {
        let role = request.roleTitle.isEmpty ? "this opportunity" : "the \(request.roleTitle) role"
        let organisation = request.organisation.isEmpty ? "your organisation" : request.organisation
        let motivation = request.motivation.trimmingCharacters(in: .whitespacesAndNewlines)
        if motivation.isEmpty {
            return "I am applying for \(role) at \(organisation). The responsibilities in the advertisement align with approved experience I would value the opportunity to discuss."
        }
        return "I am applying for \(role) at \(organisation). \(ensureSentence(motivation))"
    }

    private func rankedEvidence(
        _ evidence: [CareerEvidenceSnapshot],
        requirements: [JobRequirementSnapshot]
    ) -> [CareerEvidenceSnapshot] {
        let requirementText = requirements.flatMap { [$0.text] + $0.keywords }.joined(separator: " ").lowercased()
        return evidence.sorted { lhs, rhs in
            score(lhs.searchableText, against: requirementText) > score(rhs.searchableText, against: requirementText)
        }
    }

    private func closestRequirement(
        to evidence: CareerEvidenceSnapshot,
        requirements: [JobRequirementSnapshot]
    ) -> JobRequirementSnapshot? {
        requirements.max { lhs, rhs in
            score(evidence.searchableText, against: lhs.text) < score(evidence.searchableText, against: rhs.text)
        }
    }

    private func score(_ source: String, against target: String) -> Int {
        let sourceWords = Set(source.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 3 })
        let targetWords = Set(target.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count > 3 })
        return sourceWords.intersection(targetWords).count
    }

    private func lowercasedOpening(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }

    private func ensureSentence(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = clean.last, !".!?".contains(last) else { return clean }
        return clean + "."
    }

    private func wordCount(_ value: String) -> Int {
        value.split(whereSeparator: \.isWhitespace).count
    }
}

struct ClaimValidationService: Sendable {
    func validate(
        generatedText: String,
        approvedSources: [String],
        allowedContext: [String] = []
    ) -> [String] {
        let corpus = (approvedSources + allowedContext).joined(separator: " ").lowercased()
        var warnings: [String] = []
        for number in matches(#"(?<![A-Za-z])(?:\d+(?:[.,]\d+)?%?)"#, in: generatedText) {
            if !corpus.contains(number.lowercased()) {
                warnings.append("Unsupported number or metric: \(number)")
            }
        }
        let ownershipWords = ["led", "owned", "managed", "directed", "supervised"]
        for word in ownershipWords where containsWord(word, in: generatedText) && !containsWord(word, in: corpus) {
            warnings.append("Ownership word needs approved evidence: \(word)")
        }
        let technologies = ["Swift", "Python", "Java", "Kotlin", "React", "AWS", "Azure", "GCP", "SQL", "Docker", "Kubernetes", "Terraform", "Salesforce", "SAP"]
        for technology in technologies where containsWord(technology, in: generatedText) && !containsWord(technology, in: corpus) {
            warnings.append("Technology needs approved evidence: \(technology)")
        }
        return Array(Set(warnings)).sorted()
    }

    private func matches(_ pattern: String, in value: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: value, range: NSRange(value.startIndex..., in: value)).compactMap { match in
            Range(match.range, in: value).map { String(value[$0]) }
        }
    }

    private func containsWord(_ word: String, in value: String) -> Bool {
        value.range(of: #"\b"# + NSRegularExpression.escapedPattern(for: word) + #"\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
}

@MainActor
struct CareerApplicationService {
    func makeTailoredResume(
        baseline: ResumeVersion,
        opportunity: Opportunity,
        requirements: [JobRequirement],
        positions: [CareerPosition],
        skills: [CareerSkill],
        in context: ModelContext
    ) throws -> ResumeVersion {
        let request = TailoringRequest(
            jobTitle: opportunity.roleTitle,
            organisation: opportunity.organisation,
            requirements: requirements.filter(\.isConfirmed).map(snapshot),
            evidence: evidenceSnapshots(positions: positions, skills: skills),
            baseline: baseline.document
        )
        let result = TruthfulTailoringService().tailor(request)
        let version = ResumeVersion(
            parentVersionID: baseline.id,
            sourceID: baseline.sourceID,
            opportunityID: opportunity.id,
            name: "\(opportunity.roleTitle) · \(opportunity.organisation)",
            targetRole: opportunity.roleTitle,
            targetOrganisation: opportunity.organisation,
            template: baseline.template,
            document: result.document,
            tailoringReport: result.report
        )
        context.insert(version)
        try context.save()
        return version
    }

    func makeCoverLetter(
        opportunity: Opportunity,
        resume: ResumeVersion?,
        requirements: [JobRequirement],
        positions: [CareerPosition],
        skills: [CareerSkill],
        profile: CareerProfile?,
        motivation: String,
        tone: String,
        targetWords: Int,
        in context: ModelContext
    ) throws -> CoverLetter {
        let result = GroundedCoverLetterService().generate(CoverLetterDraftRequest(
            candidateName: profile?.name ?? "",
            roleTitle: opportunity.roleTitle,
            organisation: opportunity.organisation,
            motivation: motivation,
            tone: tone,
            targetWords: targetWords,
            requirements: requirements.filter(\.isConfirmed).map(snapshot),
            evidence: evidenceSnapshots(positions: positions, skills: skills)
        ))
        let letter = CoverLetter(
            opportunityID: opportunity.id,
            resumeVersionID: resume?.id,
            title: "\(opportunity.roleTitle) cover letter",
            body: result.body,
            grounding: result.grounding,
            generator: result.grounding.generator,
            validationWarnings: result.grounding.validationWarnings,
            sourceEntityIDs: result.sourceEntityIDs
        )
        context.insert(letter)
        try context.save()
        return letter
    }

    private func snapshot(_ requirement: JobRequirement) -> JobRequirementSnapshot {
        JobRequirementSnapshot(
            id: requirement.id,
            text: requirement.text,
            keywords: requirement.keywords,
            capabilities: requirement.capabilities.map(\.rawValue),
            importance: requirement.importance
        )
    }

    private func evidenceSnapshots(
        positions: [CareerPosition],
        skills: [CareerSkill]
    ) -> [CareerEvidenceSnapshot] {
        let approvedSkills = skills.filter { $0.verificationStatus.permitsGeneration }
        let positionEvidence = positions.filter { $0.verificationStatus.permitsGeneration }.map { position in
            let inferredCapabilities = TextAnalyzer().inferCapabilities(from: ([position.title] + position.bullets).joined(separator: " "))
            return CareerEvidenceSnapshot(
                id: position.id,
                title: position.title,
                organisation: position.organisation,
                bullets: position.bullets,
                skills: position.skills,
                capabilities: inferredCapabilities.map(\.rawValue)
            )
        }
        let skillEvidence = approvedSkills.map { skill in
            CareerEvidenceSnapshot(
                id: skill.id,
                title: skill.name,
                organisation: "Approved skill",
                bullets: skill.sourceExcerpt.isEmpty ? [] : [skill.sourceExcerpt],
                skills: [skill.name],
                capabilities: TextAnalyzer().inferCapabilities(from: skill.name).map(\.rawValue)
            )
        }
        return positionEvidence + skillEvidence
    }
}
