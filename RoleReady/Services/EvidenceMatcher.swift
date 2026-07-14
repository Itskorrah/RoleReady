import Foundation

enum MatchTier: String, Codable, Sendable {
    case direct
    case transferable
    case weak
    case none

    var title: String {
        switch self {
        case .direct: "Direct evidence"
        case .transferable: "Transferable"
        case .weak: "Weak or partial"
        case .none: "No verified evidence"
        }
    }

    var allowsAnswer: Bool {
        self == .direct || self == .transferable
    }
}

struct MatchFactors: Hashable {
    let lexical: Double
    let capability: Double
    let tools: Double
    let readiness: Double
    let recency: Double
    let ownership: Double
}

struct EvidenceMatch: Identifiable, Hashable {
    let id: UUID
    let requirementID: UUID
    let experienceID: UUID
    let score: Double
    let tier: MatchTier
    let matchedTerms: [String]
    let matchedCapabilities: [Capability]
    let factors: MatchFactors
    let explanation: String
    let cautions: [String]
}

struct EvidenceMatcher {
    private let analyzer = TextAnalyzer()
    private let scorer = EvidenceScorer()

    func rank(
        requirement: JobRequirement,
        against experiences: [Experience],
        now: Date = Date(),
        explicitlyApprovedSensitiveExperienceIDs: Set<UUID> = []
    ) -> [EvidenceMatch] {
        let requirementSource = requirement.text + " " + requirement.keywords.joined(separator: " ")
        let requirementTerms = Set(analyzer.tokens(in: requirementSource))
        let inferredCapabilities = Set(requirement.capabilities.isEmpty ? analyzer.inferCapabilities(from: requirement.text) : requirement.capabilities)

        return experiences.compactMap { experience -> EvidenceMatch? in
            guard experience.isApprovedForMatching else { return nil }
            guard !experience.confidentiality.blocksAutomaticUse
                    || explicitlyApprovedSensitiveExperienceIDs.contains(experience.id) else { return nil }
            let weightedText = [
                experience.actions.joined(separator: " "),
                experience.actions.joined(separator: " "),
                experience.result,
                experience.result,
                experience.evidence,
                experience.task,
                experience.tools.joined(separator: " "),
                experience.situation
            ].joined(separator: " ")
            let experienceTerms = Set(analyzer.tokens(in: weightedText))
            let overlap = requirementTerms.intersection(experienceTerms).sorted()
            let displayOverlap = readableTerms(for: overlap, in: requirementSource)
            let unionCount = max(requirementTerms.union(experienceTerms).count, 1)
            let lexical = (
                min(Double(overlap.count) / Double(max(min(requirementTerms.count, 10), 1)) * 1.4, 1) * 0.8
                    + Double(overlap.count) / Double(unionCount) * 0.2
            )
            let capabilityMatches = inferredCapabilities.intersection(Set(experience.capabilities)).sorted { $0.title < $1.title }
            let capability = inferredCapabilities.isEmpty ? 0 : Double(capabilityMatches.count) / Double(inferredCapabilities.count)
            let toolTokens = Set(experience.tools.flatMap { analyzer.tokens(in: $0) })
            let matchedToolTerms = requirementTerms.intersection(toolTokens)
            let tools = requirementTerms.isEmpty ? 0 : min(Double(matchedToolTerms.count) / 2, 1)
            let readiness = Double(scorer.score(experience).total) / 100
            let years = max(now.timeIntervalSince(experience.occurredAt) / 31_557_600, 0)
            let recency = max(0.45, 1 - min(years, 8) * 0.07)
            let ownership: Double
            switch experience.ownership {
            case .led, .owned: ownership = 1
            case .contributed: ownership = 0.72
            case .supported: ownership = 0.52
            }
            let factors = MatchFactors(
                lexical: lexical,
                capability: capability,
                tools: tools,
                readiness: readiness,
                recency: recency,
                ownership: ownership
            )
            let rawScore = lexical * 0.40 + capability * 0.20 + tools * 0.12 + readiness * 0.16 + recency * 0.06 + ownership * 0.06
            let hasLexicalSignal = overlap.count >= 2 || lexical >= 0.2
            let hasStrongLexicalSignal = overlap.count >= 3 || (overlap.count >= 2 && lexical >= 0.35)
            let hasCapabilitySignal = !capabilityMatches.isEmpty
            let hasToolSignal = !matchedToolTerms.isEmpty
            let hasRelevantSignal = hasLexicalSignal || hasCapabilitySignal || hasToolSignal
            let score = hasRelevantSignal ? rawScore : 0
            let tier: MatchTier
            if !hasRelevantSignal {
                tier = .none
            } else if capability >= 0.66,
                      score >= 0.56,
                      hasStrongLexicalSignal || (hasLexicalSignal && hasToolSignal) {
                tier = .direct
            } else if hasCapabilitySignal, (hasLexicalSignal || hasToolSignal || capability >= 0.5), score >= 0.36 {
                tier = .transferable
            } else {
                tier = .weak
            }
            var cautions: [String] = []
            let evidenceScore = scorer.score(experience)
            if evidenceScore.total < 56 { cautions.append("Strengthen this story before relying on it in an interview.") }
            if experience.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { cautions.append("The outcome is not recorded yet.") }
            if experience.ownership == .supported { cautions.append("Keep the wording clear that you supported this work.") }
            if experience.confidentiality >= .confidential { cautions.append("Review confidential detail before using this story.") }

            let explanation = explanation(
                title: experience.title,
                overlap: displayOverlap,
                capabilities: capabilityMatches,
                readiness: evidenceScore.readiness,
                tier: tier
            )
            return EvidenceMatch(
                id: experience.id,
                requirementID: requirement.id,
                experienceID: experience.id,
                score: score,
                tier: tier,
                matchedTerms: displayOverlap,
                matchedCapabilities: capabilityMatches,
                factors: factors,
                explanation: explanation,
                cautions: cautions
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.experienceID.uuidString < rhs.experienceID.uuidString }
            return lhs.score > rhs.score
        }
    }

    private func readableTerms(for stems: [String], in source: String) -> [String] {
        let stemSet = Set(stems)
        var seen: Set<String> = []
        return analyzer.surfaceTokens(in: source).compactMap { surface in
            guard let stem = analyzer.tokens(in: surface, includeStopWords: true).first,
                  stemSet.contains(stem),
                  seen.insert(stem).inserted else { return nil }
            return surface
        }
    }

    private func explanation(
        title: String,
        overlap: [String],
        capabilities: [Capability],
        readiness: EvidenceReadiness,
        tier: MatchTier
    ) -> String {
        let terms = overlap.prefix(4).joined(separator: ", ")
        let capabilityText = capabilities.prefix(2).map(\.title).joined(separator: " and ")
        if tier == .none {
            return "No verified detail in “\(title)” directly supports this requirement. Keep the gap visible or add a real example."
        }
        if tier == .weak {
            return "“\(title)” shares limited wording, but it does not yet contain enough verified detail to rely on for this requirement."
        }
        if !terms.isEmpty, !capabilityText.isEmpty {
            let fit = tier == .direct ? "directly supports" : "can transfer to"
            return "“\(title)” \(fit) \(capabilityText.lowercased()) and shares verified detail around \(terms). The example is \(readiness.title.lowercased())."
        }
        if !capabilityText.isEmpty {
            return "“\(title)” demonstrates \(capabilityText.lowercased()), although the wording has limited direct overlap with this requirement."
        }
        if !terms.isEmpty {
            return "“\(title)” shares specific terms—\(terms)—but the capability fit needs your review."
        }
        return "Only a limited wording link was found. Review it as partial evidence, not proof."
    }
}
