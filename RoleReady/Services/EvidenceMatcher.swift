import Foundation

enum MatchTier: String {
    case strong
    case promising
    case gap

    var title: String {
        switch self {
        case .strong: "Strong proof"
        case .promising: "Could support"
        case .gap: "Evidence gap"
        }
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

    func rank(requirement: JobRequirement, against experiences: [Experience], now: Date = Date()) -> [EvidenceMatch] {
        let requirementTerms = Set(analyzer.tokens(in: requirement.text + " " + requirement.keywords.joined(separator: " ")))
        let inferredCapabilities = Set(requirement.capabilities.isEmpty ? analyzer.inferCapabilities(from: requirement.text) : requirement.capabilities)

        return experiences.compactMap { experience -> EvidenceMatch? in
            guard experience.isApprovedForMatching, !experience.confidentiality.blocksAutomaticUse else { return nil }
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
            let unionCount = max(requirementTerms.union(experienceTerms).count, 1)
            let lexical = (
                min(Double(overlap.count) / Double(max(min(requirementTerms.count, 10), 1)) * 1.4, 1) * 0.8
                    + Double(overlap.count) / Double(unionCount) * 0.2
            )
            let capabilityMatches = inferredCapabilities.intersection(Set(experience.capabilities)).sorted { $0.title < $1.title }
            let capability = inferredCapabilities.isEmpty ? 0.45 : Double(capabilityMatches.count) / Double(inferredCapabilities.count)
            let toolTokens = Set(experience.tools.flatMap { analyzer.tokens(in: $0) })
            let tools = requirementTerms.isEmpty ? 0 : min(Double(requirementTerms.intersection(toolTokens).count) / 2, 1)
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
            let score = lexical * 0.40 + capability * 0.20 + tools * 0.12 + readiness * 0.16 + recency * 0.06 + ownership * 0.06
            let tier: MatchTier = score >= 0.62 ? .strong : (score >= 0.34 ? .promising : .gap)
            var cautions: [String] = []
            let evidenceScore = scorer.score(experience)
            if evidenceScore.total < 56 { cautions.append("Strengthen this story before relying on it in an interview.") }
            if experience.result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { cautions.append("The outcome is not recorded yet.") }
            if experience.ownership == .supported { cautions.append("Keep the wording clear that you supported this work.") }
            if experience.confidentiality >= .confidential { cautions.append("Review confidential detail before using this story.") }

            let explanation = explanation(
                title: experience.title,
                overlap: overlap,
                capabilities: capabilityMatches,
                readiness: evidenceScore.readiness
            )
            return EvidenceMatch(
                id: experience.id,
                requirementID: requirement.id,
                experienceID: experience.id,
                score: score,
                tier: tier,
                matchedTerms: overlap,
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

    private func explanation(
        title: String,
        overlap: [String],
        capabilities: [Capability],
        readiness: EvidenceReadiness
    ) -> String {
        let terms = overlap.prefix(4).joined(separator: ", ")
        let capabilityText = capabilities.prefix(2).map(\.title).joined(separator: " and ")
        if !terms.isEmpty, !capabilityText.isEmpty {
            return "“\(title)” matches \(capabilityText.lowercased()) and shares specific evidence around \(terms). The story is \(readiness.title.lowercased())."
        }
        if !capabilityText.isEmpty {
            return "“\(title)” demonstrates \(capabilityText.lowercased()), although the wording has limited direct overlap with this requirement."
        }
        if !terms.isEmpty {
            return "“\(title)” shares specific terms—\(terms)—but the capability fit needs your review."
        }
        return "No direct evidence link was found. Keep this as a gap or choose a story manually."
    }
}
