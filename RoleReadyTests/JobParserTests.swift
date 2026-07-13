import XCTest
@testable import RoleReady

final class JobParserTests: XCTestCase {
    func testExtractsStructuredRequirements() throws {
        let source = """
        Senior Data Engineer
        CobaltGrid

        Essential requirements
        • Demonstrated experience building reliable Python data pipelines.
        • You must use automated testing and data-quality controls.

        Responsibilities
        • Communicate technical decisions with business stakeholders.
        • Mentor analysts through practical feedback and pairing.
        """

        let result = try JobParser().parse(source)

        XCTAssertEqual(result.suggestedTitle, "Senior Data Engineer")
        XCTAssertGreaterThanOrEqual(result.requirements.count, 4)
        XCTAssertTrue(result.requirements.contains { $0.kind == .mustHave })
        XCTAssertTrue(result.requirements.flatMap(\.capabilities).contains(.stakeholderCommunication))
        XCTAssertTrue(result.requirements.flatMap(\.keywords).contains("python"))
    }

    func testRejectsEmptyAndOversizedInput() {
        XCTAssertThrowsError(try JobParser().parse("   ")) { error in
            XCTAssertEqual(error as? JobParserError, .empty)
        }
        XCTAssertThrowsError(try JobParser().parse(String(repeating: "a", count: 250_001))) { error in
            XCTAssertEqual(error as? JobParserError, .tooLarge)
        }
    }

    func testDeduplicatesRepeatedBullets() throws {
        let source = """
        Data Engineer
        Essential requirements
        • Experience in Python data pipeline development and automated testing.
        • Experience in Python data pipeline development and automated testing.
        • Communicate clearly with technical and business stakeholders.
        """
        let result = try JobParser().parse(source)
        let python = result.requirements.filter { $0.text.localizedCaseInsensitiveContains("Python data pipeline") }
        XCTAssertEqual(python.count, 1)
    }
}

