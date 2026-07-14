# Architecture decisions

## Local-first boundary

RoleReady is a device-owned SwiftUI application backed by SwiftData. The complete product works without an account, API key, backend, or network connection. This removes credentials, remote breach surface, subscription availability, and career-data transmission from the critical path. Optional App Lock adds an operating-system device-owner authentication boundary.

The application separates language interpretation from policy. Language services may propose drafts, requirement groups, wording, cues, or follow-up questions. Deterministic application code remains authoritative for privacy permissions, storage, match eligibility, source selection, numeric and ownership validation, word limits, approval, export, and restore.

## Connected career data flow

```text
Résumé, career notes, or manual input
-> local text extraction
-> unverified career, profile and source-span drafts
-> user review and explicit approval
-> persisted career facts, source records and baseline ResumeVersion

Job advertisement
-> deterministic requirement grouping
-> editable, confirmed JobRequirement records
-> relevance-gated evidence ranking
-> truthful tailored ResumeVersion and grounded CoverLetter
-> ApplicationActivity timeline and optional CareerReminder

Question + selected verified Experience + allowed role context
-> grounded draft and clause-level source claims
-> word-count and factual validation
-> user edits and provenance reconciliation
-> deterministic approval decision
-> saved answer and focused practice
```

Import parsing and career/job analysis run away from the main actor through detached tasks. SwiftData mutations and policy decisions remain on the main actor.

## Persistence

SwiftData owns 17 models:

1. `CareerProfile`
2. `CareerSource`
3. `CareerSourceSpan`
4. `CareerPosition`
5. `CareerEducation`
6. `CareerCertification`
7. `CareerSkill`
8. `Experience`
9. `Opportunity`
10. `JobRequirement`
11. `ResumeVersion`
12. `CoverLetter`
13. `ApplicationActivity`
14. `CareerReminder`
15. `GeneratedAnswer`
16. `PracticeSession`
17. `InterviewReflection`

Cross-feature references use stable UUIDs. Enums are stored as raw strings, and collections are encoded into scalar storage where needed. Imported career candidates remain value-type drafts until the user reviews them; this prevents an extraction heuristic from silently making evidence eligible for generation.

The career-workspace expansion is additive. New entities are registered in the same `ModelContainer`; new stored properties are optional or default-backed, allowing SwiftData's compatible automatic migration path to open an existing store. There is no destructive reset and no explicit `SchemaMigrationPlan`. Richer answer-claim metadata remains backward-compatibly encoded in `GeneratedAnswer.sourceClaimsJSON`; older claims decode with a `legacy` origin so edited legacy answers cannot inherit unearned approval.

## Application structure

- `App` owns the five-tab shell, navigation routes, onboarding state, app-lock lifecycle, privacy shield, and model container.
- `Features/Resume` owns résumé intake, review, library, editing, tailoring, PDF preview and export.
- `Features/Applications` owns the job application workspace, cover letters, activity tracking and reminders.
- `Features/Career` owns the approved career workspace; `Features/Evidence` owns reusable stories and advanced editing.
- `Features/Prepare` owns guided interview preparation, answer studio, practice home, decks and reflections.
- `Features/Roles` owns saved jobs, requirement editing and detailed match reports.
- `Features/You` owns profile, insights, privacy, settings, export, restore, and deletion.
- `Models` contains the 17 SwiftData entities and shared domain types.
- `Services` contains document and career-history ingestion, parsing, scoring, matching, grounded generation, language-provider contracts, provenance, approval, export, restore, reminders, haptics, and device authentication.
- `DesignSystem` provides semantic colours, Dynamic Type-aware typography, spacing, surfaces, and accessible reusable controls.

The Xcode project uses filesystem-synchronised source groups. The checked-in project and `project.yml` select Swift 6, complete strict concurrency checking, and warnings-as-errors.

## Provider-neutral language architecture

`RoleReadyLanguageService` defines three asynchronous capabilities:

- extract possible career examples;
- group job requirements; and
- compose an answer from a `GroundedExperience` value.

`LanguageServiceDescriptor` declares provider kind, availability, model identity, download needs, cost summary, privacy behaviour and whether data leaves the device. The shipped boundary now covers deterministic local, Apple on-device, optional local open-weight, and premium cloud providers.

`LanguageProviderRegistry` resolves the user’s preference. Automatic mode chooses Apple Foundation Models only when iOS reports the system model available; otherwise it uses `DeterministicLanguageService`. Apple language refinement is never authoritative: every changed answer clause is reconciled through `AnswerProvenanceService`, while the application continues to decide approval.

The open-weight provider has an integrity-checked model store and runtime protocol but no bundled model. `LocalModelCandidateCatalog` records Qwen3.5-2B and Gemma 3n E2B as evaluation candidates. Installing weights requires an exact manifest, byte count, SHA-256 checksum and explicit licence acceptance. Premium cloud transport is disabled until there is a secure backend; it requires explicit source-level consent and blocks highly sensitive data.

`AIEvaluationHarness` runs the same synthetic extraction, requirement, grounding and ownership fixtures across providers. Current results and the physical-device gate are documented in `LOCAL_AI_EVALUATION.md`.

This protocol is an extension boundary, not permission to move policy into a model. A future provider must return structured values, make its availability and transmission behaviour explicit, and pass the same deterministic validation before data is stored or an answer is approved. The product must continue to fall back to the deterministic provider.

The selected provider is applied to answer composition in `AnswerStudioView`. Résumé extraction, requirement grouping, matching, tailoring and cover-letter evidence selection remain deterministic in this release so the free local workflow is stable and testable. Extending model-assisted wording into those flows must retain the same structured-output and validation boundary.

## Honest evidence matching

`EvidenceMatcher` considers only examples explicitly approved for matching and excludes Highly sensitive examples from automatic use. It computes lexical, capability, tool, readiness, recency, and ownership factors, but first applies a relevance gate. Readiness, recency, or strong ownership cannot manufacture a match when there is no relevant term, capability, or tool signal.

The domain result uses four semantic tiers: direct, transferable, weak, and none. Only direct or transferable evidence enables answer creation in the guided flow. A numeric score remains an internal sorting input and a detailed diagnostic factor; the primary interface does not present it as a hiring probability.

## Grounding and approval

`GroundedAnswerEngine` accepts a value-type snapshot of one selected experience plus limited question and role context. It produces content, three to five cues, suggested follow-ups, source fields, and clause claims. Formats define real word-count ranges; speaking duration is estimated at 130 words per minute.

Each `StoredAnswerClaim` records:

- rendered claim text;
- source field and exact source text;
- origin (`generated`, `questionContext`, `editedSupported`, `editedUnsupported`, or `legacy`); and
- whether deterministic validation supports the wording.

`AnswerProvenanceService` splits edited content into clauses and attempts exact, near-exact, or explicitly linked source reconciliation. It rejects new numbers not present in the linked source and prevents contributed or supported work from being rewritten as led or owned. Merely selecting a source does not make an unsupported clause valid.

`AnswerApprovalService` owns the approval decision. Approval requires supported claims, no blocking grounded-review warning, non-empty content, and compliance with the selected format's word range. Editing linked example or role content invalidates current approval. Drafts with unsupported wording can be saved, but they cannot enter approved practice as verified material.

## Export and restore

`ExportService` writes a sorted, ISO-8601, version 3 JSON envelope containing the interview records plus career sources, source spans, approved career facts, résumé versions, cover letters, activities and reminders. The reduced-sensitivity filter is applied before source text and derived records are selected.

`WorkspaceRestoreService` accepts version 1, 2 and 3 envelopes up to 20 MB and follows this sequence:

```text
Read file -> verify JSON identifier and supported version
-> validate enums, required text, UUID dependencies, and sensitivity metadata
-> revalidate answer provenance and approval
-> preview new, duplicate, rejected, and sensitive records
-> explicit user confirmation
-> insert valid new records through a dedicated non-autosaving ModelContext
-> save once, or roll back on failure
```

Restore is deliberately add-only. Existing UUIDs win; local records are never overwritten or deleted. The only profile mutation allowed is filling a single genuinely empty, non-sample starter profile. Invalid independent records can be skipped while valid records restore, but a structurally malformed JSON collection fails safely before mutation.

Version 1 compatibility is conservative: missing collections decode as empty, legacy answers return unapproved, and Highly sensitive examples without an explicit historical matching flag return disabled for automatic matching. Version 2 predates the career workspace, so those collections restore empty with a warning. Version 3 validates source dependencies, résumé ancestry, cover-letter links, activities and reminders in addition to the existing answer provenance checks.

## Reliability and failure handling

- Parsing and generation return values and do not mutate SwiftData implicitly.
- Save failures roll back the relevant model context and surface plain-language errors.
- Source example and role revision timestamps invalidate stale approved answers.
- Destructive actions require confirmation; complete deletion also cancels reminders and temporary exports.
- First-run sample insertion is idempotent, and sample removal cleans dependent records.
- Restore refuses to begin while the current context has unsaved changes and never clears a workspace.
- Document and restore inputs are capped at 20 MB; imported text is capped at 250,000 characters and PDFs at 300 pages.
- No sensitive content is written through `print`, `Logger`, analytics, or crash instrumentation in the app target.

Near-limit archive decoding and validation currently execute on the main actor because the service reads SwiftData state. This can briefly affect responsiveness for an unusually large archive and is a candidate for a future snapshot-based validation refactor.

## Security and privacy

- App Lock calls iOS device-owner authentication, allowing biometrics or device passcode without exposing credentials to RoleReady.
- The lifecycle privacy shield covers content whenever the scene becomes inactive.
- The complete `AppShell` is marked `.privacySensitive()`; especially sensitive practice content also marks itself directly.
- Highly sensitive examples are always blocked from automatic matching; explicit answer use still requires the user to approve the example for that use.
- The default export omits Confidential and Highly sensitive examples and dependent materials, full extracted source text, full job-ad source text, private role notes, contact details, reminder notes, and all reflections.
- There are no embedded secrets, analytics SDKs, trackers, accounts, network clients, or remote permissions.

## Platform boundary

The deployment target is iOS 18 and the selected release toolchain is Xcode 26. Windows can perform repository and configuration checks only. Swift compilation, strict-concurrency diagnostics, SwiftData macro expansion, Simulator interaction, accessibility UI tests, and signing validation require macOS with Xcode and are enforced through `scripts/test-ios.sh` and the macOS CI workflow.
