import SwiftData
import XCTest
@testable import RoleReady

final class ResumeIntakeServiceTests: XCTestCase {
    private let source = """
    Alex Morgan
    Senior Software Engineer
    Sydney, NSW | alex@example.com | +61 400 000 000
    https://linkedin.com/in/alexmorgan

    PROFESSIONAL SUMMARY
    Software engineer focused on reliable mobile products and developer tooling.

    TECHNICAL SKILLS
    Languages: Swift, Python, SQL
    Platforms: iOS, AWS

    PROFESSIONAL EXPERIENCE
    Senior Software Engineer | Northstar Labs
    2022 – Present
    • Built a Swift release pipeline used by four product teams.
    • Reduced failed releases by 30% after adding automated validation.

    Software Engineer | Harbour Systems
    2019 – 2022
    • Developed iOS workflows for field technicians.

    EDUCATION
    Bachelor of Computer Science
    University of Sydney | 2016 – 2019

    CERTIFICATIONS
    AWS Certified Developer | Amazon Web Services | 2023
    """

    func testExtractsStructuredResumeWithoutApprovingClaims() throws {
        let draft = try ResumeIntakeService().extract(from: source, sourceName: "Alex Resume")

        XCTAssertEqual(draft.contact.name, "Alex Morgan")
        XCTAssertEqual(draft.contact.email, "alex@example.com")
        XCTAssertEqual(draft.headline, "Senior Software Engineer")
        XCTAssertEqual(draft.positions.count, 2)
        XCTAssertEqual(draft.positions.first?.organisation, "Northstar Labs")
        XCTAssertEqual(draft.positions.first?.bullets.count, 2)
        XCTAssertTrue(draft.positions.first?.isCurrent == true)
        XCTAssertEqual(Set(draft.skills.map(\.name)), Set(["Swift", "Python", "SQL", "iOS", "AWS"]))
        XCTAssertEqual(draft.education.count, 1)
        XCTAssertEqual(draft.certifications.count, 1)
        XCTAssertTrue(draft.warnings.joined().localizedCaseInsensitiveContains("draft"))
    }

    func testRejectsEmptyShortAndOversizedInput() {
        XCTAssertThrowsError(try ResumeIntakeService().extract(from: "")) {
            XCTAssertEqual($0 as? ResumeIntakeError, .empty)
        }
        XCTAssertThrowsError(try ResumeIntakeService().extract(from: "too short")) {
            XCTAssertEqual($0 as? ResumeIntakeError, .tooShort)
        }
        XCTAssertThrowsError(try ResumeIntakeService().extract(from: String(repeating: "a", count: 250_001))) {
            XCTAssertEqual($0 as? ResumeIntakeError, .tooLarge)
        }
    }

    func testEditedDateTextCanBeReparsedBeforeImport() throws {
        let range = ResumeIntakeService().parseDateRange("2018 – Present")
        let startYear = try XCTUnwrap(range.start).formatted(.dateTime.year())

        XCTAssertEqual(startYear, "2018")
        XCTAssertNil(range.end)
        XCTAssertTrue(range.isCurrent)

        let finished = ResumeIntakeService().parseDateRange("2018 – 2021")
        XCTAssertEqual(try XCTUnwrap(finished.end).formatted(.dateTime.year()), "2021")
        XCTAssertFalse(finished.isCurrent)
    }

    @MainActor
    func testApprovedImportCreatesGroundedBaselineResume() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let draft = try ResumeIntakeService().extract(from: source, sourceName: "Alex Resume")

        let result = try CareerWorkspaceService().saveResumeImport(
            draft,
            filename: "alex-resume.pdf",
            approveIncludedItems: true,
            createBaselineResume: true,
            in: context
        )

        XCTAssertEqual(result.positionIDs.count, 2)
        XCTAssertNotNil(result.resumeVersionID)
        let positions = try context.fetch(FetchDescriptor<CareerPosition>())
        XCTAssertTrue(positions.allSatisfy { $0.verificationStatus == .approved })
        let versions = try context.fetch(FetchDescriptor<ResumeVersion>())
        let bullets = versions.first?.document.sections
            .first(where: { $0.kind == .experience })?.items.flatMap(\.bullets) ?? []
        XCTAssertFalse(bullets.isEmpty)
        XCTAssertTrue(bullets.allSatisfy { $0.isApproved && !$0.sourceEntityIDs.isEmpty })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CareerSource>()), 1)
        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<CareerSourceSpan>()), 0)
    }

    @MainActor
    func testDraftImportCannotCreateGeneratedResume() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let draft = try ResumeIntakeService().extract(from: source)

        let result = try CareerWorkspaceService().saveResumeImport(
            draft,
            filename: "resume.txt",
            approveIncludedItems: false,
            createBaselineResume: true,
            in: context
        )

        XCTAssertNil(result.resumeVersionID)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CareerPosition>()).allSatisfy {
            $0.verificationStatus == .imported
        })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ResumeVersion>()), 0)
    }

    @MainActor
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
