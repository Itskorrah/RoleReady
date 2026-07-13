import Foundation

struct AnswerClaim: Identifiable, Hashable {
    let id: UUID
    let text: String
    let sourceField: String
}

struct GeneratedDraft: Hashable {
    var content: String
    var quickCues: [String]
    var claims: [AnswerClaim]
    var followUps: [String]
    var warnings: [String]
    var wordCount: Int
}

enum GroundedAnswerError: LocalizedError, Equatable {
    case missingSituation
    case missingActions
    case missingResult
    case blockedBySensitivity

    var errorDescription: String? {
        switch self {
        case .missingSituation: "Add the situation before creating an answer."
        case .missingActions: "Add at least one action you personally took."
        case .missingResult: "Add what changed or how you verified the outcome before creating an answer."
        case .blockedBySensitivity: "This story is marked highly sensitive. Approve it for matching before creating an answer."
        }
    }
}

struct GroundedAnswerEngine {
    private let analyzer = TextAnalyzer()

    func generate(
        question: String,
        from experience: Experience,
        format: AnswerFormat,
        audience: AnswerAudience,
        tone: AnswerTone,
        roleTitle: String? = nil
    ) throws -> GeneratedDraft {
        guard !experience.situation.trimmed.isEmpty else { throw GroundedAnswerError.missingSituation }
        guard !experience.actions.isEmpty else { throw GroundedAnswerError.missingActions }
        guard !experience.result.trimmed.isEmpty else { throw GroundedAnswerError.missingResult }
        guard !experience.confidentiality.blocksAutomaticUse || experience.isApprovedForMatching else {
            throw GroundedAnswerError.blockedBySensitivity
        }

        let situation = sentence(experience.situation)
        let task = sentence(experience.task.isEmpty ? ownershipTask(for: experience) : experience.task)
        let actions = experience.actions.map(sentence)
        let result = sentence(experience.result)
        let evidence = experience.evidence.trimmed.isEmpty ? nil : sentence(experience.evidence)
        let learning = experience.learning.trimmed.isEmpty ? nil : sentence(experience.learning)

        var claims: [AnswerClaim] = []
        func claim(_ text: String, field: String) -> String {
            claims.append(AnswerClaim(id: UUID(), text: text, sourceField: field))
            return text
        }

        let content: String
        let matchedQuestionCapability = analyzer.inferCapabilities(from: question)
            .first { experience.capabilities.contains($0) }
        let lead = contextualLead(
            matchedCapability: matchedQuestionCapability,
            roleTitle: roleTitle,
            audience: audience,
            tone: tone
        )
        switch format {
        case .quickPrompt:
            content = quickCues(for: experience).joined(separator: " → ")
            claims = quickCues(for: experience).enumerated().map { index, cue in
                AnswerClaim(id: UUID(), text: cue, sourceField: index == 0 ? "Story title" : (index == quickCues(for: experience).count - 1 ? "Result" : "Action"))
            }
        case .thirtySeconds:
            content = [
                lead,
                claim(situation, field: "Situation"),
                claim(task, field: "Responsibility"),
                actions.prefix(2).map { claim($0, field: "Action") }.joined(separator: " "),
                claim(result, field: "Result")
            ].filter { !$0.isEmpty }.joined(separator: " ")
        case .sixtySeconds:
            var parts = [
                lead,
                claim(situation, field: "Situation"),
                claim(task, field: "Responsibility"),
                actions.prefix(3).map { claim($0, field: "Action") }.joined(separator: " "),
                claim(result, field: "Result")
            ]
            if let evidence { parts.append(claim(evidence, field: "Evidence")) }
            content = parts.joined(separator: " ")
        case .ninetySeconds:
            var parts = [
                lead,
                claim(situation, field: "Situation"),
                claim(task, field: "Responsibility"),
                actions.map { claim($0, field: "Action") }.joined(separator: " "),
                claim(result, field: "Result")
            ]
            if let evidence { parts.append(claim(evidence, field: "Evidence")) }
            if let learning { parts.append(claim(learning, field: "Learning")) }
            content = parts.joined(separator: " ")
        case .writtenSTAR:
            var sections = [
                "Situation\n\(claim(situation, field: "Situation"))",
                "Task\n\(claim(task, field: "Responsibility"))",
                "Action\n\(actions.map { claim($0, field: "Action") }.joined(separator: " "))",
                "Result\n\(claim(result, field: "Result"))"
            ]
            if let evidence { sections[3] += " " + claim(evidence, field: "Evidence") }
            if let learning { sections.append("Reflection\n" + claim(learning, field: "Learning")) }
            content = sections.joined(separator: "\n\n")
        case .resumeBullet:
            let action = resumeAction(from: actions[0])
            content = "\(claim(action, field: "Action")); \(claim(result.lowercasingFirstCharacter(), field: "Result"))"
        case .coverLetter:
            let actionText = actions.prefix(2).map { claim($0, field: "Action") }.joined(separator: " ")
            content = "\(lead) \(claim(situation, field: "Situation")) \(claim(task, field: "Responsibility")) \(actionText) \(claim(result, field: "Result"))"
        case .selectionCriteria:
            var parts = [
                lead,
                claim(situation, field: "Situation"),
                claim(task, field: "Responsibility"),
                actions.map { claim($0, field: "Action") }.joined(separator: " "),
                claim(result, field: "Result")
            ]
            if let evidence { parts.append(claim(evidence, field: "Evidence")) }
            if let learning { parts.append(claim(learning, field: "Learning")) }
            content = parts.joined(separator: " ")
        }

        let context = [question, roleTitle ?? ""].joined(separator: " ")
        let warnings = reviewWarnings(output: content, against: experience, allowedContext: context)

        return GeneratedDraft(
            content: content,
            quickCues: quickCues(for: experience),
            claims: claims,
            followUps: followUps(for: experience, question: question),
            warnings: Array(Set(warnings)).sorted(),
            wordCount: content.split(whereSeparator: \.isWhitespace).count
        )
    }

    func reviewWarnings(
        output: String,
        against experience: Experience,
        allowedContext: String = ""
    ) -> [String] {
        let sourceFacts = [
            experience.title,
            experience.organisation,
            experience.situation,
            experience.task,
            experience.actions.joined(separator: " "),
            experience.result,
            experience.evidence,
            experience.learning,
            experience.tools.joined(separator: " "),
            allowedContext
        ].joined(separator: " ")
        var warnings = groundingWarnings(output: output, sourceFacts: sourceFacts, experience: experience)
        warnings.append(contentsOf: analyzer.sensitiveFindings(in: output).map {
            "Review before sharing: \($0.lowercased()) detected."
        })
        if experience.confidentiality >= .confidential {
            warnings.append("This answer uses a \(experience.confidentiality.title.lowercased()) story. Review names and internal detail before sharing.")
        }
        return Array(Set(warnings)).sorted()
    }

    private func ownershipTask(for experience: Experience) -> String {
        switch experience.ownership {
        case .led: "I led the response and was accountable for the approach."
        case .owned: "I was responsible for delivering the work."
        case .contributed: "I contributed a defined part of the team’s response."
        case .supported: "I supported the team’s response in a defined capacity."
        }
    }

    private func quickCues(for experience: Experience) -> [String] {
        var cues = [shorten(experience.title, words: 5)]
        cues.append(contentsOf: experience.actions.prefix(3).map { shorten($0.replacingOccurrences(of: "I ", with: "", options: [.anchored, .caseInsensitive]), words: 6) })
        cues.append(shorten(experience.result, words: 12))
        return cues.filter { !$0.isEmpty }
    }

    private func followUps(for experience: Experience, question: String) -> [String] {
        var items = [
            "What made this situation difficult?",
            "Why did you choose that approach?",
            "How did you verify the result?",
            "What would you do differently now?"
        ]
        if experience.capabilities.contains(.stakeholderCommunication) {
            items.insert("How did you bring stakeholders with you?", at: 2)
        }
        if question.lowercased().contains("mistake") || experience.kind == .mistakeAndLearning {
            items.insert("How did you take accountability?", at: 1)
        }
        return Array(items.prefix(5))
    }

    private func groundingWarnings(output: String, sourceFacts: String, experience: Experience) -> [String] {
        let outputNumbers = analyzer.numericClaims(in: output)
        let sourceNumbers = analyzer.numericClaims(in: sourceFacts)
        var warnings: [String] = []
        let unsupported = outputNumbers.subtracting(sourceNumbers)
        if !unsupported.isEmpty {
            warnings.append("Unsupported number detected: \(unsupported.sorted().joined(separator: ", ")).")
        }
        if experience.ownership == .supported || experience.ownership == .contributed {
            let lower = output.lowercased()
            if lower.contains("i led") || lower.contains("i owned") {
                warnings.append("The wording may overstate your recorded ownership level.")
            }
        }
        return warnings
    }

    private func resumeAction(from sentence: String) -> String {
        sentence
            .replacingOccurrences(of: #"^I\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
            .uppercasingFirstCharacter()
    }

    private func contextualLead(
        matchedCapability: Capability?,
        roleTitle: String?,
        audience: AnswerAudience,
        tone: AnswerTone
    ) -> String {
        let focus = matchedCapability.map { " demonstrating \($0.title.lowercased())" } ?? ""
        let role = roleTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let roleContext = role.flatMap { $0.isEmpty ? nil : " for the \($0) role" } ?? ""

        switch (audience, tone) {
        case (_, .concise):
            return "A relevant example\(focus)\(roleContext) is:"
        case (.technicalPanel, _), (_, .technical):
            return "A technically relevant example\(focus)\(roleContext) is:"
        case (.executivePanel, _):
            return "One example of accountable delivery\(roleContext) is:"
        case (_, .confident):
            return "A strong example\(focus)\(roleContext) is:"
        default:
            return "One relevant example\(focus)\(roleContext) is:"
        }
    }

    private func sentence(_ value: String) -> String {
        let trimmed = value.trimmed
        guard !trimmed.isEmpty else { return "" }
        let capitalised = trimmed.uppercasingFirstCharacter()
        return ".!?".contains(capitalised.last ?? " ") ? capitalised : capitalised + "."
    }

    private func shorten(_ value: String, words: Int) -> String {
        value.trimmed
            .split(whereSeparator: \.isWhitespace)
            .prefix(words)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;: "))
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    func uppercasingFirstCharacter() -> String {
        guard let first else { return self }
        return first.uppercased() + String(dropFirst())
    }

    func lowercasingFirstCharacter() -> String {
        guard let first else { return self }
        return first.lowercased() + String(dropFirst())
    }
}
