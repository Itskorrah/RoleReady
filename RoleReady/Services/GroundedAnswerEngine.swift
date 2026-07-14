import Foundation

struct GroundedExperience: Hashable, Sendable {
    let id: UUID
    let title: String
    let organisation: String
    let situation: String
    let task: String
    let actions: [String]
    let result: String
    let evidence: String
    let learning: String
    let ownership: OwnershipLevel
    let capabilities: [Capability]
    let tools: [String]
    let confidentiality: Confidentiality
    let isApprovedForMatching: Bool

    init(_ experience: Experience) {
        id = experience.id
        title = experience.title
        organisation = experience.organisation
        situation = experience.situation
        task = experience.task
        actions = experience.actions
        result = experience.result
        evidence = experience.evidence
        learning = experience.learning
        ownership = experience.ownership
        capabilities = experience.capabilities
        tools = experience.tools
        confidentiality = experience.confidentiality
        isApprovedForMatching = experience.isApprovedForMatching
    }

    init(
        id: UUID,
        title: String,
        organisation: String,
        situation: String,
        task: String,
        actions: [String],
        result: String,
        evidence: String,
        learning: String,
        ownership: OwnershipLevel,
        capabilities: [Capability],
        tools: [String],
        confidentiality: Confidentiality,
        isApprovedForMatching: Bool
    ) {
        self.id = id
        self.title = title
        self.organisation = organisation
        self.situation = situation
        self.task = task
        self.actions = actions
        self.result = result
        self.evidence = evidence
        self.learning = learning
        self.ownership = ownership
        self.capabilities = capabilities
        self.tools = tools
        self.confidentiality = confidentiality
        self.isApprovedForMatching = isApprovedForMatching
    }
}

struct AnswerClaim: Identifiable, Hashable, Sendable {
    let id: UUID
    let text: String
    let sourceField: String
    let sourceText: String
    let origin: AnswerClaimOrigin
    let isSupported: Bool

    init(
        id: UUID = UUID(),
        text: String,
        sourceField: String,
        sourceText: String = "",
        origin: AnswerClaimOrigin = .generated,
        isSupported: Bool = true
    ) {
        self.id = id
        self.text = text
        self.sourceField = sourceField
        self.sourceText = sourceText
        self.origin = origin
        self.isSupported = isSupported
    }

    var needsSource: Bool {
        !isSupported || origin == .editedUnsupported
    }
}

struct GeneratedDraft: Hashable, Sendable {
    var content: String
    var quickCues: [String]
    var claims: [AnswerClaim]
    var followUps: [String]
    var warnings: [String]
    var wordCount: Int
    var estimatedSpeakingSeconds: Int = 0
    var targetWordCount: ClosedRange<Int> = 0...Int.max

    var isWithinTarget: Bool {
        targetWordCount.contains(wordCount)
    }
}

enum GroundedAnswerError: LocalizedError, Equatable, Sendable {
    case missingSituation
    case missingActions
    case missingResult
    case blockedBySensitivity

    var errorDescription: String? {
        switch self {
        case .missingSituation: "Add what happened before creating an answer."
        case .missingActions: "Add at least one action you personally took."
        case .missingResult: "Add what changed or how you verified the outcome before creating an answer."
        case .blockedBySensitivity: "This example is marked highly sensitive. Approve it for matching before creating an answer."
        }
    }
}

struct GroundedAnswerEngine: Sendable {
    private let analyzer = TextAnalyzer()

    func generate(
        question: String,
        from experience: Experience,
        format: AnswerFormat,
        audience: AnswerAudience,
        tone: AnswerTone,
        roleTitle: String? = nil
    ) throws -> GeneratedDraft {
        try generate(
            question: question,
            from: GroundedExperience(experience),
            format: format,
            audience: audience,
            tone: tone,
            roleTitle: roleTitle
        )
    }

    func generate(
        question: String,
        from experience: GroundedExperience,
        format: AnswerFormat,
        audience: AnswerAudience,
        tone: AnswerTone,
        roleTitle: String? = nil
    ) throws -> GeneratedDraft {
        guard !experience.situation.trimmed.isEmpty else { throw GroundedAnswerError.missingSituation }
        guard experience.actions.contains(where: { !$0.trimmed.isEmpty }) else { throw GroundedAnswerError.missingActions }
        guard !experience.result.trimmed.isEmpty else { throw GroundedAnswerError.missingResult }
        guard !experience.confidentiality.blocksAutomaticUse || experience.isApprovedForMatching else {
            throw GroundedAnswerError.blockedBySensitivity
        }

        let context = [question, roleTitle ?? ""].joined(separator: " ").trimmed
        let matchedQuestionCapability = analyzer.inferCapabilities(from: question)
            .first { experience.capabilities.contains($0) }
        let lead = contextualLead(
            matchedCapability: matchedQuestionCapability,
            roleTitle: roleTitle,
            audience: audience,
            tone: tone
        )
        let leadClaim = AnswerClaim(
            text: lead,
            sourceField: "Question context",
            sourceText: context,
            origin: .questionContext
        )
        let situationClaim = AnswerClaim(
            text: "For context, \(sentenceFragment(experience.situation))",
            sourceField: "Situation",
            sourceText: experience.situation
        )
        let responsibilitySource = experience.task.trimmed.isEmpty
            ? ownershipTask(for: experience.ownership)
            : experience.task
        let responsibilityClaim = AnswerClaim(
            text: "My responsibility was \(sentenceFragment(responsibilitySource))",
            sourceField: "Responsibility",
            sourceText: experience.task.trimmed.isEmpty ? "Ownership: \(experience.ownership.title)" : experience.task
        )
        let actionClaims = experience.actions
            .filter { !$0.trimmed.isEmpty }
            .enumerated()
            .map { index, action in
                AnswerClaim(
                    text: "\(actionTransition(index)) \(sentence(action))",
                    sourceField: "Action",
                    sourceText: action
                )
            }
        let resultClaim = AnswerClaim(
            text: "As a result, \(sentenceFragment(experience.result))",
            sourceField: "Result",
            sourceText: experience.result
        )
        let evidenceClaim = experience.evidence.trimmed.isEmpty ? nil : AnswerClaim(
            text: "I verified the outcome with this evidence: \(sentence(experience.evidence))",
            sourceField: "Evidence",
            sourceText: experience.evidence
        )
        let learningClaim = experience.learning.trimmed.isEmpty ? nil : AnswerClaim(
            text: "The lesson I took forward was \(sentenceFragment(experience.learning))",
            sourceField: "Learning",
            sourceText: experience.learning
        )

        let content: String
        var claims: [AnswerClaim]
        switch format {
        case .quickPrompt:
            let cueValues = quickCueSources(for: experience)
            claims = cueValues.map { value in
                AnswerClaim(
                    text: value.text,
                    sourceField: value.field,
                    sourceText: value.source
                )
            }
            content = claims.map(\.text).joined(separator: " → ")

        case .thirtySeconds:
            claims = fitSpokenClaims(
                head: [leadClaim, situationClaim, responsibilityClaim],
                middle: Array(actionClaims.prefix(2)),
                tail: [resultClaim],
                optional: [],
                maximumWords: format.targetWordCount.upperBound
            )
            content = claims.map(\.text).joined(separator: " ")

        case .sixtySeconds:
            claims = fitSpokenClaims(
                head: [leadClaim, situationClaim, responsibilityClaim],
                middle: Array(actionClaims.prefix(4)),
                tail: [resultClaim],
                optional: [evidenceClaim, learningClaim].compactMap { $0 },
                maximumWords: format.targetWordCount.upperBound
            )
            content = claims.map(\.text).joined(separator: " ")

        case .ninetySeconds:
            claims = fitSpokenClaims(
                head: [leadClaim, situationClaim, responsibilityClaim],
                middle: Array(actionClaims.prefix(6)),
                tail: [resultClaim],
                optional: [evidenceClaim, learningClaim].compactMap { $0 },
                maximumWords: format.targetWordCount.upperBound
            )
            content = claims.map(\.text).joined(separator: " ")

        case .writtenSTAR:
            claims = [situationClaim, responsibilityClaim] + actionClaims + [resultClaim]
            claims.append(contentsOf: [evidenceClaim, learningClaim].compactMap { $0 })
            var sections = [
                "Situation\n\(situationClaim.text)",
                "Task\n\(responsibilityClaim.text)",
                "Action\n\(actionClaims.map(\.text).joined(separator: " "))",
                "Result\n\(([resultClaim, evidenceClaim].compactMap { $0 }).map(\.text).joined(separator: " "))"
            ]
            if let learningClaim { sections.append("Reflection\n\(learningClaim.text)") }
            content = sections.joined(separator: "\n\n")

        case .resumeBullet:
            let action = AnswerClaim(
                text: resumeAction(from: experience.actions[0]),
                sourceField: "Action",
                sourceText: experience.actions[0]
            )
            let result = AnswerClaim(
                text: sentenceFragment(experience.result),
                sourceField: "Result",
                sourceText: experience.result
            )
            claims = [action, result]
            content = "\(action.text); \(result.text)"

        case .coverLetter:
            claims = fitSpokenClaims(
                head: [leadClaim, situationClaim, responsibilityClaim],
                middle: Array(actionClaims.prefix(3)),
                tail: [resultClaim],
                optional: [evidenceClaim].compactMap { $0 },
                maximumWords: format.targetWordCount.upperBound
            )
            content = claims.map(\.text).joined(separator: " ")

        case .selectionCriteria:
            let criterionLead = AnswerClaim(
                text: "I address this criterion with a specific example from my verified experience.",
                sourceField: "Question context",
                sourceText: context,
                origin: .questionContext
            )
            let capabilityText = experience.capabilities.prefix(3).map(\.title).joined(separator: ", ")
            let capabilityClaim = capabilityText.isEmpty ? nil : AnswerClaim(
                text: "The example demonstrates recorded capability in \(capabilityText.lowercased()).",
                sourceField: "Verified capabilities",
                sourceText: capabilityText
            )
            let criterionClose = AnswerClaim(
                text: "Together, these verified facts show how my experience responds to the criterion without overstating my contribution.",
                sourceField: "Question context",
                sourceText: context,
                origin: .questionContext
            )
            claims = [criterionLead, situationClaim, responsibilityClaim]
                + Array(actionClaims.prefix(6))
                + [resultClaim]
                + [evidenceClaim, learningClaim, capabilityClaim].compactMap { $0 }
                + [criterionClose]
            while countWords(claims.map(\.text).joined(separator: " ")) > format.targetWordCount.upperBound,
                  let removableIndex = claims.dropLast().lastIndex(where: {
                      $0.sourceField == "Learning" || $0.sourceField == "Verified capabilities"
                  }) {
                claims.remove(at: removableIndex)
            }
            claims = limitClaims(claims, to: format.targetWordCount.upperBound)
            content = claims.map(\.text).joined(separator: "\n\n")
        }

        let wordCount = countWords(content)
        var warnings = reviewWarnings(output: content, against: experience, allowedContext: context)
        if !format.targetWordCount.contains(wordCount) {
            if wordCount < format.targetWordCount.lowerBound {
                warnings.append(
                    "This \(format.title.lowercased()) answer is \(wordCount) words. Add source detail before approval; the useful target is \(format.targetWordCount.lowerBound)–\(format.targetWordCount.upperBound) words."
                )
            } else {
                warnings.append(
                    "This \(format.title.lowercased()) answer is \(wordCount) words. Shorten it to \(format.targetWordCount.upperBound) words or fewer before approval."
                )
            }
        }

        return GeneratedDraft(
            content: content,
            quickCues: quickCues(for: experience),
            claims: claims,
            followUps: followUps(for: experience, question: question),
            warnings: Array(Set(warnings)).sorted(),
            wordCount: wordCount,
            estimatedSpeakingSeconds: estimatedSpeakingSeconds(for: wordCount),
            targetWordCount: format.targetWordCount
        )
    }

    func reviewWarnings(
        output: String,
        against experience: Experience,
        allowedContext: String = ""
    ) -> [String] {
        reviewWarnings(output: output, against: GroundedExperience(experience), allowedContext: allowedContext)
    }

    func reviewWarnings(
        output: String,
        against experience: GroundedExperience,
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
        var warnings = groundingWarnings(output: output, sourceFacts: sourceFacts, ownership: experience.ownership)
        warnings.append(contentsOf: analyzer.sensitiveFindings(in: output).map {
            "Review before sharing: \($0.lowercased()) detected."
        })
        if experience.confidentiality >= .confidential {
            warnings.append("This answer uses a \(experience.confidentiality.title.lowercased()) example. Review names and internal detail before sharing.")
        }
        return Array(Set(warnings)).sorted()
    }

    private func fitSpokenClaims(
        head: [AnswerClaim],
        middle: [AnswerClaim],
        tail: [AnswerClaim],
        optional: [AnswerClaim],
        maximumWords: Int
    ) -> [AnswerClaim] {
        let requiredMiddle = Array(middle.prefix(1))
        var selected = limitClaims(head + requiredMiddle + tail, to: maximumWords)
        let insertionIndex = head.count + requiredMiddle.count
        for claim in middle.dropFirst(requiredMiddle.count) {
            var candidate = selected
            candidate.insert(claim, at: max(candidate.count - tail.count, insertionIndex))
            if countWords(candidate.map(\.text).joined(separator: " ")) <= maximumWords {
                selected = candidate
            }
        }
        for claim in optional {
            let candidate = selected + [claim]
            if countWords(candidate.map(\.text).joined(separator: " ")) <= maximumWords {
                selected = candidate
            }
        }
        return selected
    }

    private func limitClaims(_ claims: [AnswerClaim], to maximumWords: Int) -> [AnswerClaim] {
        guard countWords(claims.map(\.text).joined(separator: " ")) > maximumWords,
              !claims.isEmpty else { return claims }
        var remainingWords = maximumWords
        var result: [AnswerClaim] = []
        for (index, claim) in claims.enumerated() {
            let remainingClaims = claims.count - index
            let allowance = max(6, remainingWords / max(remainingClaims, 1))
            let words = claim.text.split(whereSeparator: \.isWhitespace)
            let limitedText: String
            if words.count > allowance {
                limitedText = words.prefix(allowance)
                    .joined(separator: " ")
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".,;: ")) + "."
            } else {
                limitedText = claim.text
            }
            let limited = AnswerClaim(
                text: limitedText,
                sourceField: claim.sourceField,
                sourceText: claim.sourceText,
                origin: claim.origin,
                isSupported: claim.isSupported
            )
            result.append(limited)
            remainingWords -= countWords(limitedText)
        }
        return result
    }

    private func ownershipTask(for ownership: OwnershipLevel) -> String {
        switch ownership {
        case .led: "I led the response and was accountable for the approach."
        case .owned: "I was responsible for delivering the work."
        case .contributed: "I contributed a defined part of the team’s response."
        case .supported: "I supported the team’s response in a defined capacity."
        }
    }

    private func quickCueSources(for experience: GroundedExperience) -> [(text: String, field: String, source: String)] {
        var values: [(String, String, String)] = [
            (shorten(experience.title, words: 5), "Story title", experience.title)
        ]
        values.append(contentsOf: experience.actions.prefix(3).map { action in
            (
                shorten(action.replacingOccurrences(of: "I ", with: "", options: [.anchored, .caseInsensitive]), words: 6),
                "Action",
                action
            )
        })
        values.append((shorten(experience.result, words: 12), "Result", experience.result))
        return values.filter { !$0.0.isEmpty }
    }

    private func quickCues(for experience: GroundedExperience) -> [String] {
        quickCueSources(for: experience).map(\.text)
    }

    private func followUps(for experience: GroundedExperience, question: String) -> [String] {
        var items = [
            "What made this situation difficult?",
            "Why did you choose that approach?",
            "How did you verify the result?",
            "What would you do differently now?"
        ]
        if experience.capabilities.contains(.stakeholderCommunication) {
            items.insert("How did you bring stakeholders with you?", at: 2)
        }
        if question.lowercased().contains("mistake") {
            items.insert("How did you take accountability?", at: 1)
        }
        return Array(items.prefix(5))
    }

    private func groundingWarnings(output: String, sourceFacts: String, ownership: OwnershipLevel) -> [String] {
        let outputNumbers = analyzer.numericClaims(in: output)
        let sourceNumbers = analyzer.numericClaims(in: sourceFacts)
        var warnings: [String] = []
        let unsupported = outputNumbers.subtracting(sourceNumbers)
        if !unsupported.isEmpty {
            warnings.append("Unsupported number detected: \(unsupported.sorted().joined(separator: ", ")).")
        }
        if ownership == .supported || ownership == .contributed {
            let lower = output.lowercased()
            let ownershipOverstatement = #"\bi\s+(?:personally\s+)?(?:led|owned|managed|directed|oversaw|drove|headed|spearheaded|controlled)\b|\bi\s+was\s+(?:solely\s+|fully\s+)?responsible\b|\bsolely responsible\b"#
            if lower.range(of: ownershipOverstatement, options: .regularExpression) != nil {
                warnings.append("The wording may overstate your recorded ownership level.")
            }
        }
        return warnings
    }

    private func resumeAction(from value: String) -> String {
        value
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

        return switch (audience, tone) {
        case (_, .concise): "A relevant example\(focus)\(roleContext) is this."
        case (.technicalPanel, _), (_, .technical): "A technically relevant example\(focus)\(roleContext) is this."
        case (.executivePanel, _): "One example of accountable delivery\(roleContext) is this."
        case (_, .confident): "A strong example\(focus)\(roleContext) is this."
        default: "One relevant example\(focus)\(roleContext) is this."
        }
    }

    private func actionTransition(_ index: Int) -> String {
        switch index {
        case 0: "First,"
        case 1: "Then,"
        case 2: "Next,"
        default: "After that,"
        }
    }

    private func sentence(_ value: String) -> String {
        let trimmed = value.trimmed
        guard !trimmed.isEmpty else { return "" }
        let capitalised = trimmed.uppercasingFirstCharacter()
        return ".!?".contains(capitalised.last ?? " ") ? capitalised : capitalised + "."
    }

    private func sentenceFragment(_ value: String) -> String {
        let sentence = sentence(value)
        guard sentence.count >= 2 else { return sentence }
        if sentence.hasPrefix("I ") || sentence.hasPrefix("I’") || sentence.hasPrefix("I'") {
            return sentence
        }
        let first = sentence[sentence.startIndex]
        let secondIndex = sentence.index(after: sentence.startIndex)
        let second = sentence[secondIndex]
        if first.isUppercase, second.isLowercase {
            return first.lowercased() + String(sentence.dropFirst())
        }
        return sentence
    }

    private func shorten(_ value: String, words: Int) -> String {
        value.trimmed
            .split(whereSeparator: \.isWhitespace)
            .prefix(words)
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;: "))
    }

    private func countWords(_ value: String) -> Int {
        value.split(whereSeparator: \.isWhitespace).count
    }

    private func estimatedSpeakingSeconds(for wordCount: Int) -> Int {
        Int((Double(wordCount) / 130 * 60).rounded())
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    func uppercasingFirstCharacter() -> String {
        guard let first else { return self }
        return first.uppercased() + String(dropFirst())
    }
}
