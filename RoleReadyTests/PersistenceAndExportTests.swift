import SwiftData
import XCTest
@testable import RoleReady

@MainActor
final class PersistenceAndExportTests: XCTestCase {
    func testSampleWorkspaceIsCompleteAndIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext

        try SeedService().installSampleWorkspace(in: context)
        try SeedService().installSampleWorkspace(in: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CareerProfile>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Experience>()), 6)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Opportunity>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JobRequirement>()), 6)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GeneratedAnswer>()), 1)
    }

    func testExportExcludesConfidentialStoriesByDefault() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(TestFixtures.experience(title: "Standard story", confidentiality: .standard))
        context.insert(TestFixtures.experience(title: "Confidential story", confidentiality: .confidential))
        try context.save()

        let data = try ExportService().makeExport(in: context, includeConfidential: false)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(RoleReadyExport.self, from: data)

        XCTAssertEqual(export.identifier, RoleReadyExport.formatIdentifier)
        XCTAssertEqual(export.version, RoleReadyExport.formatVersion)
        XCTAssertEqual(export.experiences.map(\.title), ["Standard story"])
        XCTAssertFalse(export.includesConfidential)
    }

    func testRedactedExportOmitsAllInterviewReflections() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let standard = TestFixtures.experience(title: "Standard story", confidentiality: .standard)
        let confidential = TestFixtures.experience(title: "Confidential story", confidentiality: .confidential)
        context.insert(standard)
        context.insert(confidential)
        context.insert(InterviewReflection(
            opportunityID: UUID(),
            questions: ["How did you protect quality?"],
            experienceIDs: [standard.id, confidential.id],
            strongestMoment: "I explained the validation approach clearly.",
            difficultMoment: "",
            feedback: "",
            nextImprovement: "Use a shorter opening."
        ))
        try context.save()

        let data = try ExportService().makeExport(in: context, includeConfidential: false)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(RoleReadyExport.self, from: data)

        XCTAssertTrue(export.reflections.isEmpty)
    }

    func testConfidentialExportIncludesInterviewReflections() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reflection = InterviewReflection(
            opportunityID: UUID(),
            questions: ["How did you protect quality?"],
            experienceIDs: [],
            strongestMoment: "I explained the validation approach clearly.",
            difficultMoment: "",
            feedback: "The panel asked for implementation detail.",
            nextImprovement: "Use a shorter opening."
        )
        context.insert(reflection)
        try context.save()

        let data = try ExportService().makeExport(in: context, includeConfidential: true)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(RoleReadyExport.self, from: data)

        XCTAssertEqual(export.reflections.count, 1)
        XCTAssertEqual(export.reflections.first?.id, reflection.id)
    }

    func testExportIncludesPracticeSessionProvenance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let experience = TestFixtures.experience()
        let opportunity = Opportunity(
            roleTitle: "Data Platform Lead",
            organisation: "Northstar Energy",
            location: "Sydney · Hybrid",
            sourceText: "Lead reliable data platform delivery.",
            status: .preparing
        )
        let answer = GeneratedAnswer(
            question: "Tell me about a platform you made more reliable.",
            experienceID: experience.id,
            opportunityID: opportunity.id,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural,
            content: "A grounded answer.",
            quickCues: ["Baseline", "Validation", "Outcome"],
            sourceFields: ["Situation", "Action", "Result"],
            followUps: []
        )
        let session = PracticeSession(
            answerID: answer.id,
            experienceID: experience.id,
            opportunityID: opportunity.id,
            question: answer.question,
            durationSeconds: 64,
            confidence: 4,
            notes: "Shorten the opening."
        )
        context.insert(experience)
        context.insert(opportunity)
        context.insert(answer)
        context.insert(session)
        try context.save()

        let data = try ExportService().makeExport(in: context, includeConfidential: false)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(RoleReadyExport.self, from: data)

        XCTAssertEqual(export.practiceSessions.count, 1)
        XCTAssertEqual(export.practiceSessions.first?.answerID, answer.id)
        XCTAssertEqual(export.practiceSessions.first?.experienceID, experience.id)
        XCTAssertEqual(export.practiceSessions.first?.opportunityID, opportunity.id)
        XCTAssertEqual(export.practiceSessions.first?.durationSeconds, 64)
    }

    func testReducedSensitivityExportRedactsOpportunitySourceAndNotes() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let opportunity = Opportunity(
            roleTitle: "Data Platform Lead",
            organisation: "Northstar Energy",
            location: "Sydney · Hybrid",
            sourceText: "Full advertisement with recruiter contact details.",
            status: .preparing,
            notes: "Private salary and contact notes."
        )
        let requirement = JobRequirement(
            opportunityID: opportunity.id,
            text: "Lead reliable data platform delivery.",
            kind: .responsibility,
            keywords: ["reliable", "delivery"],
            capabilities: [.delivery]
        )
        context.insert(opportunity)
        context.insert(requirement)
        try context.save()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let reduced = try decoder.decode(
            RoleReadyExport.self,
            from: ExportService().makeExport(in: context, includeConfidential: false)
        )
        let full = try decoder.decode(
            RoleReadyExport.self,
            from: ExportService().makeExport(in: context, includeConfidential: true)
        )

        XCTAssertEqual(reduced.opportunities.first?.sourceText, "")
        XCTAssertEqual(reduced.opportunities.first?.notes, "")
        XCTAssertEqual(reduced.requirements.first?.text, requirement.text)
        XCTAssertEqual(full.opportunities.first?.sourceText, opportunity.sourceText)
        XCTAssertEqual(full.opportunities.first?.notes, opportunity.notes)
    }

    func testRemovingSampleWorkspaceAlsoRemovesDerivedRecords() throws {
        let container = try makeContainer()
        let context = container.mainContext
        try SeedService().installSampleWorkspace(in: context)

        let derivedAnswer = GeneratedAnswer(
            question: "A follow-up sample question",
            experienceID: SeedService.IDs.sasMigration,
            opportunityID: SeedService.IDs.opportunity,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural,
            content: "A source-grounded answer.",
            quickCues: ["Source", "Action", "Result"],
            sourceFields: ["Situation", "Action", "Result"],
            followUps: []
        )
        context.insert(derivedAnswer)
        context.insert(PracticeSession(
            answerID: derivedAnswer.id,
            question: derivedAnswer.question,
            durationSeconds: 45,
            confidence: 4
        ))
        context.insert(InterviewReflection(
            opportunityID: SeedService.IDs.opportunity,
            questions: ["What changed?"],
            experienceIDs: [SeedService.IDs.sasMigration],
            strongestMoment: "The evidence was clear.",
            difficultMoment: "",
            feedback: "",
            nextImprovement: "Lead with the result."
        ))
        try context.save()

        try SeedService().removeSampleWorkspace(from: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Experience>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Opportunity>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GeneratedAnswer>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PracticeSession>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<InterviewReflection>()), 0)
    }

    func testEditingSourceInvalidatesLinkedApprovedAnswers() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let experience = TestFixtures.experience()
        let answer = GeneratedAnswer(
            question: "Tell me about a process you improved.",
            experienceID: experience.id,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural,
            content: "A grounded answer.",
            quickCues: ["Problem", "Action", "42 records"],
            sourceFields: ["Situation", "Action", "Result"],
            sourceClaims: [
                StoredAnswerClaim(
                    sourceField: "Result",
                    text: experience.result,
                    sourceText: experience.result
                )
            ],
            followUps: [],
            isFactConfirmed: true,
            sourceExperienceUpdatedAt: experience.updatedAt
        )
        context.insert(experience)
        context.insert(answer)
        try context.save()
        XCTAssertTrue(answer.isApprovalCurrent(for: experience))

        experience.result = "The updated result was verified against 42 records."
        experience.updatedAt = Date().addingTimeInterval(1)
        let invalidated = try AnswerApprovalService().invalidateAnswers(for: experience.id, in: context)
        try context.save()

        XCTAssertEqual(invalidated, 1)
        XCTAssertFalse(answer.isFactConfirmed)
        XCTAssertFalse(answer.isApprovalCurrent(for: experience))
    }

    func testRoleMetadataEditKeepsApprovalButContentEditInvalidatesIt() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let revision = Date(timeIntervalSince1970: 1_750_000_000)
        let experience = TestFixtures.experience()
        experience.updatedAt = revision
        let opportunity = Opportunity(
            roleTitle: "Senior Data Engineer",
            organisation: "CobaltGrid Energy",
            location: "Sydney · Hybrid",
            sourceText: "Build reliable data products.",
            status: .preparing,
            updatedAt: revision,
            contentUpdatedAt: revision
        )
        let answer = GeneratedAnswer(
            question: "Tell me about reliable delivery.",
            experienceID: experience.id,
            opportunityID: opportunity.id,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural,
            content: "A grounded answer.",
            quickCues: ["Reliability"],
            sourceFields: ["Action", "Result"],
            sourceClaims: [
                StoredAnswerClaim(
                    sourceField: "Action",
                    text: experience.actions[0],
                    sourceText: experience.actions[0]
                )
            ],
            followUps: [],
            isFactConfirmed: true,
            sourceExperienceUpdatedAt: revision,
            sourceOpportunityUpdatedAt: revision
        )
        context.insert(experience)
        context.insert(opportunity)
        context.insert(answer)
        try context.save()

        opportunity.status = .interviewing
        opportunity.interviewDate = revision.addingTimeInterval(86_400)
        opportunity.updatedAt = revision.addingTimeInterval(60)
        XCTAssertTrue(answer.isApprovalCurrent(for: experience, opportunity: opportunity))

        opportunity.roleTitle = "Lead Data Engineer"
        opportunity.contentUpdatedAt = revision.addingTimeInterval(120)
        let invalidated = try AnswerApprovalService()
            .invalidateAnswers(forOpportunityID: opportunity.id, in: context)

        XCTAssertEqual(invalidated, 1)
        XCTAssertFalse(answer.isApprovalCurrent(for: experience, opportunity: opportunity))
    }

    func testDeletingRoleDetachesReusableAnswersAndPracticeHistory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let experience = TestFixtures.experience()
        let opportunity = Opportunity(
            roleTitle: "Senior Data Engineer",
            organisation: "CobaltGrid Energy",
            location: "Sydney · Hybrid",
            sourceText: "Build reliable data products.",
            status: .preparing
        )
        let answer = GeneratedAnswer(
            question: "Tell me about reliable delivery.",
            experienceID: experience.id,
            opportunityID: opportunity.id,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural,
            content: "A grounded answer.",
            quickCues: ["Reliability"],
            sourceFields: ["Action", "Result"],
            followUps: [],
            sourceOpportunityUpdatedAt: opportunity.contentUpdatedAt
        )
        let session = PracticeSession(
            answerID: answer.id,
            experienceID: experience.id,
            opportunityID: opportunity.id,
            question: answer.question,
            durationSeconds: 58,
            confidence: 4
        )
        context.insert(experience)
        context.insert(opportunity)
        context.insert(answer)
        context.insert(session)
        context.insert(JobRequirement(
            opportunityID: opportunity.id,
            text: "Build and maintain data products.",
            kind: .responsibility,
            keywords: ["data products"],
            capabilities: [.delivery]
        ))
        context.insert(InterviewReflection(
            opportunityID: opportunity.id,
            questions: [answer.question],
            experienceIDs: [experience.id],
            strongestMoment: "Clear evidence.",
            difficultMoment: "",
            feedback: "",
            nextImprovement: "Shorten the opening."
        ))
        try context.save()

        try OpportunityDeletionService().delete(opportunity, in: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Opportunity>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JobRequirement>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<InterviewReflection>()), 0)
        XCTAssertNil(answer.opportunityID)
        XCTAssertNil(answer.sourceOpportunityUpdatedAt)
        XCTAssertNil(session.opportunityID)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GeneratedAnswer>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PracticeSession>()), 1)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            CareerProfile.self,
            CareerSource.self,
            CareerSourceSpan.self,
            CareerPosition.self,
            CareerEducation.self,
            CareerCertification.self,
            CareerSkill.self,
            Experience.self,
            Opportunity.self,
            JobRequirement.self,
            ResumeVersion.self,
            CoverLetter.self,
            ApplicationActivity.self,
            CareerReminder.self,
            GeneratedAnswer.self,
            PracticeSession.self,
            InterviewReflection.self
        ])
        return try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }
}
