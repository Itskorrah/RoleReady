import Foundation

struct TextAnalyzer: Sendable {
    private let stopWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "been", "being", "by", "for", "from", "had", "has", "have",
        "i", "in", "into", "is", "it", "its", "of", "on", "or", "our", "that", "the", "their", "this", "to", "was",
        "we", "were", "will", "with", "you", "your", "role", "work", "working", "team"
    ]

    private let capabilityTerms: [Capability: Set<String>] = [
        .technicalProblemSolving: ["debug", "debugging", "engineer", "engineering", "incident", "python", "root", "solution", "solve", "technical"],
        .processImprovement: ["automate", "automation", "efficient", "improve", "migration", "modernise", "optimise", "process", "workflow"],
        .dataQuality: ["accuracy", "audit", "quality", "regression", "reliable", "risk", "schema", "test", "testing", "validate", "validation"],
        .stakeholderCommunication: ["business", "communicate", "communication", "facilitate", "present", "requirements", "stakeholder", "workshop"],
        .leadership: ["coach", "coordinate", "lead", "leadership", "mentor", "own", "strategy"],
        .teamwork: ["collaborate", "collaboration", "pair", "partner", "teamwork"],
        .delivery: ["deadline", "deliver", "implementation", "launch", "release", "ship"],
        .customerFocus: ["client", "customer", "patient", "service", "user"],
        .adaptability: ["adapt", "change", "uncertain", "unknown"],
        .accountability: ["accountability", "mistake", "recover", "responsible", "risk"],
        .learning: ["feedback", "learn", "retrospective", "training"],
        .planning: ["competing", "plan", "priorities", "prioritise", "schedule"]
    ]

    func tokens(in text: String, includeStopWords: Bool = false) -> [String] {
        surfaceTokens(in: text, includeStopWords: includeStopWords).map(stem)
    }

    /// Human-readable tokens in their original inflected form. Matching uses
    /// stemmed tokens internally, but product copy must never expose stems.
    func surfaceTokens(in text: String, includeStopWords: Bool = false) -> [String] {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let pattern = #"[a-z0-9][a-z0-9+.#-]*"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(folded.startIndex..<folded.endIndex, in: folded)
        return expression.matches(in: folded, range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: folded) else { return nil }
            let token = String(folded[tokenRange])
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: "."))
            guard token.count > 1 else { return nil }
            guard includeStopWords || !stopWords.contains(token) else { return nil }
            return token
        }
    }

    func keywords(in text: String, limit: Int = 12) -> [String] {
        let frequencies = Dictionary(grouping: tokens(in: text), by: { $0 }).mapValues(\.count)
        return frequencies
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(max(limit, 0))
            .map(\.key)
    }

    func inferCapabilities(from text: String) -> [Capability] {
        let words = Set(tokens(in: text))
        return capabilityTerms.compactMap { capability, terms in
            words.isDisjoint(with: Set(terms.map { stem($0) })) ? nil : capability
        }
        .sorted { $0.title < $1.title }
    }

    func sensitiveFindings(in text: String) -> [String] {
        let lower = text.lowercased()
        var findings: [String] = []
        let patterns: [(String, String)] = [
            (#"\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b"#, "Email address"),
            (#"\b(?:password|secret|api[_ -]?key|access token)\b"#, "Credential or secret"),
            (#"\b(?:patient id|medical record|health record|diagnosis)\b"#, "Health information"),
            (#"\b(?:customer id|account number|case number)\b"#, "Customer identifier"),
            (#"\b(?:internal only|restricted|classified|security incident)\b"#, "Restricted information")
        ]
        for (pattern, label) in patterns {
            if lower.range(of: pattern, options: .regularExpression) != nil {
                findings.append(label)
            }
        }
        return findings
    }

    func numericClaims(in text: String) -> Set<String> {
        Set(orderedNumericClaims(in: text))
    }

    func orderedNumericClaims(in text: String) -> [String] {
        let pattern = #"(?<![A-Za-z])\$?\d+(?:[.,]\d+)*(?:%|\s?(?:hours?|days?|weeks?|months?|years?|gb|mb|tests?))?"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]).lowercased().replacingOccurrences(of: " ", with: "") }
        }
    }

    private func stem(_ word: String) -> String {
        guard word.count > 4 else { return word }
        for suffix in ["ingly", "ments", "ation", "ings", "ment", "ied", "ing", "ers", "ed", "es", "s"] where word.hasSuffix(suffix) {
            let candidate = String(word.dropLast(suffix.count))
            if candidate.count >= 3 { return candidate }
        }
        return word
    }
}
