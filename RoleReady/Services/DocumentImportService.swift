import Foundation
import PDFKit
import UniformTypeIdentifiers
import UIKit

enum DocumentImportError: LocalizedError, Sendable {
    case inaccessible
    case unsupportedType
    case tooLarge
    case emptyDocument
    case unreadable

    var errorDescription: String? {
        switch self {
        case .inaccessible: "RoleReady could not access that document. Choose it again from Files."
        case .unsupportedType: "Choose a PDF, Word (.docx), RTF, or plain-text document."
        case .tooLarge: "Choose a document smaller than 20 MB."
        case .emptyDocument: "No selectable text was found in that document."
        case .unreadable: "The document could not be read. It may be damaged or password protected."
        }
    }
}

struct ImportedDocument: Hashable, Sendable {
    let name: String
    let text: String
    let warnings: [String]
}

struct DocumentImportService: Sendable {
    static var supportedContentTypes: [UTType] {
        [.pdf, .rtf, .plainText] + [UTType(filenameExtension: "docx")].compactMap { $0 }
    }

    private let maximumBytes = 20 * 1_024 * 1_024
    private let maximumCharacters = 250_000

    func extractText(from url: URL) throws -> ImportedDocument {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey, .nameKey])
        guard let fileSize = values?.fileSize, fileSize <= maximumBytes else { throw DocumentImportError.tooLarge }
        let type = values?.contentType ?? UTType(filenameExtension: url.pathExtension)
        guard let type else { throw DocumentImportError.unsupportedType }

        let text: String
        var warnings: [String] = []
        if type.conforms(to: .pdf) {
            guard let document = PDFDocument(url: url) else { throw DocumentImportError.unreadable }
            guard document.pageCount <= 300 else { throw DocumentImportError.tooLarge }
            var pages: [String] = []
            var emptyPages = 0
            for index in 0..<document.pageCount {
                let pageText = document.page(at: index)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if pageText.isEmpty { emptyPages += 1 } else { pages.append(pageText) }
            }
            text = pages.joined(separator: "\n\n")
            if emptyPages > 0 {
                warnings.append("\(emptyPages) page\(emptyPages == 1 ? "" : "s") had no selectable text and may need to be pasted manually.")
            }
        } else if url.pathExtension.caseInsensitiveCompare("docx") == .orderedSame {
            guard let attributed = try? NSAttributedString(
                url: url,
                options: [:],
                documentAttributes: nil
            ) else { throw DocumentImportError.unreadable }
            text = attributed.string
            warnings.append("Word formatting was removed so the role can be analysed as plain text.")
        } else if type.conforms(to: .rtf) {
            let attributed = try NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            text = attributed.string
        } else if type.conforms(to: .plainText) || type.conforms(to: .utf8PlainText) {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { throw DocumentImportError.unreadable }
            text = content
        } else {
            throw DocumentImportError.unsupportedType
        }

        let trimmed = String(text.prefix(maximumCharacters)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw DocumentImportError.emptyDocument }
        if text.count > maximumCharacters {
            warnings.append("Only the first \(maximumCharacters.formatted()) characters were imported for safety.")
        }
        return ImportedDocument(name: values?.name ?? url.lastPathComponent, text: trimmed, warnings: warnings)
    }
}
