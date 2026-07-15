import SwiftData
import XCTest
@testable import RoleReady

@MainActor
final class CareerWorkspaceModelTests: XCTestCase {
    func testImportedCareerRecordsRemainUnapprovedUntilReviewed() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let source = CareerSource(
            kind: .resume,
            name: "Existing résumé",
            filename: "resume.docx",
            contentType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            rawText: "Platform Engineer at Northstar"
        )
        let position = CareerPosition(
            sourceID: source.id,
            title: "Platform Engineer",
            organisation: "Northstar",
            bullets: ["Improved deployment reliability"],
            sourceExcerpt: source.rawText
        )
        let span = CareerSourceSpan(
            sourceID: source.id,
            entityID: position.id,
            entityType: "careerPosition",
            fieldPath: "title",
            startOffset: -4,
            endOffset: 17,
            excerpt: "Platform Engineer",
            confidence: 1.4
        )

        context.insert(source)
        context.insert(position)
        context.insert(span)
        try context.save()

        XCTAssertEqual(position.verificationStatus, .imported)
        XCTAssertFalse(position.verificationStatus.permitsGeneration)
        XCTAssertNil(position.approvedAt)
        XCTAssertEqual(span.startOffset, 0)
        XCTAssertEqual(span.confidence, 1)
        XCTAssertFalse(span.isApproved)
    }

    func testResumeVersionRoundTripsStructuredContentAndProvenance() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let sourceEntityID = UUID()
        let bullet = ResumeBullet(
            text: "Reduced recovery time by improving deployment diagnostics.",
            sourceEntityIDs: [sourceEntityID],
            evidence: .direct,
            isApproved: true
        )
        let item = ResumeItem(
            sourceEntityIDs: [sourceEntityID],
            heading: "Platform Engineer",
            subheading: "Northstar",
            bullets: [bullet]
        )
        let document = ResumeDocument(
            contact: ResumeContact(
                name: "Avery Singh",
                email: "avery@example.com",
                phone: "0400 000 000",
                location: "Sydney, NSW",
                linkedIn: "linkedin.com/in/avery",
                portfolio: "avery.dev"
            ),
            headline: "Platform engineer focused on reliable delivery",
            sections: [ResumeSection(kind: .experience, items: [item])]
        )
        let resume = ResumeVersion(
            name: "Platform baseline",
            document: document,
            isBaseline: true
        )

        context.insert(resume)
        try context.save()

        let restored = try XCTUnwrap(context.fetch(FetchDescriptor<ResumeVersion>()).first)
        XCTAssertEqual(restored.document, document)
        XCTAssertEqual(restored.document.sections.first?.items.first?.bullets.first?.sourceEntityIDs, [sourceEntityID])
        XCTAssertEqual(restored.document.sections.first?.items.first?.bullets.first?.evidence, .direct)
        XCTAssertTrue(restored.document.sections.first?.items.first?.bullets.first?.isApproved == true)
    }

    func testApplicationRecordsPersistAroundOneOpportunity() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let opportunity = Opportunity(
            roleTitle: "Senior Platform Engineer",
            organisation: "Northstar",
            location: "Sydney",
            jobURL: "https://example.com/jobs/42",
            sourceName: "Company careers",
            sourceText: "Build reliable delivery systems.",
            status: .applied,
            appliedAt: Date(),
            followUpAt: Date().addingTimeInterval(7 * 86_400),
            salaryRange: "$150k–$170k",
            workArrangement: "Hybrid",
            nextAction: "Follow up with recruiter"
        )
        let resume = ResumeVersion(
            opportunityID: opportunity.id,
            name: "Northstar tailored résumé",
            targetRole: opportunity.roleTitle,
            targetOrganisation: opportunity.organisation
        )
        let letter = CoverLetter(
            opportunityID: opportunity.id,
            resumeVersionID: resume.id,
            title: "Northstar cover letter",
            body: "A grounded draft."
        )
        let activity = ApplicationActivity(
            opportunityID: opportunity.id,
            kind: .applied,
            title: "Application submitted"
        )
        let reminder = CareerReminder(
            opportunityID: opportunity.id,
            activityID: activity.id,
            kind: .followUp,
            title: "Check application progress",
            dueAt: Date().addingTimeInterval(7 * 86_400)
        )

        context.insert(opportunity)
        context.insert(resume)
        context.insert(letter)
        context.insert(activity)
        context.insert(reminder)
        try context.save()

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ResumeVersion>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CoverLetter>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ApplicationActivity>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CareerReminder>()), 1)
        XCTAssertEqual(opportunity.status, .applied)
        XCTAssertEqual(opportunity.nextAction, "Follow up with recruiter")
    }

    func testDeletingOpportunityRemovesDependentApplicationDataAndKeepsResume() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let opportunity = Opportunity(
            roleTitle: "iOS Engineer",
            organisation: "Harbour Labs",
            location: "Remote",
            sourceText: "Build accessible SwiftUI products.",
            status: .assessment
        )
        let resume = ResumeVersion(
            opportunityID: opportunity.id,
            name: "Harbour Labs résumé",
            targetRole: opportunity.roleTitle
        )
        context.insert(opportunity)
        context.insert(resume)
        context.insert(CoverLetter(
            opportunityID: opportunity.id,
            title: "Letter",
            body: "Draft"
        ))
        context.insert(ApplicationActivity(
            opportunityID: opportunity.id,
            kind: .assessment,
            title: "Assessment received"
        ))
        context.insert(CareerReminder(
            opportunityID: opportunity.id,
            kind: .assessment,
            title: "Complete assessment",
            dueAt: Date()
        ))
        try context.save()

        try OpportunityDeletionService().delete(opportunity, in: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Opportunity>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CoverLetter>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ApplicationActivity>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CareerReminder>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ResumeVersion>()), 1)
        XCTAssertNil(resume.opportunityID)
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
