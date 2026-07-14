import Foundation

enum CareerHistoryIngestionError: LocalizedError, Equatable, Sendable {
    case empty
    case tooShort
    case tooLarge
    case noExamplesFound

    var errorDescription: String? {
        switch self {
        case .empty:
            "Paste career history or choose a résumé first."
        case .tooShort:
            "Add a little more detail so RoleReady can find a useful example."
        case .tooLarge:
            "Career history must be under 250,000 characters."
        case .noExamplesFound:
            "No clear work examples were found. Try pasting the experience or project section, or describe one example manually."
        }
    }
}

struct CareerHistoryDraft: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var organisation: String
    var occurredAt: Date
    var kind: ExperienceKind
    var situation: String
    var task: String
    var actions: [String]
    var result: String
    var evidence: String
    var learning: String
    var ownership: OwnershipLevel
    var capabilities: [Capability]
    var tools: [String]
    var sourceExcerpt: String
    var isIncluded: Bool
    var warnings: [String]

    init(
        id: UUID = UUID(),
        title: String,
        organisation: String = "",
        occurredAt: Date = Date(),
        kind: ExperienceKind = .project,
        situation: String = "",
        task: String = "",
        actions: [String] = [],
        result: String = "",
        evidence: String = "",
        learning: String = "",
        ownership: OwnershipLevel = .contributed,
        capabilities: [Capability] = [],
        tools: [String] = [],
        sourceExcerpt: String = "",
        isIncluded: Bool = true,
        warnings: [String] = []
    ) {
        self.id = id
        self.title = title
        self.organisation = organisation
        self.occurredAt = occurredAt
        self.kind = kind
        self.situation = situation
        self.task = task
        self.actions = actions
        self.result = result
        self.evidence = evidence
        self.learning = learning
        self.ownership = ownership
        self.capabilities = capabilities
        self.tools = tools
        self.sourceExcerpt = sourceExcerpt
        self.isIncluded = isIncluded
        self.warnings = warnings
    }
}

struct CareerHistoryIngestionResult: Hashable, Sendable {
    var drafts: [CareerHistoryDraft]
    var warnings: [String]
}

struct CareerHistoryIngestionService: Sendable {
    private let maximumCharacters = 250_000
    private let analyzer = TextAnalyzer()

    func extractDrafts(from source: String) throws -> CareerHistoryIngestionResult {
        let normalized = normalize(source)
        guard !normalized.isEmpty else { throw CareerHistoryIngestionError.empty }
        guard normalized.count >= 24 else { throw CareerHistoryIngestionError.tooShort }
        guard normalized.count <= maximumCharacters else { throw CareerHistoryIngestionError.tooLarge }

        let paragraphs = normalized
            .replacingOccurrences(of: #"\n[ \t]*\n+"#, with: "\n\n", options: .regularExpression)
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !isSectionHeading($0) }

        var drafts = paragraphs.compactMap(makeDraft(from:))
        if drafts.isEmpty, let fallback = makeFallbackDraft(from: normalized) {
            drafts = [fallback]
        }
        guard !drafts.isEmpty else { throw CareerHistoryIngestionError.noExamplesFound }

        var warnings: [String] = [
            "Found examples are unverified drafts. Review the wording, your ownership and the outcome before matching or generating an answer."
        ]
        if drafts.count == 12 {
            warnings.append("Only the first 12 potential examples are shown. Add others later from My Examples.")
        }
        return CareerHistoryIngestionResult(drafts: Array(drafts.prefix(12)), warnings: warnings)
    }

    func combine(_ selectedDrafts: [CareerHistoryDraft]) -> CareerHistoryDraft? {
        guard let first = selectedDrafts.first else { return nil }
        let actions = deduplicated(selectedDrafts.flatMap(\.actions))
        let capabilities = Array(Set(selectedDrafts.flatMap(\.capabilities))).sorted { $0.title < $1.title }
        let tools = deduplicated(selectedDrafts.flatMap(\.tools))
        let results = deduplicated(selectedDrafts.map(\.result).filter { !$0.isEmpty })
        let sources = selectedDrafts.map(\.sourceExcerpt).filter { !$0.isEmpty }.joined(separator: "\n\n")

        return CareerHistoryDraft(
            title: first.title,
            organisation: first.organisation,
            occurredAt: selectedDrafts.map(\.occurredAt).max() ?? first.occurredAt,
            kind: first.kind,
            situation: deduplicated(selectedDrafts.map(\.situation).filter { !$0.isEmpty }).joined(separator: " "),
            task: deduplicated(selectedDrafts.map(\.task).filter { !$0.isEmpty }).joined(separator: " "),
            actions: actions,
            result: results.joined(separator: " "),
            evidence: deduplicated(selectedDrafts.map(\.evidence).filter { !$0.isEmpty }).joined(separator: " "),
            learning: deduplicated(selectedDrafts.map(\.learning).filter { !$0.isEmpty }).joined(separator: " "),
            ownership: .contributed,
            capabilities: capabilities,
            tools: tools,
            sourceExcerpt: sources,
            warnings: ["Combined from \(selectedDrafts.count) résumé sections. Confirm they describe one genuine example before continuing."]
        )
    }

    private func makeDraft(from paragraph: String) -> CareerHistoryDraft? {
        let lines = paragraph.components(separatedBy: .newlines)
            .map(cleanLine)
            .filter { !$0.isEmpty }
        guard lines.count >= 2 else { return nil }

        let bulletLines = lines.filter(isBullet).map(stripBullet)
        let proseLines = lines.filter { !isBullet($0) && !isSectionHeading($0) }
        guard !bulletLines.isEmpty || proseLines.count >= 3 else { return nil }

        let headerLines = Array(proseLines.prefix(3))
        let headerParts = headerLines
            .flatMap(splitHeader)
            .filter { !containsDate($0) }
        let title = headerParts.first ?? "Career example"
        let organisation = headerParts.dropFirst().first ?? ""
        let candidateDetails = bulletLines.isEmpty ? Array(proseLines.dropFirst(min(headerLines.count, 2))) : bulletLines
        guard !candidateDetails.isEmpty else { return nil }

        let resultIndex = candidateDetails.lastIndex(where: looksLikeResult)
        let result = resultIndex.map { candidateDetails[$0] } ?? ""
        var actions = candidateDetails.enumerated().compactMap { index, line in
            index == resultIndex && candidateDetails.count > 1 ? nil : line
        }
        if actions.isEmpty, let resultIndex {
            actions = [candidateDetails[resultIndex]]
        }
        actions = Array(deduplicated(actions).prefix(6))

        let combined = paragraph + " " + candidateDetails.joined(separator: " ")
        var warnings: [String] = []
        if title == "Career example" { warnings.append("Add a short title for this example.") }
        if result.isEmpty { warnings.append("No clear outcome was found. Add what changed before creating an answer.") }
        warnings.append("Ownership defaults to ‘Contributed’ until you confirm your personal part.")

        return CareerHistoryDraft(
            title: title,
            organisation: organisation,
            occurredAt: approximateDate(in: paragraph) ?? Date(),
            kind: inferredKind(from: combined),
            situation: headerLines.joined(separator: " · "),
            actions: actions,
            result: result,
            ownership: .contributed,
            capabilities: analyzer.inferCapabilities(from: combined),
            tools: inferredTools(in: combined),
            sourceExcerpt: String(paragraph.prefix(2_000)),
            warnings: warnings
        )
    }

    private func makeFallbackDraft(from source: String) -> CareerHistoryDraft? {
        let lines = source.components(separatedBy: .newlines)
            .map(cleanLine)
            .filter { !$0.isEmpty && !isSectionHeading($0) }
        guard !lines.isEmpty else { return nil }
        let details = lines.map(stripBullet)
        let resultIndex = details.lastIndex(where: looksLikeResult)
        let result = resultIndex.map { details[$0] } ?? ""
        var actions = details.enumerated().compactMap { index, line in
            index == resultIndex && details.count > 1 ? nil : line
        }
        if actions.isEmpty { actions = [details[0]] }
        return CareerHistoryDraft(
            title: String(details[0].prefix(90)),
            occurredAt: approximateDate(in: source) ?? Date(),
            situation: details[0],
            actions: Array(actions.prefix(6)),
            result: result,
            ownership: .contributed,
            capabilities: analyzer.inferCapabilities(from: source),
            tools: inferredTools(in: source),
            sourceExcerpt: String(source.prefix(2_000)),
            warnings: [
                "RoleReady found one rough example because the source had no clear résumé sections.",
                "Confirm your personal part and add any missing outcome before continuing."
            ]
        )
    }

    private func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cleanLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isBullet(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return ["•", "-", "–", "—", "*", "▪", "◦"].contains(where: trimmed.hasPrefix)
            || trimmed.range(of: #"^\d+[.)]\s"#, options: .regularExpression) != nil
    }

    private func stripBullet(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"^(?:[•\-–—*▪◦]|\d+[.)])\s*"#,
            with: "",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isSectionHeading(_ value: String) -> Bool {
        let clean = value.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ": "))
        return [
            "experience", "professional experience", "employment history", "work history",
            "career history", "projects", "selected projects", "achievements", "education",
            "qualifications", "skills", "technical skills", "references", "referees"
        ].contains(clean)
    }

    private func splitHeader(_ value: String) -> [String] {
        value
            .components(separatedBy: CharacterSet(charactersIn: "|\t"))
            .flatMap { $0.components(separatedBy: " at ") }
            .map(cleanLine)
            .filter { !$0.isEmpty }
    }

    private func containsDate(_ value: String) -> Bool {
        value.range(of: #"\b(?:19|20)\d{2}\b|\bpresent\b|\bcurrent\b"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func approximateDate(in value: String) -> Date? {
        guard let expression = try? NSRegularExpression(pattern: #"\b(?:19|20)\d{2}\b"#) else { return nil }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        let years = expression.matches(in: value, range: range).compactMap { match -> Int? in
            guard let matchRange = Range(match.range, in: value) else { return nil }
            return Int(value[matchRange])
        }
        guard let year = years.max() else { return nil }
        return Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: 1, day: 1))
    }

    private func looksLikeResult(_ value: String) -> Bool {
        let lower = value.lowercased()
        let signals = [
            "achieved", "approved", "completed", "delivered", "improved", "increased", "passed",
            "prevented", "reduced", "resolved", "result", "saved", "successful", "verified"
        ]
        return signals.contains(where: lower.contains)
            || !analyzer.numericClaims(in: value).isEmpty
    }

    private func inferredKind(from value: String) -> ExperienceKind {
        let lower = value.lowercased()
        if lower.contains("led ") || lower.contains("leadership") || lower.contains("managed ") { return .leadership }
        if lower.contains("stakeholder") || lower.contains("workshop") { return .stakeholder }
        if lower.contains("customer") || lower.contains("client") || lower.contains("service") { return .customerService }
        if lower.contains("resolved") || lower.contains("fixed") || lower.contains("problem") { return .problemSolved }
        if lower.contains("volunteer") || lower.contains("community") { return .volunteering }
        if lower.contains("degree") || lower.contains("university") || lower.contains("study") { return .study }
        return .project
    }

    private func inferredTools(in value: String) -> [String] {
        let knownTools = [
            "Excel", "Power BI", "Tableau", "SQL", "Python", "R", "SAS", "Salesforce", "SAP",
            "Jira", "Confluence", "SharePoint", "Microsoft Teams", "Azure", "AWS", "Git", "Swift"
        ]
        let lower = value.lowercased()
        return knownTools.filter { tool in
            let candidate = tool.lowercased()
            guard candidate.count > 1 else { return false }
            return lower.contains(candidate)
        }
    }

    private func deduplicated(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap { value in
            let clean = cleanLine(value)
            guard !clean.isEmpty else { return nil }
            let fingerprint = clean.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return seen.insert(fingerprint).inserted ? clean : nil
        }
    }
}
