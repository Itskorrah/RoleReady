import Foundation

struct ParsedRequirement: Identifiable, Hashable, Sendable {
    let id: UUID
    var text: String
    var kind: RequirementKind
    var keywords: [String]
    var capabilities: [Capability]
    var importance: Int
}

struct ParsedJob: Hashable, Sendable {
    var suggestedTitle: String
    var suggestedOrganisation: String
    var requirements: [ParsedRequirement]
    var warnings: [String]
}

enum JobParserError: LocalizedError, Equatable, Sendable {
    case empty
    case tooShort
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .empty: "There is no job text to analyse."
        case .tooShort: "Add a little more of the job advertisement so requirements can be found."
        case .tooLarge: "This job advertisement is too large. Import a document under 250,000 characters."
        }
    }
}

struct JobParser {
    private let analyzer = TextAnalyzer()
    private let requirementSignals = [
        "must", "required", "essential", "experience in", "experience with", "demonstrated", "ability to", "responsible for",
        "you will", "you'll", "proficient", "knowledge of", "skills in", "capable of", "qualification", "key responsibilities"
    ]

    func parse(_ source: String) throws -> ParsedJob {
        let clean = normalise(source)
        guard !clean.isEmpty else { throw JobParserError.empty }
        guard clean.count >= 80 else { throw JobParserError.tooShort }
        guard clean.count <= 250_000 else { throw JobParserError.tooLarge }

        let lines = clean.components(separatedBy: .newlines)
            .map(cleanLine)
            .filter { !$0.isEmpty }
        let title = inferTitle(from: lines)
        let organisation = inferOrganisation(from: lines, excluding: title)

        var candidates: [(String, RequirementKind, Int)] = []
        var currentKind: RequirementKind = .responsibility
        for line in lines {
            if let headingKind = kindForHeading(line) {
                currentKind = headingKind
                continue
            }
            let bullet = isBullet(line)
            let body = stripBullet(line)
            let lower = body.lowercased()
            guard body.count >= 18, body.count <= 420 else { continue }
            if bullet || requirementSignals.contains(where: lower.contains) {
                let kind = requirementKind(for: lower, fallback: currentKind)
                let importance = kind == .mustHave ? 3 : (kind == .responsibility ? 2 : 1)
                candidates.append((body, kind, importance))
            }
        }

        if candidates.count < 3 {
            let sentenceCandidates = clean
                .components(separatedBy: CharacterSet(charactersIn: ".;\n"))
                .map(cleanLine)
                .filter { sentence in
                    sentence.count >= 24 && sentence.count <= 360
                        && requirementSignals.contains(where: sentence.lowercased().contains)
                }
            candidates.append(contentsOf: sentenceCandidates.map { sentence in
                let kind = requirementKind(for: sentence.lowercased(), fallback: .responsibility)
                return (sentence, kind, kind == .mustHave ? 3 : 2)
            })
        }

        var seen: Set<String> = []
        let requirements = candidates.compactMap { text, kind, importance -> ParsedRequirement? in
            let fingerprint = analyzer.tokens(in: text).prefix(10).joined(separator: " ")
            guard !fingerprint.isEmpty, seen.insert(fingerprint).inserted else { return nil }
            return ParsedRequirement(
                id: UUID(),
                text: text,
                kind: kind,
                keywords: analyzer.keywords(in: text, limit: 8),
                capabilities: analyzer.inferCapabilities(from: text),
                importance: importance
            )
        }
        .prefix(24)

        var warnings: [String] = []
        if requirements.isEmpty {
            warnings.append("No clear requirement statements were found. Add them manually before matching.")
        } else if requirements.count < 4 {
            warnings.append("Only a few clear requirements were found. Review the source for anything missing.")
        }

        return ParsedJob(
            suggestedTitle: title,
            suggestedOrganisation: organisation,
            requirements: Array(requirements),
            warnings: warnings
        )
    }

    private func normalise(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
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
        line.replacingOccurrences(of: #"^(?:[•\-–—*▪◦]|\d+[.)])\s*"#, with: "", options: .regularExpression)
    }

    private func kindForHeading(_ line: String) -> RequirementKind? {
        let lower = line.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard line.count < 70 else { return nil }
        if lower.contains("essential") || lower.contains("must have") || lower.contains("qualification") || lower.contains("requirements") {
            return .mustHave
        }
        if lower.contains("responsibil") || lower.contains("what you'll do") || lower.contains("about the role") {
            return .responsibility
        }
        if lower.contains("desirable") || lower.contains("nice to have") || lower.contains("who you are") {
            return .signal
        }
        return nil
    }

    private func requirementKind(for lower: String, fallback: RequirementKind) -> RequirementKind {
        if ["must", "required", "essential", "qualification", "demonstrated"].contains(where: lower.contains) { return .mustHave }
        if ["desirable", "preferred", "nice to have"].contains(where: lower.contains) { return .signal }
        return fallback
    }

    private func inferTitle(from lines: [String]) -> String {
        lines.prefix(6).first(where: { line in
            line.count >= 4 && line.count <= 80
                && !isBullet(line)
                && !requirementSignals.contains(where: line.lowercased().contains)
                && ["engineer", "analyst", "manager", "advisor", "consultant", "developer", "officer", "specialist", "lead", "coordinator"]
                    .contains(where: line.lowercased().contains)
        }) ?? ""
    }

    private func inferOrganisation(from lines: [String], excluding title: String) -> String {
        let candidates = lines.prefix(8).filter { $0 != title && $0.count >= 2 && $0.count <= 70 && !isBullet($0) }
        return candidates.first(where: { line in
            let lower = line.lowercased()
            return lower.hasPrefix("at ") || lower.contains("company") || lower.contains("organisation")
        })?.replacingOccurrences(of: #"^(?:at|company:|organisation:)\s*"#, with: "", options: [.regularExpression, .caseInsensitive]) ?? ""
    }
}
