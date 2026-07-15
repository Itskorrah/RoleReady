import UniformTypeIdentifiers
import UIKit
import XCTest
import zlib
@testable import RoleReady

final class DocumentImportServiceTests: XCTestCase {
    func testSupportedTypesIncludeModernWordDocuments() {
        XCTAssertTrue(DocumentImportService.supportedContentTypes.contains { type in
            type.preferredFilenameExtension?.lowercased() == "docx"
        })
    }

    func testSupportedTypesIncludeEveryAdvertisedFormat() {
        let types = DocumentImportService.supportedContentTypes
        XCTAssertTrue(types.contains(where: { $0.conforms(to: .pdf) }))
        XCTAssertTrue(types.contains(where: { $0.conforms(to: .rtf) }))
        XCTAssertTrue(types.contains(where: { $0.conforms(to: .plainText) }))
        XCTAssertTrue(types.contains(where: { $0.preferredFilenameExtension == "docx" }))
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

    func testPDFImportExtractsSelectableText() throws {
        let url = temporaryURL(extension: "pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writePDF(text: "Senior Engineer\nBuilt a safer deployment pipeline.", to: url)

        let imported = try DocumentImportService().extractText(from: url)

        XCTAssertTrue(imported.text.contains("Senior Engineer"))
        XCTAssertTrue(imported.text.contains("deployment pipeline"))
    }

    func testScannedPDFExplainsOCRRequirement() throws {
        let url = temporaryURL(extension: "pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writePDF(text: nil, to: url)

        XCTAssertThrowsError(try DocumentImportService().extractText(from: url)) { error in
            XCTAssertEqual(error as? DocumentImportError, .scannedPDFNeedsOCR)
            XCTAssertTrue(error.localizedDescription.localizedCaseInsensitiveContains("OCR"))
        }
    }

    func testRTFImportExtractsText() throws {
        let url = temporaryURL(extension: "rtf")
        defer { try? FileManager.default.removeItem(at: url) }
        try writeAttributedDocument(
            "Platform Engineer at Northstar",
            type: .rtf,
            to: url
        )

        let imported = try DocumentImportService().extractText(from: url)

        XCTAssertEqual(imported.text, "Platform Engineer at Northstar")
    }

    func testDOCXImportExtractsTextAndWarnsAboutFormatting() throws {
        let url = temporaryURL(extension: "docx")
        defer { try? FileManager.default.removeItem(at: url) }
        try writeDOCX(text: "Data Analyst at Harbour Labs", to: url)

        let imported = try DocumentImportService().extractText(from: url)

        XCTAssertEqual(imported.text, "Data Analyst at Harbour Labs")
        XCTAssertTrue(imported.warnings.contains(where: { $0.contains("formatting was removed") }))
    }

    func testCompressedDOCXImportExtractsRealWorldZIPPayload() throws {
        let url = temporaryURL(extension: "docx")
        defer { try? FileManager.default.removeItem(at: url) }
        try writeDOCX(
            text: "Platform Engineer\nReduced deployment recovery time",
            compressed: true,
            to: url
        )

        let imported = try DocumentImportService().extractText(from: url)

        XCTAssertTrue(imported.text.contains("Platform Engineer"))
        XCTAssertTrue(imported.text.contains("deployment recovery time"))
    }

    private func temporaryURL(extension pathExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
    }

    private func writePDF(text: String?, to url: URL) throws {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            if let text {
                text.draw(
                    in: page.insetBy(dx: 40, dy: 40),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 16)]
                )
            } else {
                UIColor.darkGray.setFill()
                context.cgContext.fill(page.insetBy(dx: 40, dy: 40))
            }
        }
    }

    private func writeAttributedDocument(
        _ text: String,
        type: NSAttributedString.DocumentType,
        to url: URL
    ) throws {
        let attributed = NSAttributedString(string: text)
        let data = try attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: type]
        )
        try data.write(to: url, options: .atomic)
    }

    private func writeDOCX(
        text: String,
        compressed: Bool = false,
        to url: URL
    ) throws {
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
        """
        let relationships = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
        let document = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body><w:p><w:r><w:t>\(text)</w:t></w:r></w:p><w:sectPr/></w:body>
        </w:document>
        """
        let entries = try [
            StoredZIPEntry(name: "[Content_Types].xml", text: contentTypes),
            StoredZIPEntry(name: "_rels/.rels", text: relationships),
            StoredZIPEntry(name: "word/document.xml", text: document)
        ]
        try makeZIP(entries: entries, compressed: compressed).write(to: url, options: .atomic)
    }

    private func makeZIP(entries: [StoredZIPEntry], compressed: Bool) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()

        for entry in entries {
            let localOffset = UInt32(archive.count)
            let crc = crc32(entry.data)
            let payload = compressed ? try deflateRaw(entry.data) : entry.data
            let compressedSize = UInt32(payload.count)
            let uncompressedSize = UInt32(entry.data.count)
            let compressionMethod = UInt16(compressed ? 8 : 0)
            let nameSize = UInt16(entry.nameData.count)

            archive.appendLittleEndian(UInt32(0x04034B50))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(compressionMethod)
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(crc)
            archive.appendLittleEndian(compressedSize)
            archive.appendLittleEndian(uncompressedSize)
            archive.appendLittleEndian(nameSize)
            archive.appendLittleEndian(UInt16(0))
            archive.append(entry.nameData)
            archive.append(payload)

            centralDirectory.appendLittleEndian(UInt32(0x02014B50))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(compressionMethod)
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(crc)
            centralDirectory.appendLittleEndian(compressedSize)
            centralDirectory.appendLittleEndian(uncompressedSize)
            centralDirectory.appendLittleEndian(nameSize)
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt32(0))
            centralDirectory.appendLittleEndian(localOffset)
            centralDirectory.append(entry.nameData)
        }

        let centralOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendLittleEndian(UInt32(0x06054B50))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt32(centralDirectory.count))
        archive.appendLittleEndian(centralOffset)
        archive.appendLittleEndian(UInt16(0))
        return archive
    }

    private func deflateRaw(_ data: Data) throws -> Data {
        var stream = z_stream()
        let initialized = deflateInit2_(
            &stream,
            Z_DEFAULT_COMPRESSION,
            Z_DEFLATED,
            -MAX_WBITS,
            8,
            Z_DEFAULT_STRATEGY,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initialized == Z_OK else { throw DocumentImportError.unreadable }
        defer { deflateEnd(&stream) }

        var output = Data(count: Int(deflateBound(&stream, uLong(data.count))))
        let result = data.withUnsafeBytes { inputBuffer in
            output.withUnsafeMutableBytes { outputBuffer in
                stream.next_in = UnsafeMutablePointer<Bytef>(
                    mutating: inputBuffer.bindMemory(to: Bytef.self).baseAddress
                )
                stream.avail_in = uInt(inputBuffer.count)
                stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(outputBuffer.count)
                return deflate(&stream, Z_FINISH)
            }
        }
        guard result == Z_STREAM_END else { throw DocumentImportError.unreadable }
        return output.prefix(Int(stream.total_out))
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc = UInt32.max
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc >> 1) ^ (0xEDB88320 & (UInt32(0) &- (crc & 1)))
            }
        }
        return crc ^ UInt32.max
    }
}

private struct StoredZIPEntry {
    let nameData: Data
    let data: Data

    init(name: String, text: String) throws {
        guard let nameData = name.data(using: .utf8),
              let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        self.nameData = nameData
        self.data = data
    }
}

private extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            append(contentsOf: bytes)
        }
    }
}
