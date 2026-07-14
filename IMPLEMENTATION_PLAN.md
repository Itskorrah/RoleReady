# RoleReady implementation plan

## Product outcome

Make RoleReady a private evidence-to-interview companion that gets a new user from career history and a job advertisement to one grounded, approved answer and a focused practice run in about five minutes.

## Decisions

- Make **Prepare**, **My Examples**, and **Practise** the three primary destinations. Keep role management inside Prepare instead of treating applications as a separate CRM.
- Replace sample/manual-first activation with one guided preparation flow: career input -> unverified example review -> role requirements -> honest match -> missing details -> grounded answer -> approval -> practice.
- Keep the seven-model SwiftData schema unchanged. Resume-derived examples remain value-type drafts until the user reviews them, avoiding a risky store migration.
- Keep the deterministic local experience fully useful. Add a provider-neutral `LanguageService` boundary for later Apple on-device or explicitly permitted cloud language assistance; deterministic code remains authoritative for storage, privacy, matching, word limits, provenance, and approval.
- Replace percentage-like match presentation with four honest tiers: direct, transferable, weak/partial, and no verified evidence. A relevance gate prevents readiness, recency, or ownership from manufacturing a match.
- Reconcile every edited answer clause against source evidence. Materially edited or added clauses lose verified status until connected to a source and deterministically validated. Unsupported clauses can be saved as a draft but cannot be approved.
- Upgrade export to a faithful version 2 archive and restore version 1 or 2 through validation, preview, add-only duplicate handling, dependency checks, and rollback on failure.

## Implementation sequence

1. **Foundation and trust**
   - Career-history ingestion value types and deterministic parser.
   - Provider-neutral language-service protocol with deterministic implementation.
   - Calibrated matcher and four-tier explanations.
   - Clause reconciliation, approval decision, word-count and speaking-duration validation.
   - Versioned export/restore preview and transactional add-only restore.

2. **Five-minute journey**
   - Task-first onboarding with Prepare for a role as the primary action.
   - Prepare dashboard and one guided modal flow using existing document import, job parsing, matching, answer, and practice foundations.
   - Progressive example review and only the missing-detail prompts needed for a credible answer.
   - Approval transitions directly into focused rehearsal.

3. **Information architecture and durability**
   - Three-tab shell: Prepare, My Examples, Practise.
   - Existing roles, insights, profile, privacy, advanced editors, reflections, and sample workspace remain reachable as secondary tools.
   - Settings gains restore preview, duplicate disclosure, explicit confirmation, and clear recovery errors.

4. **Release gate**
   - Unit tests for ingestion, misleading match edges, word limits, edited provenance, archive migration, malformed/partial restore, and duplicates.
   - Update UI tests for the first-use guided preparation path and remove stale timing assumptions.
   - Build and run the full suite, then manually verify the critical path, dark mode, large Dynamic Type, VoiceOver labels, Reduce Motion, iPhone/iPad layout, and realistic input sizes in Simulator.

## Compatibility and safety

- No API key, account, network entitlement, analytics, tracker, new dependency, self-hosted model, or sensitive logging.
- Existing SwiftData entities and UUID references remain intact; richer claim metadata lives in the existing claim JSON field with backward-compatible decoding.
- Version 1 archives restore conservatively: legacy answers return unapproved because their edit/provenance state cannot be proven.
- Restore defaults to keeping local records when UUIDs collide and never clears the current workspace.
- The pre-existing uncommitted Swift 6/document-import fixes are preserved.

## Verification snapshot — 14 July 2026

- The app builds for a generic iOS Simulator destination with Swift warnings treated as errors.
- All 71 unit tests pass, covering ingestion, matching, grounding, edits, approval, export, restore, persistence, and practice policy.
- All six UI scenarios pass together in the final iPhone simulator result bundle. The critical fresh-install flow now opens a supported claim's source sheet before approval and practice.
- The sample workspace navigation and honest-match report pass on a 13-inch iPad simulator; onboarding was visually reviewed in light and dark appearance; accessibility XXXL remains navigable.
- The supplied strategy board and final simulator screens were reviewed side by side. Visible internal matching stems and the overlong default answer found in that review were corrected.
- `git diff --check` passes and the Xcode project file has not required dependency or target changes.

Still required before an App Store release: hands-on physical-device checks for App Lock and notifications, a full VoiceOver and Reduce Motion pass, near-limit document performance testing, and a signed archive. Those release activities are outside this local implementation pass.
