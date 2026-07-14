import Foundation
import SwiftData

struct AnswerApprovalDecision: Hashable, Sendable {
    let canApprove: Bool
    let issues: [String]
    let wordCount: Int
    let estimatedSpeakingSeconds: Int
}

@MainActor
struct AnswerApprovalService {
    func decision(
        content: String,
        format: AnswerFormat,
        claims: [AnswerClaim],
        experience: Experience,
        allowedContext: String = ""
    ) -> AnswerApprovalDecision {
        let wordCount = content.split(whereSeparator: \.isWhitespace).count
        let reviewWarnings = GroundedAnswerEngine().reviewWarnings(
            output: content,
            against: experience,
            allowedContext: allowedContext
        )
        var issues = reviewWarnings.filter {
            !$0.localizedCaseInsensitiveContains("uses a confidential example")
                && !$0.localizedCaseInsensitiveContains("uses a highly sensitive example")
        }
        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("The answer is empty.")
        }
        if claims.isEmpty {
            issues.append("No source clauses are available for this answer.")
        }
        if !AnswerProvenanceService().claimsCompletelyCover(content: content, claims: claims) {
            issues.append("Every answer clause must have a verified source before approval.")
        }
        let unsupportedCount = claims.filter(\.needsSource).count
        if unsupportedCount > 0 {
            issues.append(
                "\(unsupportedCount) edited clause\(unsupportedCount == 1 ? "" : "s") still need\(unsupportedCount == 1 ? "s" : "") a verified source."
            )
        }
        if !format.targetWordCount.contains(wordCount) {
            issues.append(
                "Keep this format between \(format.targetWordCount.lowerBound) and \(format.targetWordCount.upperBound) words before approval."
            )
        }
        let uniqueIssues = Array(Set(issues)).sorted()
        return AnswerApprovalDecision(
            canApprove: uniqueIssues.isEmpty,
            issues: uniqueIssues,
            wordCount: wordCount,
            estimatedSpeakingSeconds: Int((Double(wordCount) / 130 * 60).rounded())
        )
    }

    func invalidateAnswers(for experienceID: UUID, in context: ModelContext) throws -> Int {
        let linkedAnswers = try context.fetch(FetchDescriptor<GeneratedAnswer>())
            .filter { $0.experienceID == experienceID && $0.isFactConfirmed }
        linkedAnswers.forEach { answer in
            answer.isFactConfirmed = false
            answer.updatedAt = Date()
        }
        return linkedAnswers.count
    }

    func invalidateAnswers(forOpportunityID opportunityID: UUID, in context: ModelContext) throws -> Int {
        let linkedAnswers = try context.fetch(FetchDescriptor<GeneratedAnswer>())
            .filter { $0.opportunityID == opportunityID && $0.isFactConfirmed }
        linkedAnswers.forEach { answer in
            answer.isFactConfirmed = false
            answer.updatedAt = Date()
        }
        return linkedAnswers.count
    }
}
