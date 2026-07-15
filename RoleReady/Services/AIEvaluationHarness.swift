import Foundation

struct AIEvaluationMetric: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let score: Double
    let detail: String
}

struct AIEvaluationReport: Codable, Hashable, Sendable {
    let provider: LanguageServiceDescriptorSnapshot
    let fixtureVersion: Int
    let runAt: Date
    let caseCount: Int
    let successfulCaseCount: Int
    let metrics: [AIEvaluationMetric]
    let meanLatencyMilliseconds: Double
    let peakMemoryBytes: Int64?
    let downloadBytes: Int64?
    let batteryAndThermalNotes: String
    let failures: [String]
}

struct LanguageServiceDescriptorSnapshot: Codable, Hashable, Sendable {
    let id: String
    let displayName: String
    let modelName: String
    let sendsDataOffDevice: Bool

    init(_ descriptor: LanguageServiceDescriptor) {
        id = descriptor.id
        displayName = descriptor.displayName
        modelName = descriptor.modelName
        sendsDataOffDevice = descriptor.sendsDataOffDevice
    }
}

struct AIEvaluationHarness: Sendable {
    func evaluate(_ service: any RoleReadyLanguageService) async -> AIEvaluationReport {
        var scores: [AIEvaluationMetric] = []
        var latencies: [Double] = []
        var failures: [String] = []
        var successful = 0

        await measure(name: "Résumé extraction", latencies: &latencies, failures: &failures) {
            let result = try await service.extractCareerExamples(CareerExtractionRequest(text: Self.resumeFixture))
            let output = result.drafts.flatMap { [$0.title, $0.organisation, $0.result] + $0.actions }.joined(separator: " ").lowercased()
            let expected = ["migration", "example labs", "swift", "18%"]
            let matches = expected.filter(output.contains).count
            scores.append(AIEvaluationMetric(
                id: "resume-extraction",
                name: "Résumé extraction expected-field recall",
                score: Double(matches) / Double(expected.count),
                detail: "\(matches) of \(expected.count) synthetic facts recovered"
            ))
            successful += 1
        }

        await measure(name: "Job requirement extraction", latencies: &latencies, failures: &failures) {
            let result = try await service.groupRequirements(RequirementGroupingRequest(jobText: Self.jobFixture))
            let output = result.requirements.flatMap { [$0.text] + $0.keywords }.joined(separator: " ").lowercased()
            let expected = ["swift", "stakeholder", "testing"]
            let matches = expected.filter(output.contains).count
            scores.append(AIEvaluationMetric(
                id: "requirements",
                name: "Job requirement expected-field recall",
                score: Double(matches) / Double(expected.count),
                detail: "\(matches) of \(expected.count) synthetic requirements recovered"
            ))
            successful += 1
        }

        await measure(name: "Grounded STAR answer", latencies: &latencies, failures: &failures) {
            let request = AnswerCompositionRequest(
                question: "Tell me about a time you improved a technical process.",
                experience: Self.answerFixture,
                format: .sixtySeconds,
                audience: .technicalPanel,
                tone: .natural,
                roleTitle: "iOS Engineer"
            )
            let result = try await service.composeAnswer(request)
            let unsupported = result.claims.filter(\.needsSource).count
            scores.append(AIEvaluationMetric(
                id: "unsupported-claims",
                name: "Grounded answer claim support",
                score: result.claims.isEmpty ? 0 : 1 - Double(unsupported) / Double(result.claims.count),
                detail: "\(unsupported) unsupported clauses across \(result.claims.count) clauses"
            ))
            let ownershipSafe = !result.content.localizedCaseInsensitiveContains("I led")
                && !result.content.localizedCaseInsensitiveContains("I managed")
            scores.append(AIEvaluationMetric(
                id: "ownership",
                name: "Ownership safety",
                score: ownershipSafe ? 1 : 0,
                detail: ownershipSafe ? "No ownership escalation" : "Ownership wording exceeded the approved contributed level"
            ))
            successful += 1
        }

        let mean = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        return AIEvaluationReport(
            provider: LanguageServiceDescriptorSnapshot(service.descriptor),
            fixtureVersion: 1,
            runAt: Date(),
            caseCount: 3,
            successfulCaseCount: successful,
            metrics: scores,
            meanLatencyMilliseconds: mean,
            peakMemoryBytes: nil,
            downloadBytes: nil,
            batteryAndThermalNotes: "Unit harness only. Measure memory, battery, thermal behaviour and crash recovery on a physical device before shipping a downloadable model.",
            failures: failures
        )
    }

    private func measure(
        name: String,
        latencies: inout [Double],
        failures: inout [String],
        operation: () async throws -> Void
    ) async {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            try await operation()
        } catch {
            failures.append("\(name): \(error.localizedDescription)")
        }
        let elapsed = start.duration(to: clock.now)
        let components = elapsed.components
        latencies.append(Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1_000_000_000_000_000)
    }

    private static let resumeFixture = """
    Platform Migration
    Example Labs
    January 2024 – June 2024
    • Contributed Swift changes to migrate a legacy workflow.
    • Added regression tests and release checks.
    • Reduced failed release checks by 18% using the team dashboard.
    """

    private static let jobFixture = """
    iOS Engineer
    Example Company
    We are hiring an engineer to improve a customer-facing mobile product.
    Essential requirements
    • Demonstrated experience building production features with Swift.
    • Strong stakeholder communication across product and engineering teams.
    • Experience with automated testing and reliable release practices.
    """

    private static let answerFixture = GroundedExperience(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        title: "Release reliability improvement",
        organisation: "Example Labs",
        situation: "The mobile release checklist produced inconsistent results.",
        task: "I contributed the automated validation portion of the team improvement.",
        actions: [
            "I reviewed failed checks with the release engineer.",
            "I added Swift regression tests for the repeated failure paths.",
            "I documented the checks for the wider team."
        ],
        result: "Failed release checks fell by 18% in the team dashboard.",
        evidence: "The release dashboard showed the 18% reduction.",
        learning: "Small automated checks are easier to maintain when ownership is explicit.",
        ownership: .contributed,
        capabilities: [.technicalProblemSolving, .processImprovement],
        tools: ["Swift"],
        confidentiality: .standard,
        isApprovedForMatching: true
    )
}
