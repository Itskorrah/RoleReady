import XCTest
@testable import RoleReady

final class EvidenceScorerTests: XCTestCase {
    func testCompleteEvidenceIsReady() {
        let score = EvidenceScorer().score(TestFixtures.experience())

        XCTAssertGreaterThanOrEqual(score.total, 75)
        XCTAssertEqual(score.readiness, .ready)
        XCTAssertGreaterThan(score.dimensions.first(where: { $0.dimension == .verification })?.value ?? 0, 0.7)
    }

    func testMissingOutcomeProducesConstructivePrompt() {
        let experience = TestFixtures.experience(result: "", evidence: "", learning: "")
        let score = EvidenceScorer().score(experience)

        XCTAssertNotEqual(score.readiness, .ready)
        XCTAssertNotNil(score.nextPrompt)
        XCTAssertLessThan(score.dimensions.first(where: { $0.dimension == .result })?.value ?? 1, 0.2)
    }

    func testSupportedOwnershipIsNotTreatedAsLed() {
        let led = EvidenceScorer().score(TestFixtures.experience(ownership: .led))
        let supported = EvidenceScorer().score(TestFixtures.experience(ownership: .supported))

        let ledOwnership = led.dimensions.first(where: { $0.dimension == .ownership })?.value ?? 0
        let supportedOwnership = supported.dimensions.first(where: { $0.dimension == .ownership })?.value ?? 0
        XCTAssertGreaterThan(ledOwnership, supportedOwnership)
    }
}

