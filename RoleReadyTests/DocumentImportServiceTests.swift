import UniformTypeIdentifiers
import XCTest
@testable import RoleReady

final class DocumentImportServiceTests: XCTestCase {
    func testSupportedTypesIncludeModernWordDocuments() {
        XCTAssertTrue(DocumentImportService.supportedContentTypes.contains { type in
            type.preferredFilenameExtension?.lowercased() == "docx"
        })
    }

    func testPlainTextImportPreservesEditableJobContent() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let source = """
        Senior Data Engineer
        Northstar Energy
        Build reliable data products and communicate delivery risks clearly.
        """
        try source.write(to: url, atomically: true, encoding: .utf8)

        let imported = try DocumentImportService().extractText(from: url)

        XCTAssertEqual(imported.text, source)
        XCTAssertEqual(imported.name, url.lastPathComponent)
        XCTAssertTrue(imported.warnings.isEmpty)
    }
}
