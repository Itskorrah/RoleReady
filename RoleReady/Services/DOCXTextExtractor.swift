import Foundation
import zlib

struct DOCXTextExtractor: Sendable {
    private let maximumDocumentXMLBytes = 8 * 1_024 * 1_024

    func extractText(from data: Data) throws -> String {
        guard let entry = try ZIPDirectory(data: data).entry(named: "word/document.xml") else {
            throw DocumentImportError.unreadable
        }
        guard entry.uncompressedSize <= maximumDocumentXMLBytes else {
            throw DocumentImportError.tooLarge
        }

        let xmlData: Data
        switch entry.compressionMethod {
        case 0:
            xmlData = entry.compressedData
        case 8:
            xmlData = try inflateRaw(
                entry.compressedData,
                expectedSize: entry.uncompressedSize
            )
        default:
            throw DocumentImportError.unreadable
        }

        let parserDelegate = WordDocumentXMLParser()
        let parser = XMLParser(data: xmlData)
        parser.delegate = parserDelegate
        guard parser.parse() else { throw DocumentImportError.unreadable }
        return parserDelegate.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inflateRaw(_ compressed: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0, expectedSize <= maximumDocumentXMLBytes else {
            throw DocumentImportError.unreadable
        }

        var stream = z_stream()
        let initialization = inflateInit2_(
            &stream,
            -MAX_WBITS,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initialization == Z_OK else { throw DocumentImportError.unreadable }
        defer { inflateEnd(&stream) }

        var output = Data(count: expectedSize)
        let result = compressed.withUnsafeBytes { inputBuffer in
            output.withUnsafeMutableBytes { outputBuffer in
                stream.next_in = UnsafeMutablePointer<Bytef>(
                    mutating: inputBuffer.bindMemory(to: Bytef.self).baseAddress
                )
                stream.avail_in = uInt(inputBuffer.count)
                stream.next_out = outputBuffer.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(outputBuffer.count)
                return inflate(&stream, Z_FINISH)
            }
        }
        guard result == Z_STREAM_END, stream.total_out == expectedSize else {
            throw DocumentImportError.unreadable
        }
        return output
    }
}

private struct ZIPEntry {
    let compressionMethod: UInt16
    let uncompressedSize: Int
    let compressedData: Data
}

private struct ZIPDirectory {
    private let data: Data

    init(data: Data) throws {
        guard data.count >= 22 else { throw DocumentImportError.unreadable }
        self.data = data
    }

    func entry(named expectedName: String) throws -> ZIPEntry? {
        guard let endOffset = endOfCentralDirectoryOffset() else {
            throw DocumentImportError.unreadable
        }
        let centralOffset = try data.integer32(at: endOffset + 16)
        var cursor = Int(centralOffset)

        while cursor + 46 <= data.count,
              try data.integer32(at: cursor) == 0x02014B50 {
            let flags = try data.integer16(at: cursor + 8)
            let compressionMethod = try data.integer16(at: cursor + 10)
            let compressedSize = Int(try data.integer32(at: cursor + 20))
            let uncompressedSize = Int(try data.integer32(at: cursor + 24))
            let nameLength = Int(try data.integer16(at: cursor + 28))
            let extraLength = Int(try data.integer16(at: cursor + 30))
            let commentLength = Int(try data.integer16(at: cursor + 32))
            let localOffset = Int(try data.integer32(at: cursor + 42))
            let nameStart = cursor + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= data.count,
                  let name = String(data: data[nameStart..<nameEnd], encoding: .utf8) else {
                throw DocumentImportError.unreadable
            }

            if name == expectedName {
                guard flags & 0x1 == 0 else { throw DocumentImportError.unreadable }
                return try localEntry(
                    at: localOffset,
                    compressionMethod: compressionMethod,
                    compressedSize: compressedSize,
                    uncompressedSize: uncompressedSize
                )
            }
            cursor = nameEnd + extraLength + commentLength
        }
        return nil
    }

    private func localEntry(
        at offset: Int,
        compressionMethod: UInt16,
        compressedSize: Int,
        uncompressedSize: Int
    ) throws -> ZIPEntry {
        guard offset + 30 <= data.count,
              try data.integer32(at: offset) == 0x04034B50 else {
            throw DocumentImportError.unreadable
        }
        let nameLength = Int(try data.integer16(at: offset + 26))
        let extraLength = Int(try data.integer16(at: offset + 28))
        let dataStart = offset + 30 + nameLength + extraLength
        let dataEnd = dataStart + compressedSize
        guard compressedSize >= 0,
              uncompressedSize >= 0,
              dataStart <= dataEnd,
              dataEnd <= data.count else {
            throw DocumentImportError.unreadable
        }
        return ZIPEntry(
            compressionMethod: compressionMethod,
            uncompressedSize: uncompressedSize,
            compressedData: Data(data[dataStart..<dataEnd])
        )
    }

    private func endOfCentralDirectoryOffset() -> Int? {
        let minimumOffset = max(0, data.count - 65_557)
        guard data.count >= 22 else { return nil }
        for offset in stride(from: data.count - 22, through: minimumOffset, by: -1) {
            if (try? data.integer32(at: offset)) == 0x06054B50 {
                return offset
            }
        }
        return nil
    }
}

private final class WordDocumentXMLParser: NSObject, XMLParserDelegate {
    private var pieces: [String] = []
    private var currentText = ""
    private var isReadingText = false

    var text: String {
        pieces.joined()
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch localName(elementName) {
        case "t":
            currentText = ""
            isReadingText = true
        case "tab":
            pieces.append("\t")
        case "br", "cr":
            pieces.append("\n")
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isReadingText { currentText += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch localName(elementName) {
        case "t":
            pieces.append(currentText)
            currentText = ""
            isReadingText = false
        case "p":
            if pieces.last != "\n" { pieces.append("\n") }
        default:
            break
        }
    }

    private func localName(_ name: String) -> Substring {
        name.split(separator: ":").last ?? Substring(name)
    }
}

private extension Data {
    func integer16(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { throw DocumentImportError.unreadable }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func integer32(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= count else { throw DocumentImportError.unreadable }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}
