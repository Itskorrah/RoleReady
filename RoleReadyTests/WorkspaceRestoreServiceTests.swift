import SwiftData
import XCTest
@testable import RoleReady

@MainActor
final class WorkspaceRestoreServiceTests: XCTestCase {
    func testVersionTwoExportRoundTripsAllRecordTypesAndApproval() throws {
        let source = try makeContainer()
        let expected = try insertCompleteWorkspace(into: source.mainContext)
        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)

        let destination = try makeContainer()
        let preview = try WorkspaceRestoreService().preview(data, in: destination.mainContext)

        XCTAssertEqual(preview.sourceVersion, 2)
        XCTAssertTrue(preview.includesConfidential)
        XCTAssertEqual(preview.importable.profiles, 1)
        XCTAssertEqual(preview.importable.experiences, 1)
        XCTAssertEqual(preview.importable.opportunities, 1)
        XCTAssertEqual(preview.importable.requirements, 1)
        XCTAssertEqual(preview.importable.answers, 1)
        XCTAssertEqual(preview.importable.practiceSessions, 1)
        XCTAssertEqual(preview.importable.reflections, 1)
        XCTAssertEqual(preview.duplicates.total, 0)
        XCTAssertEqual(preview.rejected.total, 0)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<Experience>()), 0, "Preview must not mutate the destination")

        let result = try WorkspaceRestoreService().restore(data, in: destination.mainContext)

        XCTAssertEqual(result.restored.total, 7)
        XCTAssertEqual(result.skippedDuplicates, 0)
        XCTAssertEqual(result.rejectedRecords, 0)

        let experience = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<Experience>()).first)
        let opportunity = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<Opportunity>()).first)
        let answer = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<GeneratedAnswer>()).first)
        let session = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<PracticeSession>()).first)
        let reflection = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<InterviewReflection>()).first)

        XCTAssertEqual(experience.id, expected.experienceID)
        XCTAssertEqual(experience.actions, ["Mapped the failure path", "Added automated validation"])
        XCTAssertTrue(experience.isApprovedForMatching)
        XCTAssertEqual(opportunity.id, expected.opportunityID)
        XCTAssertEqual(answer.id, expected.answerID)
        XCTAssertTrue(answer.isFactConfirmed)
        XCTAssertTrue(answer.isApprovalCurrent(for: experience, opportunity: opportunity))
        XCTAssertEqual(answer.sourceClaims.first?.origin, .generated)
        XCTAssertEqual(session.experienceID, experience.id)
        XCTAssertEqual(session.opportunityID, opportunity.id)
        XCTAssertEqual(reflection.experienceIDs, [experience.id])
    }

    func testEngineQuickPromptAndSelectionCriteriaApprovalsSurviveRoundTrip() throws {
        let source = try makeContainer()
        let experience = TestFixtures.experience()
        source.mainContext.insert(experience)
        for format in [AnswerFormat.quickPrompt, .selectionCriteria] {
            let draft = try GroundedAnswerEngine().generate(
                question: format == .quickPrompt
                    ? "Give me concise memory cues."
                    : "Demonstrated experience improving data quality.",
                from: experience,
                format: format,
                audience: .executivePanel,
                tone: .confident
            )
            source.mainContext.insert(GeneratedAnswer(
                question: format == .quickPrompt
                    ? "Give me concise memory cues."
                    : "Demonstrated experience improving data quality.",
                experienceID: experience.id,
                format: format,
                audience: .executivePanel,
                tone: .confident,
                content: draft.content,
                quickCues: draft.quickCues,
                sourceFields: draft.claims.map(\.sourceField),
                sourceClaims: AnswerProvenanceService().storedClaims(from: draft.claims),
                followUps: draft.followUps,
                isFactConfirmed: true,
                sourceExperienceUpdatedAt: experience.updatedAt
            ))
        }
        try source.mainContext.save()

        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)
        let destination = try makeContainer()
        _ = try WorkspaceRestoreService().restore(data, in: destination.mainContext)

        let restoredExperience = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<Experience>()).first)
        let restoredAnswers = try destination.mainContext.fetch(FetchDescriptor<GeneratedAnswer>())
        XCTAssertEqual(restoredAnswers.count, 2)
        for answer in restoredAnswers {
            XCTAssertTrue(
                answer.isApprovalCurrent(for: restoredExperience),
                "Expected \(answer.format.title) to remain approved; claims: \(answer.sourceClaims)"
            )
        }
    }

    func testVersionOneExportRestoresAnswersAsUnapprovedLegacyDrafts() throws {
        let source = try makeContainer()
        _ = try insertCompleteWorkspace(into: source.mainContext)
        let versionTwo = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)
        var object = try jsonObject(from: versionTwo)
        object["version"] = 1
        stripVersionTwoFields(from: &object)
        let versionOne = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        let destination = try makeContainer()
        let preview = try WorkspaceRestoreService().preview(versionOne, in: destination.mainContext)
        XCTAssertEqual(preview.sourceVersion, 1)
        XCTAssertTrue(preview.warnings.contains { $0.contains("return as drafts") })

        _ = try WorkspaceRestoreService().restore(versionOne, in: destination.mainContext)

        let answer = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<GeneratedAnswer>()).first)
        XCTAssertFalse(answer.isFactConfirmed)
        XCTAssertEqual(answer.sourceClaims.first?.origin, .editedUnsupported)
        XCTAssertFalse(answer.hasTrustworthyProvenance, "Legacy v1 claims have no independently validated source text and must return as drafts")
    }

    func testVersionTwoUnsupportedClaimCannotRestoreAsApproved() throws {
        let source = try makeContainer()
        _ = try insertCompleteWorkspace(into: source.mainContext)
        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)
        var object = try jsonObject(from: data)
        var answers = try XCTUnwrap(object["answers"] as? [[String: Any]])
        var claims = try XCTUnwrap(answers[0]["sourceClaims"] as? [[String: Any]])
        claims[0]["origin"] = AnswerClaimOrigin.editedUnsupported.rawValue
        claims[0]["isSupported"] = false
        answers[0]["sourceClaims"] = claims
        answers[0]["isFactConfirmed"] = true
        object["answers"] = answers
        let edited = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        let destination = try makeContainer()
        _ = try WorkspaceRestoreService().restore(edited, in: destination.mainContext)

        let answer = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<GeneratedAnswer>()).first)
        XCTAssertFalse(answer.isFactConfirmed)
        XCTAssertFalse(answer.hasTrustworthyProvenance)
    }

    func testVersionTwoTamperedContentAndFabricatedClaimCannotRestoreAsApproved() throws {
        let source = try makeContainer()
        _ = try insertCompleteWorkspace(into: source.mainContext)
        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)

        var extraClauseObject = try jsonObject(from: data)
        var extraClauseAnswers = try XCTUnwrap(extraClauseObject["answers"] as? [[String: Any]])
        extraClauseAnswers[0]["content"] = "\(try XCTUnwrap(extraClauseAnswers[0]["content"] as? String)) I improved performance by 99 percent."
        extraClauseAnswers[0]["isFactConfirmed"] = true
        extraClauseObject["answers"] = extraClauseAnswers
        let extraClauseData = try JSONSerialization.data(withJSONObject: extraClauseObject, options: [.sortedKeys])
        let extraClauseDestination = try makeContainer()
        _ = try WorkspaceRestoreService().restore(extraClauseData, in: extraClauseDestination.mainContext)
        XCTAssertFalse(try XCTUnwrap(extraClauseDestination.mainContext.fetch(FetchDescriptor<GeneratedAnswer>()).first).isFactConfirmed)

        var fabricatedClaimObject = try jsonObject(from: data)
        var fabricatedAnswers = try XCTUnwrap(fabricatedClaimObject["answers"] as? [[String: Any]])
        var fabricatedClaims = try XCTUnwrap(fabricatedAnswers[0]["sourceClaims"] as? [[String: Any]])
        let fabricatedSentence = "A public service was failing during peak demand, affecting 99 percent of users."
        fabricatedClaims[0]["text"] = fabricatedSentence
        fabricatedClaims[0]["isSupported"] = true
        fabricatedAnswers[0]["sourceClaims"] = fabricatedClaims
        fabricatedAnswers[0]["content"] = "\(fabricatedSentence) The service met its published response standard."
        fabricatedAnswers[0]["isFactConfirmed"] = true
        fabricatedClaimObject["answers"] = fabricatedAnswers
        let fabricatedClaimData = try JSONSerialization.data(withJSONObject: fabricatedClaimObject, options: [.sortedKeys])
        let fabricatedClaimDestination = try makeContainer()
        _ = try WorkspaceRestoreService().restore(fabricatedClaimData, in: fabricatedClaimDestination.mainContext)
        XCTAssertFalse(try XCTUnwrap(fabricatedClaimDestination.mainContext.fetch(FetchDescriptor<GeneratedAnswer>()).first).isFactConfirmed)
    }

    func testFabricatedQuestionContextClaimIsSanitizedOnRestore() throws {
        let source = try makeContainer()
        let experience = TestFixtures.experience()
        let question = "Tell me about a process you improved."
        let draft = try GroundedAnswerEngine().generate(
            question: question,
            from: experience,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural
        )
        source.mainContext.insert(experience)
        source.mainContext.insert(GeneratedAnswer(
            question: question,
            experienceID: experience.id,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural,
            content: draft.content,
            quickCues: draft.quickCues,
            sourceFields: draft.claims.map(\.sourceField),
            sourceClaims: AnswerProvenanceService().storedClaims(from: draft.claims),
            followUps: draft.followUps,
            isFactConfirmed: true,
            sourceExperienceUpdatedAt: experience.updatedAt
        ))
        try source.mainContext.save()

        var object = try jsonObject(from: ExportService().makeExport(in: source.mainContext, includeConfidential: true))
        var answers = try XCTUnwrap(object["answers"] as? [[String: Any]])
        var claims = try XCTUnwrap(answers[0]["sourceClaims"] as? [[String: Any]])
        let index = try XCTUnwrap(claims.firstIndex { ($0["sourceField"] as? String) == "Question context" })
        let original = try XCTUnwrap(claims[index]["text"] as? String)
        let fabricated = "I secured executive endorsement."
        claims[index]["text"] = fabricated
        claims[index]["isSupported"] = true
        answers[0]["sourceClaims"] = claims
        answers[0]["content"] = (try XCTUnwrap(answers[0]["content"] as? String))
            .replacingOccurrences(of: original, with: fabricated)
        answers[0]["isFactConfirmed"] = true
        object["answers"] = answers

        let destination = try makeContainer()
        _ = try WorkspaceRestoreService().restore(
            JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
            in: destination.mainContext
        )

        let answer = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<GeneratedAnswer>()).first)
        XCTAssertFalse(answer.isFactConfirmed)
        XCTAssertTrue(answer.sourceClaims.contains(where: \.needsSource))
    }

    func testRestoreUsesValidatedSourceTimestampsInsteadOfArchiveValues() throws {
        let source = try makeContainer()
        _ = try insertCompleteWorkspace(into: source.mainContext)
        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)
        var object = try jsonObject(from: data)
        var answers = try XCTUnwrap(object["answers"] as? [[String: Any]])
        answers[0]["sourceExperienceUpdatedAt"] = "2099-01-01T00:00:00Z"
        answers[0]["sourceOpportunityUpdatedAt"] = "2099-01-01T00:00:00Z"
        object["answers"] = answers
        let altered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        let destination = try makeContainer()
        _ = try WorkspaceRestoreService().restore(altered, in: destination.mainContext)

        let experience = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<Experience>()).first)
        let opportunity = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<Opportunity>()).first)
        let answer = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<GeneratedAnswer>()).first)
        XCTAssertEqual(answer.sourceExperienceUpdatedAt, experience.updatedAt)
        XCTAssertEqual(answer.sourceOpportunityUpdatedAt, opportunity.contentUpdatedAt)
        XCTAssertTrue(answer.isFactConfirmed)
    }

    func testMalformedWrongFormatAndUnsupportedVersionsDoNotMutateWorkspace() throws {
        let destination = try makeContainer()
        let context = destination.mainContext

        assertPreviewError(.malformed, data: Data("{not-json".utf8), context: context)

        let source = try makeContainer()
        context.insert(TestFixtures.experience(title: "Current local example"))
        try context.save()
        _ = try insertCompleteWorkspace(into: source.mainContext)
        let valid = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)

        var wrongFormat = try jsonObject(from: valid)
        wrongFormat["identifier"] = "com.example.unrelated"
        assertPreviewError(
            .wrongFormat,
            data: try JSONSerialization.data(withJSONObject: wrongFormat),
            context: context
        )

        var unsupported = try jsonObject(from: valid)
        unsupported["version"] = RoleReadyExport.formatVersion + 1
        assertPreviewError(
            .unsupportedVersion(RoleReadyExport.formatVersion + 1),
            data: try JSONSerialization.data(withJSONObject: unsupported),
            context: context
        )

        let local = try context.fetch(FetchDescriptor<Experience>())
        XCTAssertEqual(local.map(\.title), ["Current local example"])
    }

    func testPartialArchiveWithMissingCollectionsRestoresIndependentValidRecords() throws {
        let source = try makeContainer()
        let experience = TestFixtures.experience(title: "Portable service recovery example")
        source.mainContext.insert(experience)
        try source.mainContext.save()
        let completeData = try ExportService().makeExport(in: source.mainContext, includeConfidential: false)
        let complete = try jsonObject(from: completeData)

        let partial: [String: Any] = [
            "identifier": try XCTUnwrap(complete["identifier"]),
            "version": try XCTUnwrap(complete["version"]),
            "createdAt": try XCTUnwrap(complete["createdAt"]),
            "includesConfidential": try XCTUnwrap(complete["includesConfidential"]),
            "experiences": try XCTUnwrap(complete["experiences"])
        ]
        let data = try JSONSerialization.data(withJSONObject: partial, options: [.sortedKeys])
        let destination = try makeContainer()

        let preview = try WorkspaceRestoreService().preview(data, in: destination.mainContext)
        XCTAssertEqual(preview.importable.experiences, 1)
        XCTAssertEqual(preview.importable.total, 1)

        _ = try WorkspaceRestoreService().restore(data, in: destination.mainContext)
        XCTAssertEqual(try destination.mainContext.fetch(FetchDescriptor<Experience>()).first?.title, experience.title)
    }

    func testRestoreFillsEmptyStarterProfileButNeverReplacesEnteredProfile() throws {
        let source = try makeContainer()
        _ = try insertCompleteWorkspace(into: source.mainContext)
        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)

        let blankDestination = try makeContainer()
        let blank = CareerProfile(
            name: "",
            headline: "",
            professionalSummary: "",
            currentOrganisation: "",
            targetRoles: [],
            skills: [],
            careerGoal: ""
        )
        blankDestination.mainContext.insert(blank)
        try blankDestination.mainContext.save()

        let blankPreview = try WorkspaceRestoreService().preview(data, in: blankDestination.mainContext)
        XCTAssertEqual(blankPreview.importable.profiles, 1)
        XCTAssertTrue(blankPreview.warnings.contains { $0.contains("empty starter profile") })
        _ = try WorkspaceRestoreService().restore(data, in: blankDestination.mainContext)

        let filledProfiles = try blankDestination.mainContext.fetch(FetchDescriptor<CareerProfile>())
        XCTAssertEqual(filledProfiles.count, 1)
        XCTAssertEqual(filledProfiles.first?.id, blank.id)
        XCTAssertEqual(filledProfiles.first?.name, "Test Applicant")

        let enteredDestination = try makeContainer()
        let entered = CareerProfile(
            name: "Local Applicant",
            headline: "Local profile",
            professionalSummary: "",
            currentOrganisation: "",
            targetRoles: [],
            skills: [],
            careerGoal: ""
        )
        enteredDestination.mainContext.insert(entered)
        try enteredDestination.mainContext.save()

        let enteredPreview = try WorkspaceRestoreService().preview(data, in: enteredDestination.mainContext)
        XCTAssertEqual(enteredPreview.importable.profiles, 0)
        XCTAssertEqual(enteredPreview.duplicates.profiles, 1)
        _ = try WorkspaceRestoreService().restore(data, in: enteredDestination.mainContext)

        let retained = try enteredDestination.mainContext.fetch(FetchDescriptor<CareerProfile>())
        XCTAssertEqual(retained.count, 1)
        XCTAssertEqual(retained.first?.name, "Local Applicant")
    }

    func testVersionOneHighlySensitiveExampleReturnsDisabledForMatching() throws {
        let source = try makeContainer()
        let example = TestFixtures.experience(title: "Restricted example", confidentiality: .highlySensitive)
        example.isApprovedForMatching = true
        source.mainContext.insert(example)
        try source.mainContext.save()
        let versionTwo = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)
        var object = try jsonObject(from: versionTwo)
        object["version"] = 1
        stripVersionTwoFields(from: &object)
        let versionOne = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        let destination = try makeContainer()
        let preview = try WorkspaceRestoreService().preview(versionOne, in: destination.mainContext)
        XCTAssertTrue(preview.warnings.contains { $0.contains("disabled for automatic matching") })
        _ = try WorkspaceRestoreService().restore(versionOne, in: destination.mainContext)

        let restored = try XCTUnwrap(destination.mainContext.fetch(FetchDescriptor<Experience>()).first)
        XCTAssertEqual(restored.confidentiality, .highlySensitive)
        XCTAssertFalse(restored.isApprovedForMatching)
    }

    func testInvalidParentRejectsDependentRecordsButKeepsValidIndependentRecords() throws {
        let source = try makeContainer()
        _ = try insertCompleteWorkspace(into: source.mainContext)
        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)
        var object = try jsonObject(from: data)
        var experiences = try XCTUnwrap(object["experiences"] as? [[String: Any]])
        experiences[0]["kind"] = "not-a-real-kind"
        object["experiences"] = experiences
        let damaged = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let destination = try makeContainer()

        let preview = try WorkspaceRestoreService().preview(damaged, in: destination.mainContext)

        XCTAssertEqual(preview.rejected.experiences, 1)
        XCTAssertEqual(preview.rejected.answers, 1)
        XCTAssertEqual(preview.rejected.practiceSessions, 1)
        XCTAssertEqual(preview.rejected.reflections, 1)
        XCTAssertEqual(preview.importable.opportunities, 1)
        XCTAssertEqual(preview.importable.requirements, 1)
        XCTAssertTrue(preview.warnings.contains { $0.contains("invalid") })

        let result = try WorkspaceRestoreService().restore(damaged, in: destination.mainContext)
        XCTAssertEqual(result.restored.opportunities, 1)
        XCTAssertEqual(result.restored.requirements, 1)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<Experience>()), 0)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<GeneratedAnswer>()), 0)
    }

    func testDuplicateAndLocalConflictHandlingNeverOverwritesCurrentRecord() throws {
        let source = try makeContainer()
        let incoming = TestFixtures.experience(title: "Incoming title")
        source.mainContext.insert(incoming)
        try source.mainContext.save()
        let single = try ExportService().makeExport(in: source.mainContext, includeConfidential: false)

        var duplicateObject = try jsonObject(from: single)
        let experiences = try XCTUnwrap(duplicateObject["experiences"] as? [[String: Any]])
        duplicateObject["experiences"] = experiences + experiences
        let duplicateData = try JSONSerialization.data(withJSONObject: duplicateObject, options: [.sortedKeys])

        let emptyDestination = try makeContainer()
        let duplicatePreview = try WorkspaceRestoreService().preview(duplicateData, in: emptyDestination.mainContext)
        XCTAssertEqual(duplicatePreview.importable.experiences, 1)
        XCTAssertEqual(duplicatePreview.duplicates.experiences, 1)
        _ = try WorkspaceRestoreService().restore(duplicateData, in: emptyDestination.mainContext)
        XCTAssertEqual(try emptyDestination.mainContext.fetchCount(FetchDescriptor<Experience>()), 1)

        let conflictDestination = try makeContainer()
        let local = TestFixtures.experience(title: "Local title")
        local.id = incoming.id
        conflictDestination.mainContext.insert(local)
        try conflictDestination.mainContext.save()

        let conflictPreview = try WorkspaceRestoreService().preview(single, in: conflictDestination.mainContext)
        XCTAssertEqual(conflictPreview.importable.total, 0)
        XCTAssertEqual(conflictPreview.duplicates.experiences, 1)
        XCTAssertThrowsError(try WorkspaceRestoreService().restore(single, in: conflictDestination.mainContext)) { error in
            XCTAssertEqual(error as? WorkspaceRestoreError, .nothingToRestore)
        }
        XCTAssertEqual(try conflictDestination.mainContext.fetch(FetchDescriptor<Experience>()).first?.title, "Local title")
    }

    func testPracticeSessionWithDanglingOptionalSourceIsRejected() throws {
        let source = try makeContainer()
        _ = try insertCompleteWorkspace(into: source.mainContext)
        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)
        var object = try jsonObject(from: data)
        var sessions = try XCTUnwrap(object["practiceSessions"] as? [[String: Any]])
        sessions[0]["experienceID"] = UUID().uuidString
        object["practiceSessions"] = sessions
        let damaged = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        let destination = try makeContainer()
        let preview = try WorkspaceRestoreService().preview(damaged, in: destination.mainContext)

        XCTAssertEqual(preview.rejected.practiceSessions, 1)
        XCTAssertEqual(preview.importable.practiceSessions, 0)
    }

    func testPracticeSessionSourceMustMatchItsAnswerAssociations() throws {
        let source = try makeContainer()
        _ = try insertCompleteWorkspace(into: source.mainContext)
        let otherExperience = TestFixtures.experience(title: "Different valid example")
        source.mainContext.insert(otherExperience)
        try source.mainContext.save()
        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)
        var object = try jsonObject(from: data)
        var sessions = try XCTUnwrap(object["practiceSessions"] as? [[String: Any]])
        sessions[0]["experienceID"] = otherExperience.id.uuidString
        object["practiceSessions"] = sessions
        let damaged = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        let destination = try makeContainer()
        let preview = try WorkspaceRestoreService().preview(damaged, in: destination.mainContext)
        XCTAssertEqual(preview.rejected.practiceSessions, 1)
        XCTAssertEqual(preview.importable.practiceSessions, 0)
    }

    func testReflectionUniquenessUsesOpportunityAsWellAsRecordID() throws {
        let source = try makeContainer()
        _ = try insertCompleteWorkspace(into: source.mainContext)
        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: true)
        var object = try jsonObject(from: data)
        let reflections = try XCTUnwrap(object["reflections"] as? [[String: Any]])
        var duplicateOpportunity = reflections[0]
        duplicateOpportunity["id"] = UUID().uuidString
        object["reflections"] = reflections + [duplicateOpportunity]
        let duplicated = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        let destination = try makeContainer()
        let preview = try WorkspaceRestoreService().preview(duplicated, in: destination.mainContext)
        XCTAssertEqual(preview.importable.reflections, 1)
        XCTAssertEqual(preview.duplicates.reflections, 1)
        _ = try WorkspaceRestoreService().restore(duplicated, in: destination.mainContext)
        XCTAssertEqual(try destination.mainContext.fetchCount(FetchDescriptor<InterviewReflection>()), 1)
    }

    func testRestoreRefusesToCommitOrRollbackUnrelatedPendingEdits() throws {
        let source = try makeContainer()
        let incoming = TestFixtures.experience(title: "Incoming example")
        source.mainContext.insert(incoming)
        try source.mainContext.save()
        let data = try ExportService().makeExport(in: source.mainContext, includeConfidential: false)

        let destination = try makeContainer()
        let local = TestFixtures.experience(title: "Unsaved local edit")
        destination.mainContext.insert(local)
        XCTAssertTrue(destination.mainContext.hasChanges)

        XCTAssertThrowsError(try WorkspaceRestoreService().restore(data, in: destination.mainContext)) { error in
            XCTAssertEqual(error as? WorkspaceRestoreError, .pendingChanges)
        }
        XCTAssertTrue(destination.mainContext.hasChanges)
        XCTAssertEqual(local.title, "Unsaved local edit")
    }

    func testFutureVersionEnvelopeIsReportedBeforePayloadDecoding() throws {
        let future: [String: Any] = [
            "identifier": RoleReadyExport.formatIdentifier,
            "version": RoleReadyExport.formatVersion + 1,
            "futurePayload": ["different": true]
        ]
        let data = try JSONSerialization.data(withJSONObject: future, options: [.sortedKeys])
        let destination = try makeContainer()

        assertPreviewError(
            .unsupportedVersion(RoleReadyExport.formatVersion + 1),
            data: data,
            context: destination.mainContext
        )
    }

    private func insertCompleteWorkspace(into context: ModelContext) throws -> (experienceID: UUID, opportunityID: UUID, answerID: UUID) {
        let stamp = Date(timeIntervalSince1970: 1_750_000_000)
        let profile = CareerProfile(
            name: "Test Applicant",
            headline: "Service delivery lead",
            professionalSummary: "Improves public-facing services.",
            currentOrganisation: "Test Department",
            targetRoles: ["Assistant Director"],
            skills: ["service delivery"],
            careerGoal: "Lead accessible services",
            createdAt: stamp,
            updatedAt: stamp
        )
        let experience = Experience(
            title: "Stabilised a public service",
            organisation: "Test Department",
            occurredAt: stamp,
            kind: .project,
            situation: "A public service was failing during peak demand.",
            task: "I was responsible for restoring reliable delivery.",
            actions: ["Mapped the failure path", "Added automated validation"],
            result: "The service met its published response standard.",
            evidence: "The operational dashboard recorded the recovery.",
            learning: "I learned to validate the highest-risk path first.",
            ownership: .owned,
            capabilities: [.delivery],
            tools: ["operational dashboard"],
            confidentiality: .standard,
            isApprovedForMatching: true,
            useCount: 3,
            createdAt: stamp,
            updatedAt: stamp
        )
        let opportunity = Opportunity(
            roleTitle: "Assistant Director, Service Delivery",
            organisation: "Example Agency",
            location: "Canberra",
            sourceText: "Lead reliable public services.",
            status: .preparing,
            notes: "Prepare a concise service recovery example.",
            createdAt: stamp,
            updatedAt: stamp,
            contentUpdatedAt: stamp
        )
        let requirement = JobRequirement(
            opportunityID: opportunity.id,
            text: "Lead reliable public services.",
            kind: .responsibility,
            keywords: ["reliable", "services"],
            capabilities: [.delivery],
            importance: 3,
            isConfirmed: true,
            createdAt: stamp
        )
        let claims = [
            StoredAnswerClaim(
                sourceField: "Situation",
                text: experience.situation,
                sourceText: experience.situation,
                origin: .generated,
                isSupported: true
            ),
            StoredAnswerClaim(
                sourceField: "Result",
                text: experience.result,
                sourceText: experience.result,
                origin: .generated,
                isSupported: true
            )
        ]
        let answer = GeneratedAnswer(
            question: "Tell me about a service you made more reliable.",
            experienceID: experience.id,
            opportunityID: opportunity.id,
            format: .quickPrompt,
            audience: .technicalPanel,
            tone: .natural,
            content: "\(experience.situation) \(experience.result)",
            quickCues: ["Peak demand", "Failure path", "Response standard"],
            sourceFields: ["Situation", "Result"],
            sourceClaims: claims,
            followUps: ["How did you validate the recovery?"],
            isFactConfirmed: true,
            sourceExperienceUpdatedAt: stamp,
            sourceOpportunityUpdatedAt: stamp,
            createdAt: stamp,
            updatedAt: stamp
        )
        let session = PracticeSession(
            answerID: answer.id,
            experienceID: experience.id,
            opportunityID: opportunity.id,
            question: answer.question,
            durationSeconds: 58,
            confidence: 4,
            notes: "Pause before the result.",
            practisedAt: stamp
        )
        let reflection = InterviewReflection(
            opportunityID: opportunity.id,
            questions: [answer.question],
            experienceIDs: [experience.id],
            strongestMoment: "The result was specific.",
            difficultMoment: "The opening was too long.",
            feedback: "Clarify personal ownership.",
            nextImprovement: "Lead with responsibility.",
            createdAt: stamp,
            updatedAt: stamp
        )

        context.insert(profile)
        context.insert(experience)
        context.insert(opportunity)
        context.insert(requirement)
        context.insert(answer)
        context.insert(session)
        context.insert(reflection)
        try context.save()
        return (experience.id, opportunity.id, answer.id)
    }

    private func jsonObject(from data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func stripVersionTwoFields(from object: inout [String: Any]) {
        let versionTwoFields: [String: [String]] = [
            "profiles": ["isSample", "createdAt", "updatedAt"],
            "experiences": ["isApprovedForMatching", "isSample", "useCount", "createdAt", "updatedAt"],
            "opportunities": ["isSample", "createdAt", "updatedAt"],
            "requirements": ["isConfirmed", "createdAt"],
            "answers": ["isUserEdited", "isSample", "updatedAt"],
            "reflections": ["updatedAt"]
        ]

        for (collection, keys) in versionTwoFields {
            guard var records = object[collection] as? [[String: Any]] else { continue }
            for index in records.indices {
                keys.forEach { records[index].removeValue(forKey: $0) }
            }
            object[collection] = records
        }

        guard var answers = object["answers"] as? [[String: Any]] else { return }
        for answerIndex in answers.indices {
            guard var claims = answers[answerIndex]["sourceClaims"] as? [[String: Any]] else { continue }
            for claimIndex in claims.indices {
                claims[claimIndex].removeValue(forKey: "sourceText")
                claims[claimIndex].removeValue(forKey: "origin")
                claims[claimIndex].removeValue(forKey: "isSupported")
            }
            answers[answerIndex]["sourceClaims"] = claims
        }
        object["answers"] = answers
    }

    private func assertPreviewError(
        _ expected: WorkspaceRestoreError,
        data: Data,
        context: ModelContext,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try WorkspaceRestoreService().preview(data, in: context), file: file, line: line) { error in
            XCTAssertEqual(error as? WorkspaceRestoreError, expected, file: file, line: line)
        }
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
