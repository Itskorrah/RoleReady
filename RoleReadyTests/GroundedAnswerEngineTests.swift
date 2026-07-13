import XCTest
@testable import RoleReady

final class GroundedAnswerEngineTests: XCTestCase {
    private let engine = GroundedAnswerEngine()

    func testKeepsNumbersGroundedInSource() throws {
        let experience = TestFixtures.experience()
        let draft = try engine.generate(
            question: "Tell me about a process you improved.",
            from: experience,
            format: .sixtySeconds,
            audience: .technicalPanel,
            tone: .natural
        )

        XCTAssertTrue(draft.content.contains("42"))
        XCTAssertFalse(draft.content.contains("70%"))
        XCTAssertFalse(draft.warnings.contains { $0.localizedCaseInsensitiveContains("unsupported number") })
        XCTAssertGreaterThanOrEqual(draft.claims.count, 4)
        XCTAssertTrue(Set(draft.claims.map(\.sourceField)).isSuperset(of: ["Situation", "Responsibility", "Action", "Result"]))
    }

    func testSupportedWorkDoesNotBecomeLedWork() throws {
        let experience = TestFixtures.experience(
            task: "I supported the team by validating the revised workflow.",
            actions: ["I ran the regression suite and documented the mismatches."],
            ownership: .supported
        )
        let draft = try engine.generate(
            question: "How did you lead this work?",
            from: experience,
            format: .thirtySeconds,
            audience: .hiringManager,
            tone: .natural
        )

        XCTAssertFalse(draft.content.localizedCaseInsensitiveContains("I led"))
        XCTAssertFalse(draft.content.localizedCaseInsensitiveContains("I owned"))
    }

    func testMissingResultBlocksGeneration() {
        let experience = TestFixtures.experience(result: "")
        XCTAssertThrowsError(try engine.generate(
            question: "What happened?",
            from: experience,
            format: .sixtySeconds,
            audience: .recruiter,
            tone: .concise
        )) { error in
            XCTAssertEqual(error as? GroundedAnswerError, .missingResult)
        }
    }

    func testResumeBulletUsesOnlyActionAndResult() throws {
        let experience = TestFixtures.experience()
        let draft = try engine.generate(
            question: "Create a résumé bullet.",
            from: experience,
            format: .resumeBullet,
            audience: .recruiter,
            tone: .concise
        )

        XCTAssertTrue(draft.content.contains(";"))
        XCTAssertTrue(draft.claims.allSatisfy { ["Action", "Result"].contains($0.sourceField) })
    }

    func testContextLeadOnlyNamesCapabilitiesSupportedByStory() throws {
        let experience = TestFixtures.experience(capabilities: [.technicalProblemSolving, .dataQuality])

        let draft = try engine.generate(
            question: "Tell me about a time you showed leadership.",
            from: experience,
            format: .thirtySeconds,
            audience: .hiringManager,
            tone: .confident,
            roleTitle: "Data Platform Lead"
        )

        XCTAssertFalse(draft.content.localizedCaseInsensitiveContains("demonstrating leadership"))
        XCTAssertTrue(draft.content.contains("Data Platform Lead"))
    }

    func testManualEditWithUnsupportedNumberRequiresReview() {
        let warnings = engine.reviewWarnings(
            output: "I improved reliability by 99% and all 42 regression tests passed.",
            against: TestFixtures.experience()
        )

        XCTAssertTrue(warnings.contains { $0.localizedCaseInsensitiveContains("unsupported number") })
        XCTAssertTrue(warnings.contains { $0.contains("99%") })
    }

    func testSelectionCriteriaResponseKeepsCompleteSourceTrail() throws {
        let draft = try engine.generate(
            question: "Demonstrated experience improving data quality.",
            from: TestFixtures.experience(),
            format: .selectionCriteria,
            audience: .executivePanel,
            tone: .confident
        )

        XCTAssertTrue(Set(draft.claims.map(\.sourceField)).isSuperset(of: [
            "Situation", "Responsibility", "Action", "Result", "Evidence", "Learning"
        ]))
        XCTAssertFalse(draft.content.isEmpty)
    }
}
