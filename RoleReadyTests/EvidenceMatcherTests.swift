import XCTest
@testable import RoleReady

final class EvidenceMatcherTests: XCTestCase {
    func testRanksRelevantReadyStoryFirst() {
        let python = TestFixtures.experience(
            title: "Rebuilt a Python pipeline",
            capabilities: [.technicalProblemSolving, .dataQuality, .delivery],
            tools: ["Python", "Polars", "pytest"]
        )
        let customer = TestFixtures.experience(
            title: "Resolved a customer complaint",
            situation: "A customer needed help understanding a delayed service response.",
            task: "I supported the service team with a clear response.",
            actions: ["I listened to the customer and clarified the next steps."],
            result: "The customer accepted the resolution.",
            evidence: "The service ticket was closed with positive feedback.",
            ownership: .supported,
            capabilities: [.customerFocus, .stakeholderCommunication],
            tools: ["CRM"]
        )
        let requirement = JobRequirement(
            opportunityID: UUID(),
            text: "Build reliable Python data pipelines using automated testing and data-quality controls.",
            kind: .mustHave,
            keywords: ["Python", "data pipelines", "automated testing"],
            capabilities: [.technicalProblemSolving, .dataQuality, .delivery],
            importance: 3
        )

        let matches = EvidenceMatcher().rank(requirement: requirement, against: [customer, python])

        XCTAssertEqual(matches.first?.experienceID, python.id)
        XCTAssertEqual(matches.first?.tier, .strong)
        XCTAssertTrue(matches.first?.matchedTerms.contains("python") == true)
        XCTAssertFalse(matches.first?.explanation.isEmpty == true)
    }

    func testHighlySensitiveStoryIsExcludedFromAutomaticRanking() {
        let sensitive = TestFixtures.experience(confidentiality: .highlySensitive)
        sensitive.isApprovedForMatching = false
        let requirement = JobRequirement(
            opportunityID: UUID(),
            text: "Modernise a Python workflow.",
            kind: .mustHave,
            keywords: ["Python"],
            capabilities: [.technicalProblemSolving]
        )

        XCTAssertTrue(EvidenceMatcher().rank(requirement: requirement, against: [sensitive]).isEmpty)
    }
}

