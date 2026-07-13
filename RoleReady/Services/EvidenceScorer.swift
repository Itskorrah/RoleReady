import Foundation

enum EvidenceDimension: String, CaseIterable, Identifiable {
    case context
    case ownership
    case action
    case decisionMaking
    case result
    case verification
    case relevance
    case reflection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .context: "Context"
        case .ownership: "Ownership"
        case .action: "Specific actions"
        case .decisionMaking: "Decision-making"
        case .result: "Result"
        case .verification: "Proof"
        case .relevance: "Capabilities"
        case .reflection: "Reflection"
        }
    }
}

struct DimensionScore: Identifiable, Hashable {
    let dimension: EvidenceDimension
    let value: Double
    let guidance: String

    var id: String { dimension.rawValue }
    var percentage: Int { Int((value * 100).rounded()) }
}

enum EvidenceReadiness: String {
    case ready
    case nearlyReady
    case building

    var title: String {
        switch self {
        case .ready: "Ready"
        case .nearlyReady: "Nearly ready"
        case .building: "Build the proof"
        }
    }
}

struct EvidenceScore: Hashable {
    let total: Int
    let readiness: EvidenceReadiness
    let dimensions: [DimensionScore]
    let nextPrompt: String?

    var strongest: DimensionScore? { dimensions.max(by: { $0.value < $1.value }) }
}

struct EvidenceScorer {
    private let analyzer = TextAnalyzer()

    func score(_ experience: Experience) -> EvidenceScore {
        let actionsText = experience.actions.joined(separator: " ")
        let context = quality(experience.situation, targetWords: 16)
        let ownership = ownershipScore(experience)
        let action = min(
            1,
            0.35 * min(Double(experience.actions.count) / 2, 1)
                + 0.65 * quality(actionsText, targetWords: 28)
        )
        let decision = decisionScore(actionsText)
        let result = resultScore(experience.result)
        let verification = verificationScore(experience)
        let relevance = min(Double(experience.capabilities.count) / 3, 1)
        let reflection = quality(experience.learning, targetWords: 10)

        let dimensions = [
            DimensionScore(dimension: .context, value: context, guidance: "Add just enough background to understand why the work mattered."),
            DimensionScore(dimension: .ownership, value: ownership, guidance: "Make your personal responsibility unmistakable."),
            DimensionScore(dimension: .action, value: action, guidance: "Name the concrete steps you personally took."),
            DimensionScore(dimension: .decisionMaking, value: decision, guidance: "Explain one choice, trade-off, or reason behind your approach."),
            DimensionScore(dimension: .result, value: result, guidance: "Describe what changed because of the work."),
            DimensionScore(dimension: .verification, value: verification, guidance: "Add a measurement, observation, sign-off, test, or other proof."),
            DimensionScore(dimension: .relevance, value: relevance, guidance: "Choose the capabilities this story genuinely demonstrates."),
            DimensionScore(dimension: .reflection, value: reflection, guidance: "Capture what you learnt or would repeat next time.")
        ]

        let weights: [EvidenceDimension: Double] = [
            .context: 0.10,
            .ownership: 0.14,
            .action: 0.20,
            .decisionMaking: 0.10,
            .result: 0.18,
            .verification: 0.14,
            .relevance: 0.08,
            .reflection: 0.06
        ]
        let total = Int(dimensions.reduce(0) { partial, item in
            partial + item.value * (weights[item.dimension] ?? 0)
        } * 100)
        let readiness: EvidenceReadiness = total >= 78 ? .ready : (total >= 56 ? .nearlyReady : .building)
        let next = dimensions
            .filter { $0.value < 0.78 }
            .max(by: { lhs, rhs in
                let leftWeight = weights[lhs.dimension] ?? 0
                let rightWeight = weights[rhs.dimension] ?? 0
                return (1 - lhs.value) * leftWeight < (1 - rhs.value) * rightWeight
            })

        return EvidenceScore(total: total, readiness: readiness, dimensions: dimensions, nextPrompt: next?.guidance)
    }

    private func quality(_ text: String, targetWords: Int) -> Double {
        guard targetWords > 0 else { return 1 }
        return min(Double(analyzer.tokens(in: text, includeStopWords: true).count) / Double(targetWords), 1)
    }

    private func ownershipScore(_ experience: Experience) -> Double {
        let base: Double
        switch experience.ownership {
        case .led, .owned: base = 1
        case .contributed: base = 0.82
        case .supported: base = 0.72
        }
        let personalLanguage = experience.actions.joined(separator: " ").lowercased().contains("i ") ? 1.0 : 0.65
        return base * personalLanguage
    }

    private func decisionScore(_ text: String) -> Double {
        let lower = text.lowercased()
        let signals = ["because", "chose", "decided", "instead", "option", "priorit", "trade-off", "why", "so that"]
        return signals.contains(where: lower.contains) ? 1 : min(quality(text, targetWords: 32) * 0.65, 0.65)
    }

    private func resultScore(_ text: String) -> Double {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return 0 }
        let outcomeSignals = ["improved", "reduced", "completed", "passed", "matched", "approved", "delivered", "prevented", "resolved", "reported", "adopted"]
        let signal = outcomeSignals.contains(where: text.lowercased().contains) ? 0.25 : 0
        return min(quality(text, targetWords: 14) * 0.75 + signal, 1)
    }

    private func verificationScore(_ experience: Experience) -> Double {
        guard !experience.evidence.isEmpty || !experience.result.isEmpty else { return 0 }
        let combined = experience.result + " " + experience.evidence
        let hasNumber = !analyzer.numericClaims(in: combined).isEmpty
        let proofSignals = ["approved", "baseline", "feedback", "measured", "reported", "sign-off", "tested", "verified"]
        let hasProof = proofSignals.contains(where: combined.lowercased().contains)
        let detail = quality(combined, targetWords: 18) * 0.55
        return min(detail + (hasNumber ? 0.25 : 0) + (hasProof ? 0.25 : 0), 1)
    }
}
