import XCTest
@testable import RoleReady

@MainActor
final class AnswerTrustTests: XCTestCase {
    private let engine = GroundedAnswerEngine()
    private let provenance = AnswerProvenanceService()

    func testGeneratedClausesRetainActualSourceExcerpts() throws {
        let experience = TestFixtures.experience()
        let draft = try engine.generate(
            question: "Tell me about a process you improved.",
            from: experience,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural
        )

        XCTAssertLessThanOrEqual(draft.wordCount, AnswerFormat.sixtySeconds.targetWordCount.upperBound)
        XCTAssertEqual(draft.wordCount, draft.content.split(whereSeparator: \.isWhitespace).count)
        XCTAssertTrue(draft.claims.allSatisfy { !$0.sourceField.isEmpty && !$0.sourceText.isEmpty })
        XCTAssertTrue(draft.claims.allSatisfy(\.isSupported))
    }

    func testMaterialNewMetricLosesSupportEvenWhenLinkedToAResult() throws {
        let experience = TestFixtures.experience()
        let draft = try engine.generate(
            question: "Tell me about a process you improved.",
            from: experience,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural
        )
        let added = "I increased adoption by 75%."
        let edited = draft.content + " " + added
        let key = provenance.claimKey(for: added)

        let unlinked = provenance.reconcile(
            content: edited,
            generatedContent: draft.content,
            generatedClaims: draft.claims,
            experience: experience
        )
        let linked = provenance.reconcile(
            content: edited,
            generatedContent: draft.content,
            generatedClaims: draft.claims,
            experience: experience,
            sourceOverrides: [key: .result]
        )

        XCTAssertTrue(unlinked.contains(where: \.needsSource))
        XCTAssertTrue(linked.contains { $0.text.localizedCaseInsensitiveContains("75%") && $0.needsSource })
    }

    func testExactUserAddedEvidenceCanBeExplicitlyLinked() throws {
        let experience = TestFixtures.experience()
        let draft = try engine.generate(
            question: "Give me short cues.",
            from: experience,
            format: .quickPrompt,
            audience: .hiringManager,
            tone: .natural
        )
        let added = experience.evidence
        let edited = draft.content + ". " + added
        let claims = provenance.reconcile(
            content: edited,
            generatedContent: draft.content,
            generatedClaims: draft.claims,
            experience: experience,
            sourceOverrides: [provenance.claimKey(for: added): .evidence]
        )

        let addedClaim = try XCTUnwrap(claims.last)
        XCTAssertEqual(provenance.claimKey(for: addedClaim.text), provenance.claimKey(for: added))
        XCTAssertTrue(addedClaim.isSupported)
        XCTAssertEqual(addedClaim.origin, .editedSupported)
        XCTAssertEqual(addedClaim.sourceField, "Evidence")
    }

    func testOwnershipOverstatementCannotBeApprovedThroughSourceLinking() throws {
        let experience = TestFixtures.experience(ownership: .contributed)
        let draft = try engine.generate(
            question: "Tell me about your contribution.",
            from: experience,
            format: .quickPrompt,
            audience: .hiringManager,
            tone: .natural
        )
        let added = "I led the entire program."
        let claims = provenance.reconcile(
            content: draft.content + ". " + added,
            generatedContent: draft.content,
            generatedClaims: draft.claims,
            experience: experience,
            sourceOverrides: [provenance.claimKey(for: added): .action]
        )

        XCTAssertTrue(claims.contains { $0.text.localizedCaseInsensitiveContains("led the entire") && $0.needsSource })
    }

    func testReversingOrderedNumbersCannotBeApprovedThroughSourceLinking() throws {
        let experience = TestFixtures.experience(result: "Processing fell from 20 days to 5 days.")
        let draft = try engine.generate(
            question: "What changed?",
            from: experience,
            format: .quickPrompt,
            audience: .hiringManager,
            tone: .natural
        )
        let reversed = "Processing fell from 5 days to 20 days."

        let claims = provenance.reconcile(
            content: draft.content + ". " + reversed,
            generatedContent: draft.content,
            generatedClaims: draft.claims,
            experience: experience,
            sourceOverrides: [provenance.claimKey(for: reversed): .result]
        )

        XCTAssertTrue(claims.contains { $0.text.contains("5 days to 20 days") && $0.needsSource })
    }

    func testContributedSourceCannotBecomeManagedOwnership() throws {
        let experience = TestFixtures.experience(
            actions: ["I helped manage the migration plan and documented the risks."],
            ownership: .contributed
        )
        let draft = try engine.generate(
            question: "What did you contribute?",
            from: experience,
            format: .quickPrompt,
            audience: .hiringManager,
            tone: .natural
        )
        let overstatement = "I managed the migration plan."

        let claims = provenance.reconcile(
            content: draft.content + ". " + overstatement,
            generatedContent: draft.content,
            generatedClaims: draft.claims,
            experience: experience,
            sourceOverrides: [provenance.claimKey(for: overstatement): .action]
        )

        XCTAssertTrue(claims.contains { $0.text.localizedCaseInsensitiveContains("I managed") && $0.needsSource })
    }

    func testRemovingNegationCannotBeApprovedThroughSourceLinking() throws {
        let experience = TestFixtures.experience(
            actions: ["I did not approve releases until the regression checks passed."]
        )
        let draft = try engine.generate(
            question: "What did you do?",
            from: experience,
            format: .quickPrompt,
            audience: .hiringManager,
            tone: .natural
        )
        let opposite = "I did approve releases until the regression checks passed."

        let claims = provenance.reconcile(
            content: draft.content + ". " + opposite,
            generatedContent: draft.content,
            generatedClaims: draft.claims,
            experience: experience,
            sourceOverrides: [provenance.claimKey(for: opposite): .action]
        )

        XCTAssertTrue(claims.contains { $0.text.localizedCaseInsensitiveContains("did approve") && $0.needsSource })
    }

    func testApprovalRejectsContentNotCoveredByClaims() throws {
        let experience = TestFixtures.experience()
        let draft = try engine.generate(
            question: "Tell me about a process you improved.",
            from: experience,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural
        )
        let padded = draft.content + " I secured executive endorsement."

        let decision = AnswerApprovalService().decision(
            content: padded,
            format: .sixtySeconds,
            claims: draft.claims,
            experience: experience
        )

        XCTAssertFalse(decision.canApprove)
        XCTAssertTrue(decision.issues.contains { $0.localizedCaseInsensitiveContains("every answer clause") })
    }

    func testUnchangedSentencesInsideAMultiSentenceClaimRetainSupport() throws {
        let experience = TestFixtures.experience(
            actions: ["I mapped the process. I tested the revised workflow with assessors."]
        )
        let draft = try engine.generate(
            question: "Tell me what you did.",
            from: experience,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural
        )
        let edited = draft.content + " An extra unsupported claim."

        let claims = provenance.reconcile(
            content: edited,
            generatedContent: draft.content,
            generatedClaims: draft.claims,
            experience: experience
        )

        XCTAssertTrue(claims.contains { $0.text.localizedCaseInsensitiveContains("tested the revised workflow") && !$0.needsSource })
        XCTAssertTrue(claims.last?.needsSource == true)
    }

    func testApprovalPolicyRejectsUnsupportedOrWrongLengthContent() {
        let experience = TestFixtures.experience()
        let unsupported = AnswerClaim(
            text: "I improved the outcome by 75%.",
            sourceField: "Edited — source needed",
            origin: .editedUnsupported,
            isSupported: false
        )
        let decision = AnswerApprovalService().decision(
            content: "I improved the outcome by 75%.",
            format: .sixtySeconds,
            claims: [unsupported],
            experience: experience
        )

        XCTAssertFalse(decision.canApprove)
        XCTAssertTrue(decision.issues.contains { $0.localizedCaseInsensitiveContains("verified source") })
        XCTAssertTrue(decision.issues.contains { $0.localizedCaseInsensitiveContains("between 105 and 145") })
        XCTAssertTrue(decision.issues.contains { $0.localizedCaseInsensitiveContains("unsupported number") })
    }

    func testEditedStoredAnswerWithUnsupportedClaimNeverAppearsApproved() {
        let experience = TestFixtures.experience()
        let answer = GeneratedAnswer(
            question: "Tell me about a process you improved.",
            experienceID: experience.id,
            format: .sixtySeconds,
            audience: .hiringManager,
            tone: .natural,
            content: "I increased adoption by 75%.",
            quickCues: ["Adoption"],
            sourceFields: ["Edited — source needed"],
            sourceClaims: [
                StoredAnswerClaim(
                    sourceField: "Edited — source needed",
                    text: "I increased adoption by 75%.",
                    origin: .editedUnsupported,
                    isSupported: false
                )
            ],
            followUps: [],
            isFactConfirmed: true,
            isUserEdited: true,
            sourceExperienceUpdatedAt: experience.updatedAt
        )

        XCTAssertFalse(answer.hasTrustworthyProvenance)
        XCTAssertFalse(answer.isApprovalCurrent(for: experience))
    }
}
