import XCTest
@testable import RoleReady

final class ApplicationMaterialServiceTests: XCTestCase {
    private let evidence = [
        CareerEvidenceSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            title: "Senior Software Engineer",
            organisation: "Northstar Labs",
            bullets: [
                "Built a Swift release pipeline used by four product teams.",
                "Reduced failed releases by 30% after adding automated validation.",
                "Partnered with product and security teams to agree release controls."
            ],
            skills: ["Swift", "iOS", "CI/CD"],
            capabilities: [Capability.technicalProblemSolving.rawValue, Capability.stakeholderCommunication.rawValue]
        ),
        CareerEvidenceSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            title: "Software Engineer",
            organisation: "Harbour Systems",
            bullets: [
                "Developed iOS workflows for field technicians.",
                "Investigated production defects and documented fixes for the support team."
            ],
            skills: ["Swift", "SQL"],
            capabilities: [Capability.technicalProblemSolving.rawValue, Capability.teamwork.rawValue]
        )
    ]

    private let requirements = [
        JobRequirementSnapshot(
            id: UUID(),
            text: "Build reliable iOS applications using Swift",
            keywords: ["iOS", "Swift", "reliability"],
            capabilities: [Capability.technicalProblemSolving.rawValue],
            importance: 3
        ),
        JobRequirementSnapshot(
            id: UUID(),
            text: "Lead Kubernetes platform migrations",
            keywords: ["Kubernetes", "platform migration"],
            capabilities: [Capability.leadership.rawValue],
            importance: 3
        )
    ]

    func testTailoringPrioritisesApprovedEvidenceAndLeavesGapsVisible() {
        let secondID = evidence[1].id
        let firstID = evidence[0].id
        let baseline = ResumeDocument(
            contact: .empty,
            headline: "Software Engineer",
            sections: [
                ResumeSection(
                    kind: .experience,
                    items: [
                        ResumeItem(sourceEntityIDs: [secondID], heading: "Software Engineer"),
                        ResumeItem(sourceEntityIDs: [firstID], heading: "Senior Software Engineer")
                    ]
                )
            ]
        )

        let result = TruthfulTailoringService().tailor(TailoringRequest(
            jobTitle: "Senior iOS Engineer",
            organisation: "Example Co",
            requirements: requirements,
            evidence: evidence,
            baseline: baseline
        ))

        let items = result.document.sections[0].items
        XCTAssertEqual(items.first?.sourceEntityIDs, [firstID])
        XCTAssertEqual(result.report.matches[0].classification, .direct)
        XCTAssertTrue(result.report.matches.contains { $0.classification == .noEvidence })
        XCTAssertTrue(result.report.matches.filter { $0.classification == .noEvidence }.allSatisfy {
            $0.sourceEntityIDs.isEmpty && $0.followUpQuestion != nil
        })
    }

    func testCoverLetterUsesOnlyApprovedEvidenceAndCarriesParagraphGrounding() {
        let result = GroundedCoverLetterService().generate(CoverLetterDraftRequest(
            candidateName: "Alex Morgan",
            roleTitle: "Senior iOS Engineer",
            organisation: "Example Co",
            motivation: "I value products that make complex field work simpler for people.",
            tone: "Direct",
            targetWords: 300,
            requirements: requirements,
            evidence: evidence
        ))

        XCTAssertTrue(result.body.contains("Northstar Labs"))
        XCTAssertTrue(result.body.localizedCaseInsensitiveContains("reduced failed releases by 30%"))
        XCTAssertFalse(result.body.localizedCaseInsensitiveContains("managed Kubernetes"))
        XCTAssertFalse(result.sourceEntityIDs.isEmpty)
        XCTAssertTrue(result.grounding.paragraphs.filter { $0.claimType == "career evidence" }.allSatisfy {
            !$0.sourceEntityIDs.isEmpty
        })
        XCTAssertTrue(result.grounding.paragraphs.allSatisfy { !$0.isApproved })
    }

    func testCoverLetterPresentsSkillEvidenceAsASkillRatherThanAJob() {
        let skill = CareerEvidenceSnapshot(
            id: UUID(),
            title: "SQL",
            organisation: "Approved skill",
            bullets: ["Skills: Python, SQL, data modelling."],
            skills: ["SQL"],
            capabilities: [Capability.technicalProblemSolving.rawValue]
        )
        let result = GroundedCoverLetterService().generate(CoverLetterDraftRequest(
            candidateName: "Alex Morgan",
            roleTitle: "Data Engineer",
            organisation: "Example Co",
            motivation: "",
            tone: "Direct",
            targetWords: 250,
            requirements: [JobRequirementSnapshot(
                id: UUID(),
                text: "Build reliable SQL data pipelines",
                keywords: ["SQL", "data pipelines"],
                capabilities: [Capability.technicalProblemSolving.rawValue],
                importance: 3
            )],
            evidence: [skill]
        ))

        XCTAssertTrue(result.body.contains("includes SQL among my technical skills"))
        XCTAssertTrue(result.body.contains("is relevant to your requirement to build reliable SQL data pipelines"))
        XCTAssertFalse(result.body.contains("SQL at Approved skill"))
    }

    func testCoverLetterOmitsEvidenceWithNoVerifiedConnectionToTheJob() {
        let unrelated = CareerEvidenceSnapshot(
            id: UUID(),
            title: "Marketing Coordinator",
            organisation: "Example Agency",
            bullets: ["Prepared a print campaign using Photoshop."],
            skills: ["Photoshop"],
            capabilities: []
        )
        let result = GroundedCoverLetterService().generate(CoverLetterDraftRequest(
            candidateName: "Alex Morgan",
            roleTitle: "Platform Engineer",
            organisation: "Example Co",
            motivation: "",
            tone: "Direct",
            targetWords: 250,
            requirements: [JobRequirementSnapshot(
                id: UUID(),
                text: "Lead Kubernetes platform migrations",
                keywords: ["Kubernetes", "platform migration"],
                capabilities: [Capability.leadership.rawValue],
                importance: 3
            )],
            evidence: [unrelated]
        ))

        XCTAssertFalse(result.body.contains("Marketing Coordinator"))
        XCTAssertFalse(result.body.contains("Photoshop"))
        XCTAssertTrue(result.sourceEntityIDs.isEmpty)
        XCTAssertTrue(result.grounding.validationWarnings.contains { $0.contains("not enough approved evidence") })
    }

    func testCoverLetterPrefersRoleEvidenceOverStandaloneSkillParagraphs() {
        let role = CareerEvidenceSnapshot(
            id: UUID(),
            title: "Data Analyst",
            organisation: "Harbour Analytics",
            bullets: ["Built reliable Python data pipelines for reporting workflows."],
            skills: ["Python", "SQL"],
            capabilities: [Capability.technicalProblemSolving.rawValue]
        )
        let skill = CareerEvidenceSnapshot(
            id: UUID(),
            title: "SQL",
            organisation: "Approved skill",
            bullets: ["Skills: Python, SQL."],
            skills: ["SQL"],
            capabilities: [Capability.technicalProblemSolving.rawValue]
        )
        let result = GroundedCoverLetterService().generate(CoverLetterDraftRequest(
            candidateName: "Alex Morgan",
            roleTitle: "Data Engineer",
            organisation: "Example Co",
            motivation: "",
            tone: "Direct",
            targetWords: 250,
            requirements: [JobRequirementSnapshot(
                id: UUID(),
                text: "Build reliable Python data pipelines",
                keywords: ["Python", "data pipelines"],
                capabilities: [Capability.technicalProblemSolving.rawValue],
                importance: 3
            )],
            evidence: [skill, role]
        ))

        XCTAssertTrue(result.body.contains("Data Analyst at Harbour Analytics"))
        XCTAssertFalse(result.body.contains("includes SQL among my technical skills"))
        XCTAssertEqual(result.sourceEntityIDs, [role.id])
    }

    func testClaimValidatorCatchesUnsupportedMetricsToolsAndOwnership() {
        let warnings = ClaimValidationService().validate(
            generatedText: "Led an AWS migration that reduced cost by 45%.",
            approvedSources: ["Contributed to a release process that reduced failures by 30%."]
        )

        XCTAssertTrue(warnings.contains { $0.contains("45%") })
        XCTAssertTrue(warnings.contains { $0.localizedCaseInsensitiveContains("led") })
        XCTAssertTrue(warnings.contains { $0.contains("AWS") })
    }

    func testApprovedNumbersAndOwnershipPassValidation() {
        let warnings = ClaimValidationService().validate(
            generatedText: "Led validation work that reduced failures by 30% using Swift.",
            approvedSources: ["Led validation work that reduced failures by 30% using Swift."]
        )
        XCTAssertTrue(warnings.isEmpty)
    }

    func testSelectedCoverLetterSectionRegenerationKeepsOtherSectionsAndGrounding() throws {
        let request = CoverLetterDraftRequest(
            candidateName: "Alex Morgan",
            roleTitle: "Senior iOS Engineer",
            organisation: "Example Co",
            motivation: "",
            tone: "Direct",
            targetWords: 300,
            requirements: requirements,
            evidence: evidence
        )
        var original = GroundedCoverLetterService().generate(request).grounding
        let selectedIndex = try XCTUnwrap(original.paragraphs.firstIndex { $0.claimType == "career evidence" })
        let selectedID = original.paragraphs[selectedIndex].id
        let unchanged = original.paragraphs.enumerated()
            .filter { $0.offset != selectedIndex }
            .map(\.element)
        original.paragraphs[selectedIndex].text = "A user-edited paragraph to replace."
        original.paragraphs[selectedIndex].isApproved = true
        original.paragraphs[selectedIndex].isUserEdited = true

        let updated = try XCTUnwrap(CoverLetterSectionRegenerator().regenerate(
            paragraphID: selectedID,
            in: original,
            request: request
        ))

        let regenerated = try XCTUnwrap(updated.paragraphs.first { $0.id == selectedID })
        XCTAssertNotEqual(regenerated.text, "A user-edited paragraph to replace.")
        XCTAssertFalse(regenerated.sourceEntityIDs.isEmpty)
        XCTAssertFalse(regenerated.isApproved)
        XCTAssertFalse(regenerated.isUserEdited)
        XCTAssertEqual(
            updated.paragraphs.filter { $0.id != selectedID },
            unchanged
        )
    }

    func testCoverLetterTextExportCreatesReadableShareFile() throws {
        let url = try CoverLetterExportService().makeTemporaryTextFile(
            title: "Senior iOS Engineer / Example Co",
            body: "A concise, grounded application letter."
        )
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.pathExtension, "txt")
        XCTAssertFalse(url.lastPathComponent.contains("/"))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "A concise, grounded application letter.")
    }
}
