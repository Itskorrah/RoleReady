import XCTest
@testable import RoleReady

final class EvidenceMatcherTrustTests: XCTestCase {
    private let matcher = EvidenceMatcher()

    func testCompleteButIrrelevantStoryCannotManufactureAHighMatch() throws {
        let irrelevant = TestFixtures.experience(
            title: "Resolved a customer billing enquiry",
            situation: "A customer disputed a bill and needed a plain-language explanation.",
            task: "I supported the service desk response.",
            actions: ["I listened to the customer, checked the account notes and explained the next step."],
            result: "The customer accepted the explanation and the service ticket was closed.",
            evidence: "The closed ticket recorded positive customer feedback.",
            capabilities: [.customerFocus, .stakeholderCommunication],
            tools: ["CRM"]
        )
        let requirement = requirement(
            "Design Kubernetes operators and manage production container orchestration.",
            capabilities: [.technicalProblemSolving]
        )

        let match = try XCTUnwrap(matcher.rank(requirement: requirement, against: [irrelevant]).first)

        XCTAssertEqual(match.tier, .none)
        XCTAssertEqual(match.score, 0)
        XCTAssertFalse(match.tier.allowsAnswer)
    }

    func testCapabilityFitWithoutDirectWordingIsTransferableNotDirect() throws {
        let transferable = TestFixtures.experience(
            title: "Coordinated a difficult policy decision",
            capabilities: [.leadership],
            tools: []
        )
        let requirement = requirement(
            "Lead a multidisciplinary branch through ambiguous organisational change.",
            capabilities: [.leadership]
        )

        let match = try XCTUnwrap(matcher.rank(requirement: requirement, against: [transferable]).first)

        XCTAssertEqual(match.tier, .transferable)
        XCTAssertTrue(match.tier.allowsAnswer)
        XCTAssertEqual(match.matchedCapabilities, [.leadership])
        XCTAssertFalse(match.explanation.isEmpty)
    }

    func testLooseLexicalOverlapWithoutCapabilityEvidenceStaysWeak() throws {
        let partial = TestFixtures.experience(
            title: "Prepared a delivery update",
            situation: "A team needed a delivery update before its weekly meeting.",
            task: "I prepared the update.",
            actions: ["I gathered portfolio governance delivery notes and shared the delivery update."],
            result: "The portfolio governance update was sent before the meeting.",
            evidence: "The email confirms delivery.",
            capabilities: [.stakeholderCommunication],
            tools: []
        )
        let requirement = requirement(
            "Own enterprise delivery governance, portfolio prioritisation and benefits assurance.",
            capabilities: [.planning, .accountability]
        )

        let match = try XCTUnwrap(matcher.rank(requirement: requirement, against: [partial]).first)

        XCTAssertEqual(match.tier, .weak)
        XCTAssertFalse(match.tier.allowsAnswer)
    }

    func testOneSharedTermAndCapabilityCannotBecomeDirectEvidence() throws {
        let partial = TestFixtures.experience(
            title: "Led an internal planning session",
            situation: "A team needed a plan for its quarterly priorities.",
            task: "I led one planning workshop.",
            actions: ["I led the workshop and recorded the team priorities."],
            result: "The team agreed its quarterly plan.",
            evidence: "The approved plan recorded the priorities.",
            capabilities: [.leadership],
            tools: []
        )
        let requirement = requirement(
            "Lead complex commercial negotiations with external suppliers.",
            capabilities: [.leadership]
        )

        let match = try XCTUnwrap(matcher.rank(requirement: requirement, against: [partial]).first)

        XCTAssertNotEqual(match.tier, .direct)
        XCTAssertLessThan(match.matchedTerms.count, 3)
    }

    private func requirement(_ text: String, capabilities: [Capability]) -> JobRequirement {
        JobRequirement(
            opportunityID: UUID(),
            text: text,
            kind: .mustHave,
            keywords: [],
            capabilities: capabilities,
            importance: 3
        )
    }
}
