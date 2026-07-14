import Foundation
import SwiftData

@MainActor
struct OpportunityDeletionService {
    func delete(_ opportunity: Opportunity, in context: ModelContext) throws {
        let opportunityID = opportunity.id

        try context.fetch(FetchDescriptor<JobRequirement>())
            .filter { $0.opportunityID == opportunityID }
            .forEach(context.delete)

        try context.fetch(FetchDescriptor<InterviewReflection>())
            .filter { $0.opportunityID == opportunityID }
            .forEach(context.delete)

        try context.fetch(FetchDescriptor<CoverLetter>())
            .filter { $0.opportunityID == opportunityID }
            .forEach(context.delete)

        try context.fetch(FetchDescriptor<ApplicationActivity>())
            .filter { $0.opportunityID == opportunityID }
            .forEach(context.delete)

        try context.fetch(FetchDescriptor<CareerReminder>())
            .filter { $0.opportunityID == opportunityID }
            .forEach(context.delete)

        try context.fetch(FetchDescriptor<ResumeVersion>())
            .filter { $0.opportunityID == opportunityID }
            .forEach { resume in
                resume.opportunityID = nil
                resume.updatedAt = Date()
            }

        let detachedAnswers = try context.fetch(FetchDescriptor<GeneratedAnswer>())
            .filter { $0.opportunityID == opportunityID }
        let detachedAnswerIDs = Set(detachedAnswers.map(\.id))

        try context.fetch(FetchDescriptor<PracticeSession>())
            .filter {
                $0.opportunityID == opportunityID || detachedAnswerIDs.contains($0.answerID)
            }
            .forEach { session in
                session.opportunityID = nil
            }

        detachedAnswers.forEach { answer in
            answer.opportunityID = nil
            answer.sourceOpportunityUpdatedAt = nil
            answer.updatedAt = Date()
        }

        context.delete(opportunity)
        try context.save()
    }
}
