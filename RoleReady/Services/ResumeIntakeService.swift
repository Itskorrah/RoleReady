import Foundation

enum ResumeIntakeError: LocalizedError, Equatable, Sendable {
    case empty
    case tooShort
    case tooLarge
    case noUsefulContent

    var errorDescription: String? {
        switch self {
        case .empty:
            "Paste résumé text or choose a document first."
        case .tooShort:
            "This does not contain enough résumé content to review."
        case .tooLarge:
            "The résumé must be under 250,000 characters."
        case .noUsefulContent:
            "RoleReady could not identify résumé sections. You can still add your career information manually."
        }
    }
}

struct ResumeIntakeDraft: Hashable, Sendable {
    var sourceName: String
    var sourceText: String
    var contact: ResumeContact
    var headline: String
    var summary: String
    var positions: [PositionIntakeDraft]
    var education: [EducationIntakeDraft]
    var certifications: [CertificationIntakeDraft]
    var skills: [SkillIntakeDraft]
    var warnings: [String]

    var hasStructuredContent: Bool {
        !positions.isEmpty || !education.isEmpty || !certifications.isEmpty || !skills.isEmpty
    }
}

struct PositionIntakeDraft: Identifiable, Hashable, Sendable {
    var id = UUID()
    var title: String
    var organisation: String
    var location: String
    var dateText: String
    var startDate: Date?
    var endDate: Date?
    var isCurrent: Bool
    var bullets: [String]
    var skills: [String]
    var sourceExcerpt: String
    var sourceRange: Range<String.Index>?
    var isIncluded = true
}

struct EducationIntakeDraft: Identifiable, Hashable, Sendable {
    var id = UUID()
    var institution: String
    var qualification: String
    var fieldOfStudy: String
    var dateText: String
    var startDate: Date?
    var endDate: Date?
    var details: [String]
    var sourceExcerpt: String
    var sourceRange: Range<String.Index>?
    var isIncluded = true
}

struct CertificationIntakeDraft: Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var issuer: String
    var issuedAt: Date?
    var sourceExcerpt: String
    var sourceRange: Range<String.Index>?
    var isIncluded = true
}

struct SkillIntakeDraft: Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var category: String
    var sourceExcerpt: String
    var sourceRange: Range<String.Index>?
    var isIncluded = true
}

struct ResumeIntakeService: Sendable {
    private enum Section: String, CaseIterable {
        case summary
        case skills
        case experience
        case education
        case certifications
        case projects

        static func identify(_ line: String) -> Section? {
            let key = line
                .lowercased()
                .replacingOccurrences(of: "&", with: "and")
                .replacingOccurrences(of: #"[^a-z ]"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            return switch key {
            case "summary", "profile", "professional summary", "professional profile", "about": .summary
            case "skills", "technical skills", "core skills", "technologies", "tools and technologies": .skills
            case "experience", "work experience", "professional experience", "employment", "employment history", "career history": .experience
            case "education", "education and training", "academic background": .education
            case "certifications", "certificates", "certification", "licenses and certifications": .certifications
            case "projects", "selected projects", "technical projects": .projects
            default: nil
            }
        }
    }

    private let maximumCharacters = 250_000

    func extract(from source: String, sourceName: String = "Imported résumé") throws -> ResumeIntakeDraft {
        let text = normalize(source)
        guard !text.isEmpty else { throw ResumeIntakeError.empty }
        guard text.count >= 40 else { throw ResumeIntakeError.tooShort }
        guard text.count <= maximumCharacters else { throw ResumeIntakeError.tooLarge }

        let sourceLines = text.components(separatedBy: .newlines)
        let sectionRanges = findSections(in: sourceLines)
        let header = Array(sourceLines.prefix(sectionRanges.first?.lineIndex ?? min(sourceLines.count, 8)))
            .map(clean)
            .filter { !$0.isEmpty }

        let contact = extractContact(from: header, allText: text)
        let headline = extractHeadline(from: header, contact: contact)
        let summaryLines = lines(in: .summary, source: sourceLines, ranges: sectionRanges)
        let summary = summaryLines.map(clean).filter { !$0.isEmpty }.joined(separator: " ")
        let skills = extractSkills(
            from: lines(in: .skills, source: sourceLines, ranges: sectionRanges),
            source: text
        )
        let positions = extractPositions(
            from: lines(in: .experience, source: sourceLines, ranges: sectionRanges),
            source: text
        ) + extractPositions(
            from: lines(in: .projects, source: sourceLines, ranges: sectionRanges),
            source: text,
            defaultOrganisation: "Project"
        )
        let education = extractEducation(
            from: lines(in: .education, source: sourceLines, ranges: sectionRanges),
            source: text
        )
        let certifications = extractCertifications(
            from: lines(in: .certifications, source: sourceLines, ranges: sectionRanges),
            source: text
        )

        guard !summary.isEmpty || !headline.isEmpty || !positions.isEmpty || !education.isEmpty || !certifications.isEmpty || !skills.isEmpty else {
            throw ResumeIntakeError.noUsefulContent
        }

        var warnings = [
            "Everything extracted from this résumé is a draft until you review and approve it.",
            "Check dates, ownership, tools and outcomes against the source before using generated material."
        ]
        if positions.isEmpty {
            warnings.append("No clear employment blocks were found. Add roles manually or use the source text as a guide.")
        }
        return ResumeIntakeDraft(
            sourceName: sourceName,
            sourceText: text,
            contact: contact,
            headline: headline,
            summary: summary,
            positions: positions,
            education: education,
            certifications: certifications,
            skills: skills,
            warnings: warnings
        )
    }

    private struct SectionMarker {
        let section: Section
        let lineIndex: Int
    }

    private func findSections(in lines: [String]) -> [SectionMarker] {
        lines.enumerated().compactMap { index, line in
            guard let section = Section.identify(clean(line)) else { return nil }
            return SectionMarker(section: section, lineIndex: index)
        }
    }

    private func lines(
        in section: Section,
        source: [String],
        ranges: [SectionMarker]
    ) -> [String] {
        guard let markerIndex = ranges.firstIndex(where: { $0.section == section }) else { return [] }
        let start = ranges[markerIndex].lineIndex + 1
        let end = markerIndex + 1 < ranges.count ? ranges[markerIndex + 1].lineIndex : source.count
        guard start < end else { return [] }
        return Array(source[start..<end])
    }

    private func extractContact(from header: [String], allText: String) -> ResumeContact {
        let email = firstMatch(#"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#, in: allText, caseInsensitive: true)
        let phone = firstMatch(#"(?:\+?\d[\d ()-]{7,}\d)"#, in: header.joined(separator: " · "))
        let linkedIn = firstMatch(#"(?:https?://)?(?:www\.)?linkedin\.com/in/[A-Z0-9_\-/]+"#, in: allText, caseInsensitive: true)
        let portfolio = firstMatch(#"https?://(?![^ ]*linkedin\.com)[^\s|]+"#, in: allText, caseInsensitive: true)
        let name = header.first { line in
            !line.contains("@") && !line.contains("http") && !containsPhone(line) && line.count <= 80
        } ?? ""
        let location = header.dropFirst().first { line in
            !line.contains("@") && !line.contains("http") && !containsPhone(line) && line.count <= 80
                && !line.localizedCaseInsensitiveContains("engineer")
                && !line.localizedCaseInsensitiveContains("manager")
                && !line.localizedCaseInsensitiveContains("developer")
                && !line.localizedCaseInsensitiveContains("analyst")
        } ?? ""
        return ResumeContact(
            name: name,
            email: email,
            phone: phone,
            location: location,
            linkedIn: linkedIn,
            portfolio: portfolio
        )
    }

    private func extractHeadline(from header: [String], contact: ResumeContact) -> String {
        header.first { line in
            line != contact.name && line != contact.location && !line.contains(contact.email)
                && !line.contains(contact.phone) && !line.contains("http") && line.count <= 120
        } ?? ""
    }

    private func extractSkills(from lines: [String], source: String) -> [SkillIntakeDraft] {
        var drafts: [SkillIntakeDraft] = []
        for rawLine in lines {
            let line = clean(rawLine)
            guard !line.isEmpty else { continue }
            let categoryParts = line.split(separator: ":", maxSplits: 1).map(String.init)
            let category = categoryParts.count == 2 ? clean(categoryParts[0]) : ""
            let values = (categoryParts.count == 2 ? categoryParts[1] : line)
                .components(separatedBy: CharacterSet(charactersIn: ",|•;"))
                .map(clean)
                .filter { !$0.isEmpty && $0.count <= 60 }
            for value in values {
                let range = source.range(of: value, options: [.caseInsensitive, .diacriticInsensitive])
                drafts.append(SkillIntakeDraft(
                    name: value,
                    category: category,
                    sourceExcerpt: line,
                    sourceRange: range
                ))
            }
        }
        var seen = Set<String>()
        return drafts.filter { seen.insert($0.name.lowercased()).inserted }
    }

    private func extractPositions(
        from lines: [String],
        source: String,
        defaultOrganisation: String = ""
    ) -> [PositionIntakeDraft] {
        let blocks = splitIntoBlocks(lines)
        return blocks.compactMap { block in
            let cleaned = block.map(clean).filter { !$0.isEmpty }
            guard !cleaned.isEmpty else { return nil }
            let bullets = cleaned.filter(isBullet).map(stripBullet)
            let metadata = cleaned.filter { !isBullet($0) }
            guard !bullets.isEmpty || metadata.count >= 2 else { return nil }

            let dateLine = metadata.first(where: containsYear) ?? ""
            let nonDate = metadata.filter { $0 != dateLine }
            let headingParts = nonDate.first.map(splitHeading) ?? []
            let title = headingParts.first ?? nonDate.first ?? "Career role"
            let organisation = headingParts.dropFirst().first
                ?? nonDate.dropFirst().first
                ?? defaultOrganisation
            let excerpt = cleaned.joined(separator: "\n")
            let dates = parseDateRange(dateLine)
            return PositionIntakeDraft(
                title: title,
                organisation: organisation,
                location: "",
                dateText: dateLine,
                startDate: dates.start,
                endDate: dates.end,
                isCurrent: dates.isCurrent,
                bullets: Array(bullets.prefix(8)),
                skills: [],
                sourceExcerpt: excerpt,
                sourceRange: source.range(of: excerpt, options: [.caseInsensitive, .diacriticInsensitive])
            )
        }
    }

    private func extractEducation(from lines: [String], source: String) -> [EducationIntakeDraft] {
        splitIntoBlocks(lines).compactMap { block in
            let cleaned = block.map(clean).filter { !$0.isEmpty }
            guard !cleaned.isEmpty else { return nil }
            let dateLine = cleaned.first(where: containsYear) ?? ""
            let content = cleaned.filter { $0 != dateLine }.map(stripBullet)
            guard let first = content.first else { return nil }
            let likelyInstitutionIndex = content.firstIndex { value in
                let lower = value.lowercased()
                return lower.contains("university") || lower.contains("college") || lower.contains("institute") || lower.contains("school")
            }
            let institution = likelyInstitutionIndex.map { content[$0] } ?? content.dropFirst().first ?? ""
            let qualification = likelyInstitutionIndex == 0 ? content.dropFirst().first ?? "" : first
            let excerpt = cleaned.joined(separator: "\n")
            let dates = parseDateRange(dateLine)
            return EducationIntakeDraft(
                institution: institution,
                qualification: qualification,
                fieldOfStudy: "",
                dateText: dateLine,
                startDate: dates.start,
                endDate: dates.end,
                details: Array(content.dropFirst(2)),
                sourceExcerpt: excerpt,
                sourceRange: source.range(of: excerpt, options: [.caseInsensitive, .diacriticInsensitive])
            )
        }
    }

    private func extractCertifications(from lines: [String], source: String) -> [CertificationIntakeDraft] {
        lines.map(clean).filter { !$0.isEmpty }.map { line in
            let parts = splitHeading(line)
            let name = parts.first ?? line
            let issuer = parts.dropFirst().first ?? ""
            return CertificationIntakeDraft(
                name: name,
                issuer: issuer,
                issuedAt: parseDateRange(line).start,
                sourceExcerpt: line,
                sourceRange: source.range(of: line, options: [.caseInsensitive, .diacriticInsensitive])
            )
        }
    }

    private func splitIntoBlocks(_ lines: [String]) -> [[String]] {
        var blocks: [[String]] = []
        var current: [String] = []
        for line in lines {
            if clean(line).isEmpty {
                if !current.isEmpty { blocks.append(current); current = [] }
            } else if !current.isEmpty, !isBullet(line), current.contains(where: isBullet), looksLikeHeading(line) {
                blocks.append(current)
                current = [line]
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { blocks.append(current) }
        return blocks
    }

    private func splitHeading(_ value: String) -> [String] {
        value
            .components(separatedBy: #"\s+[|–—]\s+"#, options: [])
            .flatMap { $0.components(separatedBy: " at ") }
            .map(clean)
            .filter { !$0.isEmpty }
    }

    func parseDateRange(_ value: String) -> (start: Date?, end: Date?, isCurrent: Bool) {
        let lower = value.lowercased()
        let years = allMatches(#"(?:19|20)\d{2}"#, in: value).compactMap(Int.init)
        let calendar = Calendar(identifier: .gregorian)
        func date(_ year: Int, month: Int) -> Date? {
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
        let start = years.first.flatMap { date($0, month: 1) }
        let isCurrent = lower.contains("present") || lower.contains("current") || lower.contains("now")
        let end = isCurrent ? nil : years.dropFirst().first.flatMap { date($0, month: 12) }
        return (start, end, isCurrent)
    }

    private func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isBullet(_ line: String) -> Bool {
        clean(line).range(of: #"^(?:[-•▪◦*]|\d+[.)])\s+"#, options: .regularExpression) != nil
    }

    private func stripBullet(_ value: String) -> String {
        clean(value).replacingOccurrences(of: #"^(?:[-•▪◦*]|\d+[.)])\s+"#, with: "", options: .regularExpression)
    }

    private func containsYear(_ value: String) -> Bool {
        value.range(of: #"(?:19|20)\d{2}"#, options: .regularExpression) != nil
            || value.localizedCaseInsensitiveContains("present")
    }

    private func looksLikeHeading(_ value: String) -> Bool {
        let cleaned = clean(value)
        return !isBullet(cleaned) && cleaned.count <= 140 && !cleaned.hasSuffix(".")
    }

    private func containsPhone(_ value: String) -> Bool {
        value.range(of: #"(?:\+?\d[\d ()-]{7,}\d)"#, options: .regularExpression) != nil
    }

    private func firstMatch(_ pattern: String, in source: String, caseInsensitive: Bool = false) -> String {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let range = Range(match.range, in: source) else { return "" }
        return String(source[range])
    }

    private func allMatches(_ pattern: String, in source: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).compactMap { match in
            Range(match.range, in: source).map { String(source[$0]) }
        }
    }
}

private extension String {
    func components(separatedBy pattern: String, options: NSRegularExpression.Options) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [self] }
        let range = NSRange(startIndex..., in: self)
        var values: [String] = []
        var cursor = startIndex
        for match in regex.matches(in: self, range: range) {
            guard let matchRange = Range(match.range, in: self) else { continue }
            values.append(String(self[cursor..<matchRange.lowerBound]))
            cursor = matchRange.upperBound
        }
        values.append(String(self[cursor...]))
        return values
    }
}
