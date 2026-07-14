import XCTest
@testable import RoleReady

final class CareerHistoryIngestionServiceTests: XCTestCase {
    private let service = CareerHistoryIngestionService()

    func testResumeSectionsBecomeConservativeUnverifiedDrafts() throws {
        let result = try service.extractDrafts(from: """
        Senior Service Designer | Department of Community Services | 2024
        • Mapped a high-volume grants assessment process with policy and operations staff.
        • I chose a staged pilot because the policy deadline could not move, then tested the workflow with assessors.
        • The approved pilot reduced avoidable rework and the branch adopted the revised process.

        Project Officer | State Infrastructure Agency | 2022
        • Coordinated weekly risk reviews across three delivery teams.
        • Recorded decisions and escalated unresolved dependencies to the program lead.
        • The steering committee accepted the recovery plan before the next milestone.
        """)

        XCTAssertGreaterThanOrEqual(result.drafts.count, 1)
        XCTAssertTrue(result.drafts.allSatisfy { $0.ownership == .contributed })
        XCTAssertTrue(result.drafts.allSatisfy(\.isIncluded))
        XCTAssertTrue(result.warnings.joined().localizedCaseInsensitiveContains("unverified"))
        XCTAssertTrue(result.drafts.contains { !$0.actions.isEmpty && !$0.sourceExcerpt.isEmpty })
    }

    func testRoughNotesStillProduceOneReviewableDraft() throws {
        let result = try service.extractDrafts(from: """
        During a difficult service release I documented the recurring incidents.
        I worked with support staff to compare the failures and chose a smaller staged rollout.
        The release owner approved the approach after the validation checks passed.
        """)

        XCTAssertEqual(result.drafts.count, 1)
        XCTAssertFalse(result.drafts[0].title.isEmpty)
        XCTAssertTrue(result.drafts[0].warnings.contains { $0.localizedCaseInsensitiveContains("confirm") })
    }

    func testCombiningDraftsNeverUpgradesOwnership() throws {
        let result = try service.extractDrafts(from: """
        Project Lead | Service Agency | 2024
        • I mapped the approval process and documented the risks.
        • The branch approved the revised workflow after a controlled pilot.

        Project Lead | Service Agency | 2024
        • I chose a staged rollout because operations could not pause processing.
        • Feedback from assessors confirmed that the revised guidance was clearer.
        """)
        let combined = try XCTUnwrap(service.combine(result.drafts))

        XCTAssertEqual(combined.ownership, .contributed)
        XCTAssertGreaterThanOrEqual(combined.actions.count, 2)
        XCTAssertTrue(combined.warnings.contains { $0.localizedCaseInsensitiveContains("confirm") })
    }

    func testRejectsEmptyShortAndOversizedSources() {
        XCTAssertThrowsError(try service.extractDrafts(from: "")) {
            XCTAssertEqual($0 as? CareerHistoryIngestionError, .empty)
        }
        XCTAssertThrowsError(try service.extractDrafts(from: "too short")) {
            XCTAssertEqual($0 as? CareerHistoryIngestionError, .tooShort)
        }
        XCTAssertThrowsError(try service.extractDrafts(from: String(repeating: "a", count: 250_001))) {
            XCTAssertEqual($0 as? CareerHistoryIngestionError, .tooLarge)
        }
    }
}
