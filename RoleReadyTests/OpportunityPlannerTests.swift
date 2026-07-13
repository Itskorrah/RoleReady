import XCTest
@testable import RoleReady

final class OpportunityPlannerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    func testActiveOpportunityChoosesNearestUpcomingInterview() {
        let closingSoon = opportunity(
            title: "Analytics Engineer",
            status: .preparing,
            closingDate: now.addingTimeInterval(86_400)
        )
        let interviewSooner = opportunity(
            title: "Data Platform Lead",
            status: .interviewing,
            interviewDate: now.addingTimeInterval(3_600)
        )
        let closed = opportunity(
            title: "Closed role",
            status: .closed,
            interviewDate: now.addingTimeInterval(1_800)
        )

        let selected = OpportunityPlanner().activeOpportunity(
            from: [closingSoon, interviewSooner, closed],
            now: now
        )

        XCTAssertEqual(selected?.id, interviewSooner.id)
    }

    func testLatestUnreflectedInterviewSkipsCompletedReflection() {
        let older = opportunity(
            title: "Data Analyst",
            status: .closed,
            interviewDate: now.addingTimeInterval(-7_200)
        )
        let newer = opportunity(
            title: "Senior Data Engineer",
            status: .interviewing,
            interviewDate: now.addingTimeInterval(-3_600)
        )

        let selected = OpportunityPlanner().latestUnreflectedInterview(
            from: [older, newer],
            reflectedOpportunityIDs: [newer.id],
            now: now
        )

        XCTAssertEqual(selected?.id, older.id)
    }

    func testReminderLeadTimesAdaptToInterviewProximity() throws {
        let service = NotificationService()

        XCTAssertEqual(
            try service.reminderDate(for: now.addingTimeInterval(48 * 3_600), now: now).timeIntervalSince1970,
            now.addingTimeInterval(24 * 3_600).timeIntervalSince1970,
            accuracy: 0.1
        )
        XCTAssertEqual(
            try service.reminderDate(for: now.addingTimeInterval(6 * 3_600), now: now).timeIntervalSince1970,
            now.addingTimeInterval(5 * 3_600).timeIntervalSince1970,
            accuracy: 0.1
        )
        XCTAssertEqual(
            try service.reminderDate(for: now.addingTimeInterval(45 * 60), now: now).timeIntervalSince1970,
            now.addingTimeInterval(35 * 60).timeIntervalSince1970,
            accuracy: 0.1
        )
    }

    func testReminderRejectsInterviewThatIsTooClose() {
        XCTAssertThrowsError(
            try NotificationService().reminderDate(
                for: now.addingTimeInterval(10 * 60),
                now: now
            )
        ) { error in
            guard let notificationError = error as? NotificationServiceError,
                  case .tooSoon = notificationError else {
                return XCTFail("Expected a tooSoon error, got \(error)")
            }
        }
    }

    private func opportunity(
        title: String,
        status: OpportunityStatus,
        closingDate: Date? = nil,
        interviewDate: Date? = nil
    ) -> Opportunity {
        Opportunity(
            roleTitle: title,
            organisation: "Northstar Energy",
            location: "Sydney · Hybrid",
            sourceText: "Role description",
            status: status,
            closingDate: closingDate,
            interviewDate: interviewDate
        )
    }
}
