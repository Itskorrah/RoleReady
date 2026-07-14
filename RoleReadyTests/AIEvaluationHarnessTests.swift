import XCTest
@testable import RoleReady

final class AIEvaluationHarnessTests: XCTestCase {
    func testDeterministicProviderPassesSyntheticGroundingHarness() async {
        let report = await AIEvaluationHarness().evaluate(DeterministicLanguageService())

        XCTAssertEqual(report.caseCount, 3)
        XCTAssertEqual(report.successfulCaseCount, 3)
        XCTAssertTrue(report.failures.isEmpty)
        XCTAssertEqual(report.metrics.first(where: { $0.id == "unsupported-claims" })?.score, 1)
        XCTAssertEqual(report.metrics.first(where: { $0.id == "ownership" })?.score, 1)
        XCTAssertFalse(report.provider.sendsDataOffDevice)
    }

    func testAutomaticProviderAlwaysResolvesToAvailablePrivateService() {
        let service = LanguageProviderRegistry().resolvedService(for: .automatic)

        XCTAssertTrue(service.descriptor.isAvailable)
        XCTAssertFalse(service.descriptor.sendsDataOffDevice)
    }

    func testCloudTransportRequiresConsentThenSecureBackend() async {
        let request = CloudGenerationEnvelope(
            requestID: UUID(),
            task: "cover-letter",
            approvedSourceIDs: [],
            approvedSourceExcerpts: [],
            requestedSchemaVersion: 1
        )
        let missingConsent = CloudAIConsent(
            approvedSourceIDs: [],
            includesHighlySensitiveData: false,
            confirmedAt: nil
        )
        do {
            _ = try await DisabledPremiumCloudTransport().send(request, consent: missingConsent)
            XCTFail("Expected consent failure")
        } catch {
            XCTAssertEqual(error as? LanguageServiceError, .explicitConsentRequired)
        }

        let approved = CloudAIConsent(
            approvedSourceIDs: [],
            includesHighlySensitiveData: false,
            confirmedAt: Date()
        )
        do {
            _ = try await DisabledPremiumCloudTransport().send(request, consent: approved)
            XCTFail("Expected secure backend failure")
        } catch {
            XCTAssertEqual(error as? LanguageServiceError, .secureBackendRequired)
        }
    }
}
