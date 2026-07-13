import Foundation
import SwiftData

@MainActor
struct AnswerApprovalService {
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
