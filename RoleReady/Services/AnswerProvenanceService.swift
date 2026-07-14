import Foundation

enum AnswerSourceField: String, CaseIterable, Identifiable, Sendable {
    case situation
    case responsibility
    case action
    case result
    case evidence
    case learning

    var id: String { rawValue }

    var title: String {
        switch self {
        case .situation: "Situation"
        case .responsibility: "Responsibility"
        case .action: "Action"
        case .result: "Result"
        case .evidence: "Evidence"
        case .learning: "Learning"
        }
    }
}

struct AnswerSourceOption: Identifiable, Hashable, Sendable {
    let field: AnswerSourceField
    let text: String

    var id: String { field.rawValue }
    var title: String { field.title }
}

struct AnswerProvenanceService: Sendable {
    private let analyzer = TextAnalyzer()
    private let styleTokens: Set<String> = [
        "after", "approach", "context", "evidence", "example", "first", "forward", "lesson",
        "next", "outcome", "relevant", "responsibility", "result", "situation", "strong", "technical",
        "then", "took", "verified"
    ]

    func reconcile(
        content: String,
        generatedContent: String,
        generatedClaims: [AnswerClaim],
        experience: Experience,
        sourceOverrides: [String: AnswerSourceField] = [:]
    ) -> [AnswerClaim] {
        reconcile(
            content: content,
            generatedContent: generatedContent,
            generatedClaims: generatedClaims,
            experience: GroundedExperience(experience),
            sourceOverrides: sourceOverrides
        )
    }

    func reconcile(
        content: String,
        generatedContent: String,
        generatedClaims: [AnswerClaim],
        experience: GroundedExperience,
        sourceOverrides: [String: AnswerSourceField] = [:]
    ) -> [AnswerClaim] {
        guard normalized(content) != normalized(generatedContent) else { return generatedClaims }

        let options = Dictionary(uniqueKeysWithValues: availableSources(for: experience).map { ($0.field, $0.text) })
        let clauseLevelGeneratedClaims = generatedClaims.flatMap { claim -> [AnswerClaim] in
            let parts = clauses(in: claim.text)
            guard parts.count > 1 else { return [claim] }
            return parts.map { part in
                AnswerClaim(
                    text: part,
                    sourceField: claim.sourceField,
                    sourceText: claim.sourceText,
                    origin: claim.origin,
                    isSupported: claim.isSupported
                )
            }
        }
        return clauses(in: content).map { clause in
            let key = claimKey(for: clause)
            if let exact = clauseLevelGeneratedClaims.first(where: { normalized($0.text) == normalized(clause) }) {
                return AnswerClaim(
                    text: clause,
                    sourceField: exact.sourceField,
                    sourceText: exact.sourceText,
                    origin: exact.origin,
                    isSupported: exact.isSupported
                )
            }

            if let near = clauseLevelGeneratedClaims
                .map({ ($0, similarity(clause, $0.text)) })
                .max(by: { $0.1 < $1.1 }),
               near.1 >= 0.9,
               isFullySupported(clause, by: near.0.text, ownership: experience.ownership) {
                return AnswerClaim(
                    text: clause,
                    sourceField: near.0.sourceField,
                    sourceText: near.0.sourceText,
                    origin: .editedSupported,
                    isSupported: true
                )
            }

            if let field = sourceOverrides[key], let sourceText = options[field] {
                let supported = isFullySupported(clause, by: sourceText, ownership: experience.ownership)
                return AnswerClaim(
                    text: clause,
                    sourceField: field.title,
                    sourceText: sourceText,
                    origin: supported ? .editedSupported : .editedUnsupported,
                    isSupported: supported
                )
            }

            return AnswerClaim(
                text: clause,
                sourceField: "Edited — source needed",
                sourceText: "",
                origin: .editedUnsupported,
                isSupported: false
            )
        }
    }

    func availableSources(for experience: Experience) -> [AnswerSourceOption] {
        availableSources(for: GroundedExperience(experience))
    }

    func availableSources(for experience: GroundedExperience) -> [AnswerSourceOption] {
        let responsibility = experience.task.trimmedForProvenance.isEmpty
            ? "Ownership: \(experience.ownership.title)"
            : experience.task
        return [
            AnswerSourceOption(field: .situation, text: experience.situation),
            AnswerSourceOption(field: .responsibility, text: responsibility),
            AnswerSourceOption(field: .action, text: experience.actions.joined(separator: " ")),
            AnswerSourceOption(field: .result, text: experience.result),
            AnswerSourceOption(field: .evidence, text: experience.evidence),
            AnswerSourceOption(field: .learning, text: experience.learning)
        ]
        .filter { !$0.text.trimmedForProvenance.isEmpty }
    }

    func claimKey(for text: String) -> String {
        normalized(text)
    }

    func storedClaims(from claims: [AnswerClaim]) -> [StoredAnswerClaim] {
        claims.map { claim in
            StoredAnswerClaim(
                sourceField: claim.sourceField,
                text: claim.text,
                sourceText: claim.sourceText,
                origin: claim.origin,
                isSupported: claim.isSupported
            )
        }
    }

    func claimsCompletelyCover(content: String, claims: [AnswerClaim]) -> Bool {
        guard !claims.isEmpty, claims.allSatisfy({ !$0.needsSource }) else { return false }
        if normalized(content) == normalized(claims.map(\.text).joined(separator: " ")) {
            return true
        }

        let supportedClaimClauses = claims.flatMap { claim in
            clauses(in: claim.text).map(normalized)
        }
        let contentClauses = clauses(in: content).map(normalized)
        guard !contentClauses.isEmpty else { return false }
        return contentClauses.allSatisfy(supportedClaimClauses.contains)
    }

    func isSupportedClaim(_ clause: String, by source: String, ownership: OwnershipLevel) -> Bool {
        isFullySupported(clause, by: source, ownership: ownership)
    }

    private func clauses(in content: String) -> [String] {
        let headings: Set<String> = ["situation", "task", "action", "result", "reflection"]
        let pattern = #"[^.!?;\n]+(?:[.!?;]+|$)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        return expression.matches(in: content, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: content) else { return nil }
            let value = String(content[matchRange]).trimmedForProvenance
            let heading = value.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".:; "))
            guard !value.isEmpty, !headings.contains(heading) else { return nil }
            return value
        }
    }

    private func similarity(_ lhs: String, _ rhs: String) -> Double {
        let left = Set(analyzer.tokens(in: lhs, includeStopWords: true))
        let right = Set(analyzer.tokens(in: rhs, includeStopWords: true))
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        return Double(left.intersection(right).count) / Double(left.union(right).count)
    }

    private func isFullySupported(_ clause: String, by source: String, ownership: OwnershipLevel) -> Bool {
        let clauseNumbers = analyzer.orderedNumericClaims(in: clause)
        let sourceNumbers = analyzer.orderedNumericClaims(in: source)
        guard orderedSubsequence(clauseNumbers, of: sourceNumbers) else { return false }
        guard polarityMarkers(in: clause) == polarityMarkers(in: source) else { return false }

        let lower = clause.lowercased()
        if ownership == .supported || ownership == .contributed {
            let ownershipOverstatement = #"\bi\s+(?:personally\s+)?(?:led|owned|managed|directed|oversaw|drove|headed|spearheaded|controlled)\b|\bi\s+was\s+(?:solely\s+|fully\s+)?responsible\b|\bsolely responsible\b"#
            guard lower.range(of: ownershipOverstatement, options: .regularExpression) == nil else { return false }
        }

        let clauseTokens = Set(analyzer.tokens(in: clause))
        let sourceTokens = Set(analyzer.tokens(in: source))
        let permittedStyleTokens = Set(styleTokens.flatMap { analyzer.tokens(in: $0) })
        let permitted = sourceTokens.union(permittedStyleTokens)
        return clauseTokens.subtracting(permitted).isEmpty
    }

    private func polarityMarkers(in value: String) -> Set<String> {
        let lower = value.lowercased()
        var markers: Set<String> = []
        let patterns: [(String, String)] = [
            (#"\b(?:not|never|no|without|neither|nor)\b"#, "negative"),
            (#"\b(?:didn't|did not|wasn't|was not|weren't|were not|cannot|can't|couldn't|could not|won't|wouldn't|shouldn't|mustn't)\b"#, "negative-verb"),
            (#"\b(?:failed to|unable to)\b"#, "failure")
        ]
        for (pattern, marker) in patterns where lower.range(of: pattern, options: .regularExpression) != nil {
            markers.insert(marker)
        }
        return markers
    }

    private func orderedSubsequence(_ values: [String], of source: [String]) -> Bool {
        guard !values.isEmpty else { return true }
        var sourceIndex = source.startIndex
        for value in values {
            guard let match = source[sourceIndex...].firstIndex(of: value) else { return false }
            sourceIndex = source.index(after: match)
        }
        return true
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct AnswerClaimValidator: Sendable {
    private let provenance = AnswerProvenanceService()

    func validate(
        _ storedClaims: [StoredAnswerClaim],
        question: String,
        format: AnswerFormat,
        audience: AnswerAudience,
        tone: AnswerTone,
        roleTitle: String,
        experience: GroundedExperience
    ) -> [AnswerClaim] {
        let referenceClaims = (try? GroundedAnswerEngine().generate(
            question: question,
            from: experience,
            format: format,
            audience: audience,
            tone: tone,
            roleTitle: roleTitle
        ).claims) ?? []

        return storedClaims.map { stored in
            let matchesReference = referenceClaims.contains { reference in
                reference.sourceField.caseInsensitiveCompare(stored.sourceField) == .orderedSame
                    && normalized(reference.sourceText) == normalized(stored.sourceText)
                    && normalized(reference.text) == normalized(stored.text)
            }
            let supported: Bool
            if matchesReference {
                supported = !stored.needsSource
            } else if let field = AnswerSourceField.allCases.first(where: {
                $0.title.caseInsensitiveCompare(stored.sourceField) == .orderedSame
            }), let currentSource = matchingSourceText(stored.sourceText, field: field, experience: experience) {
                supported = !stored.needsSource
                    && provenance.isSupportedClaim(stored.text, by: currentSource, ownership: experience.ownership)
            } else {
                supported = false
            }

            return AnswerClaim(
                text: stored.text,
                sourceField: supported ? stored.sourceField : "Edited — source needed",
                sourceText: supported ? stored.sourceText : "",
                origin: supported ? stored.origin : .editedUnsupported,
                isSupported: supported
            )
        }
    }

    private func matchingSourceText(
        _ storedSource: String,
        field: AnswerSourceField,
        experience: GroundedExperience
    ) -> String? {
        let candidates: [String]
        switch field {
        case .situation:
            candidates = [experience.situation]
        case .responsibility:
            candidates = experience.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ["Ownership: \(experience.ownership.title)"]
                : [experience.task]
        case .action:
            candidates = experience.actions + [experience.actions.joined(separator: " ")]
        case .result:
            candidates = [experience.result]
        case .evidence:
            candidates = [experience.evidence]
        case .learning:
            candidates = [experience.learning]
        }
        return candidates.first { normalized($0) == normalized(storedSource) }
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var trimmedForProvenance: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
