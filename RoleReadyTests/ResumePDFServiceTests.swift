import PDFKit
import XCTest
@testable import RoleReady

final class ResumePDFServiceTests: XCTestCase {
    @MainActor
    func testExportProducesSelectableTextPDF() throws {
        let document = ResumeDocument(
            contact: ResumeContact(
                name: "Alex Morgan",
                email: "alex@example.com",
                phone: "+61 400 000 000",
                location: "Sydney",
                linkedIn: "linkedin.com/in/alex",
                portfolio: "alex.dev"
            ),
            headline: "Senior Software Engineer",
            sections: [
                ResumeSection(kind: .summary, body: "Engineer focused on reliable mobile products."),
                ResumeSection(
                    kind: .experience,
                    items: [
                        ResumeItem(
                            heading: "Senior Software Engineer",
                            subheading: "Northstar Labs",
                            bullets: [
                                ResumeBullet(text: "Built a Swift release pipeline used by four product teams.", isApproved: true)
                            ]
                        )
                    ]
                )
            ]
        )

        let data = try ResumePDFService().data(for: document)
        let pdf = try XCTUnwrap(PDFDocument(data: data))
        let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")

        XCTAssertTrue(text.contains("Alex Morgan"))
        XCTAssertTrue(text.contains("Senior Software Engineer"))
        XCTAssertTrue(text.contains("Built a Swift release pipeline"))
        XCTAssertGreaterThan(data.count, 1_000)
    }

    @MainActor
    func testExportRequiresCandidateName() {
        XCTAssertThrowsError(try ResumePDFService().data(for: .empty)) {
            XCTAssertEqual($0 as? ResumePDFError, .missingName)
        }
    }
}
