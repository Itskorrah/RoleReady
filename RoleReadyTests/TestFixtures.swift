import Foundation
@testable import RoleReady

enum TestFixtures {
    static func experience(
        id: UUID = UUID(),
        title: String = "Modernised a reporting workflow",
        situation: String = "A legacy monthly reporting workflow was difficult to maintain and regularly delayed quality review.",
        task: String = "I owned the redesign while preserving the approved output rules.",
        actions: [String] = [
            "I mapped the current rules and chose modular processing stages because each stage could be tested independently.",
            "I added schema validation and automated regression tests before switching the workflow."
        ],
        result: String = "The new workflow matched the approved baseline and all 42 regression tests passed.",
        evidence: String = "The quality lead approved the comparison report and test run.",
        learning: String = "I learnt to agree parity criteria before beginning a migration.",
        ownership: OwnershipLevel = .owned,
        capabilities: [Capability] = [.technicalProblemSolving, .processImprovement, .dataQuality],
        tools: [String] = ["Python", "SQL", "pytest"],
        confidentiality: Confidentiality = .privateRecord
    ) -> Experience {
        Experience(
            id: id,
            title: title,
            organisation: "Example Analytics",
            occurredAt: Date(timeIntervalSince1970: 1_735_689_600),
            kind: .project,
            situation: situation,
            task: task,
            actions: actions,
            result: result,
            evidence: evidence,
            learning: learning,
            ownership: ownership,
            capabilities: capabilities,
            tools: tools,
            confidentiality: confidentiality
        )
    }
}

