import Foundation
import UIKit

enum ResumePDFError: LocalizedError, Equatable, Sendable {
    case missingName
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .missingName: "Add your name before exporting the résumé."
        case .writeFailed: "The résumé PDF could not be created. Try again."
        }
    }
}

@MainActor
struct ResumePDFService {
    private let page = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
    private let margin: CGFloat = 48

    func data(for document: ResumeDocument) throws -> Data {
        guard !document.contact.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ResumePDFError.missingName
        }
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { context in
            var cursor = Cursor(y: margin)
            context.beginPage()
            drawHeader(document, cursor: &cursor, context: context)
            for section in document.sections where section.isVisible && hasContent(section) {
                draw(section, cursor: &cursor, context: context)
            }
        }
    }

    func makeTemporaryPDF(for document: ResumeDocument, name: String) throws -> URL {
        let data = try data(for: document)
        let cleanName = sanitized(name.isEmpty ? document.contact.name + " Resume" : name)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoleReady-\(cleanName)-\(UUID().uuidString.prefix(8))")
            .appendingPathExtension("pdf")
        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            throw ResumePDFError.writeFailed
        }
    }

    private struct Cursor {
        var y: CGFloat
    }

    private func drawHeader(
        _ document: ResumeDocument,
        cursor: inout Cursor,
        context: UIGraphicsPDFRendererContext
    ) {
        drawText(
            document.contact.name,
            font: .systemFont(ofSize: 24, weight: .bold),
            color: .black,
            spacingAfter: 4,
            cursor: &cursor,
            context: context
        )
        if !document.headline.isEmpty {
            drawText(
                document.headline,
                font: .systemFont(ofSize: 11.5, weight: .semibold),
                color: UIColor(white: 0.18, alpha: 1),
                spacingAfter: 6,
                cursor: &cursor,
                context: context
            )
        }
        let contact = [
            document.contact.email,
            document.contact.phone,
            document.contact.location,
            document.contact.linkedIn,
            document.contact.portfolio
        ].filter { !$0.isEmpty }.joined(separator: "  •  ")
        if !contact.isEmpty {
            drawText(
                contact,
                font: .systemFont(ofSize: 8.8),
                color: UIColor(white: 0.28, alpha: 1),
                spacingAfter: 10,
                cursor: &cursor,
                context: context
            )
        }
        let lineY = cursor.y
        context.cgContext.setStrokeColor(UIColor(white: 0.18, alpha: 1).cgColor)
        context.cgContext.setLineWidth(0.8)
        context.cgContext.move(to: CGPoint(x: margin, y: lineY))
        context.cgContext.addLine(to: CGPoint(x: page.width - margin, y: lineY))
        context.cgContext.strokePath()
        cursor.y += 12
    }

    private func draw(
        _ section: ResumeSection,
        cursor: inout Cursor,
        context: UIGraphicsPDFRendererContext
    ) {
        ensureSpace(40, cursor: &cursor, context: context)
        drawText(
            section.title.uppercased(),
            font: .systemFont(ofSize: 10.5, weight: .bold),
            color: UIColor(white: 0.12, alpha: 1),
            spacingAfter: 5,
            cursor: &cursor,
            context: context,
            letterSpacing: 0.7
        )
        if !section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            drawText(
                section.body,
                font: .systemFont(ofSize: 9.7),
                color: UIColor(white: 0.16, alpha: 1),
                spacingAfter: 8,
                cursor: &cursor,
                context: context,
                lineSpacing: 2
            )
        }
        for item in section.items {
            draw(item, cursor: &cursor, context: context)
        }
        cursor.y += 3
    }

    private func draw(
        _ item: ResumeItem,
        cursor: inout Cursor,
        context: UIGraphicsPDFRendererContext
    ) {
        let estimated = 28 + CGFloat(item.bullets.count) * 17
        ensureSpace(min(estimated, 140), cursor: &cursor, context: context)
        let date = dateRange(item)
        let headingWidth = date.isEmpty ? contentWidth : contentWidth - 118
        let headingHeight = measuredHeight(item.heading, font: .systemFont(ofSize: 10.3, weight: .bold), width: headingWidth)
        (item.heading as NSString).draw(
            with: CGRect(x: margin, y: cursor.y, width: headingWidth, height: headingHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 10.3, weight: .bold), .foregroundColor: UIColor.black],
            context: nil
        )
        if !date.isEmpty {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .right
            (date as NSString).draw(
                in: CGRect(x: page.width - margin - 118, y: cursor.y, width: 118, height: 16),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 8.8, weight: .medium),
                    .foregroundColor: UIColor(white: 0.3, alpha: 1),
                    .paragraphStyle: paragraph
                ]
            )
        }
        cursor.y += max(headingHeight, 13) + 1
        let subheading = [item.subheading, item.location].filter { !$0.isEmpty }.joined(separator: " · ")
        if !subheading.isEmpty {
            drawText(
                subheading,
                font: .systemFont(ofSize: 9.2, weight: .medium),
                color: UIColor(white: 0.28, alpha: 1),
                spacingAfter: 3,
                cursor: &cursor,
                context: context
            )
        }
        for bullet in item.bullets where !bullet.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            drawBullet(bullet.text, cursor: &cursor, context: context)
        }
        cursor.y += 6
    }

    private func drawBullet(
        _ text: String,
        cursor: inout Cursor,
        context: UIGraphicsPDFRendererContext
    ) {
        let font = UIFont.systemFont(ofSize: 9.4)
        let width = contentWidth - 13
        let height = measuredHeight(text, font: font, width: width, lineSpacing: 1.8)
        ensureSpace(height + 4, cursor: &cursor, context: context)
        ("•" as NSString).draw(
            at: CGPoint(x: margin + 1, y: cursor.y),
            withAttributes: [.font: font, .foregroundColor: UIColor.black]
        )
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 1.8
        (text as NSString).draw(
            with: CGRect(x: margin + 13, y: cursor.y, width: width, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .foregroundColor: UIColor(white: 0.13, alpha: 1), .paragraphStyle: paragraph],
            context: nil
        )
        cursor.y += height + 3
    }

    private func drawText(
        _ text: String,
        font: UIFont,
        color: UIColor,
        spacingAfter: CGFloat,
        cursor: inout Cursor,
        context: UIGraphicsPDFRendererContext,
        letterSpacing: CGFloat = 0,
        lineSpacing: CGFloat = 0
    ) {
        let height = measuredHeight(text, font: font, width: contentWidth, lineSpacing: lineSpacing)
        ensureSpace(height + spacingAfter, cursor: &cursor, context: context)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        (text as NSString).draw(
            with: CGRect(x: margin, y: cursor.y, width: contentWidth, height: height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .foregroundColor: color, .kern: letterSpacing, .paragraphStyle: paragraph],
            context: nil
        )
        cursor.y += height + spacingAfter
    }

    private func ensureSpace(
        _ required: CGFloat,
        cursor: inout Cursor,
        context: UIGraphicsPDFRendererContext
    ) {
        if cursor.y + required > page.height - margin {
            context.beginPage()
            cursor.y = margin
        }
    }

    private func measuredHeight(_ text: String, font: UIFont, width: CGFloat, lineSpacing: CGFloat = 0) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        return ceil((text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil
        ).height)
    }

    private var contentWidth: CGFloat { page.width - margin * 2 }

    private func hasContent(_ section: ResumeSection) -> Bool {
        !section.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !section.items.isEmpty
    }

    private func dateRange(_ item: ResumeItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let start = item.startDate.map(formatter.string) ?? ""
        let end = item.endDate.map(formatter.string) ?? (item.startDate == nil ? "" : "Present")
        if start.isEmpty { return end }
        return "\(start) – \(end)"
    }

    private func sanitized(_ value: String) -> String {
        let cleaned = value.replacingOccurrences(of: #"[^A-Za-z0-9._-]+"#, with: "-", options: .regularExpression)
        return String(cleaned.prefix(80)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
