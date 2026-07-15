# Quality assurance and release gate

## Validation layers

RoleReady uses complementary gates:

1. `scripts/verify-windows.ps1` performs dependency-free repository checks for required files, the 17-model declaration, the Today/Résumés/Jobs/Interview/Career contract, project settings, asset metadata, global privacy-sensitive coverage, and absence of undeclared package dependencies.
2. Unit tests exercise deterministic product policy, parsing, matching, answer grounding, provenance, approval, persistence, export, and restore.
3. UI tests exercise onboarding in light and dark appearance, the first-use preparation journey, source inspection, manual example capture, honest sample matching, practice, accessibility text sizing, and adaptive tab navigation.
4. Manual Simulator and physical-device passes cover visual quality, operating-system permissions, App Lock, background shielding, notifications, and device-dependent accessibility behaviour.

The GitHub Actions workflow in `.github/workflows/ios.yml` runs the complete macOS gate on `macos-26`, reports the selected Xcode version, and uploads the `.xcresult` whether the tests pass or fail.

## Requirements

- Xcode 26 or newer;
- an iOS 18 or newer iPhone Simulator runtime; and
- no API key, account, package resolution, or external service.

The deployment target is iOS 18. The project uses Swift 6 with complete strict concurrency and treats Swift warnings as errors.

## Exact local commands

Run Windows repository checks from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-windows.ps1
```

Run the complete macOS unit and UI suite. The script chooses and boots an available iPhone Simulator:

```sh
bash scripts/test-ios.sh
```

Choose stable result and derived-data locations when diagnosing a run:

```sh
RESULT_BUNDLE_PATH="$PWD/TestResults/RoleReady-local.xcresult" \
DERIVED_DATA_PATH="$PWD/.derived-data" \
CODE_SIGNING_ALLOWED=NO \
bash scripts/test-ios.sh
```

The result path must not already exist. Delete or rename an earlier local result deliberately before reusing a path.

Build without running tests, after obtaining a UUID from `xcrun simctl list devices available`:

```sh
xcodebuild build \
  -project RoleReady.xcodeproj \
  -scheme RoleReady \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UUID>' \
  -derivedDataPath "$PWD/.derived-data" \
  CODE_SIGNING_ALLOWED=NO
```

Run only the unit target:

```sh
xcodebuild test \
  -project RoleReady.xcodeproj \
  -scheme RoleReady \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UUID>' \
  -derivedDataPath "$PWD/.derived-data" \
  -only-testing:RoleReadyTests \
  CODE_SIGNING_ALLOWED=NO
```

Run only the critical UI target:

```sh
xcodebuild test \
  -project RoleReady.xcodeproj \
  -scheme RoleReady \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UUID>' \
  -derivedDataPath "$PWD/.derived-data" \
  -only-testing:RoleReadyUITests \
  CODE_SIGNING_ALLOWED=NO
```

Inspect a result bundle in Xcode, or list its tests from Terminal:

```sh
xcrun xcresulttool get test-results tests \
  --path TestResults/RoleReady-local.xcresult
```

## Automated test scope

The checked-in unit suites cover:

- career-history extraction, conservative ownership defaults, warnings, and combining drafts;
- document import types, size and empty-document failures;
- evidence scoring, job parsing, and opportunity planning;
- relevance-gated direct, transferable, weak, and no-evidence matching, including misleading lexical edge cases;
- grounded answer formats, word-count limits, speaking duration, numeric and ownership validation;
- source-claim reconciliation, unsupported edits, explicit source links, and deterministic approval;
- approval invalidation after example or role revision;
- reduced-sensitivity export, version 3 career-workspace field fidelity, provenance sanitisation, and dependent-record filtering;
- version 1, version 2 and version 3 restore, duplicate handling, cyclic résumé rejection, partial archives, malformed and future versions, dependency rejection, sensitivity metadata, profile safety, rollback guards, and restored-answer revalidation;
- résumé intake, source spans, PDF rendering, job-specific tailoring, cover-letter grounding, section regeneration, application activity and reminder persistence;
- deterministic, Apple, local open-weight and premium-cloud routing boundaries plus the repeatable AI evaluation harness;
- SwiftData seed integrity, sample removal, preferences reset, and dependent-record cleanup; and
- practice session and reflection associations.

The checked-in UI suite covers:

- task-first onboarding and primary action reachability at accessibility XXXL;
- the complete fresh-workspace path from pasted career history and job text through draft review, honest matching, strengthening, grounded answer generation, opening a claim's supporting evidence, approval, and guided practice;
- sample examples, saved roles, semantic match tiers, and absence of percentage-like hiring-probability copy;
- approved practice cues and explicit pre-interview positioning; and
- manual example capture and retrieval under Career;
- baseline résumé editing and PDF preview;
- the connected application path through tailoring, cover letter, status and reminder creation;
- focused verification that cover letters prefer relevant approved role evidence over redundant skill-only filler;
- onboarding at accessibility XXXL; and
- onboarding in dark appearance, plus adaptive five-tab navigation on iPad.

## Critical-path manual script

Run this path on a clean Simulator after the automated suite:

1. Delete the app from the Simulator and launch it.
2. Confirm onboarding explains real evidence, user approval, local-by-default storage, and the no-live-assistance boundary.
3. Choose **Import or build my résumé**.
4. Import or paste realistic career history and confirm extracted items are marked unverified, with source excerpts available.
5. Edit, reject, or combine drafts; approve one example for matching.
6. Import or paste a realistic job advertisement and review its requirement themes.
7. Confirm the recommendation is Direct, Transferable, Weak or partial, or No verified evidence with a plain-language reason.
8. Answer the missing-detail prompts and generate the default 60-second answer.
9. Inspect every claim's supporting evidence.
10. Add an unsupported number and stronger ownership statement. Confirm approval is revoked and the clauses require a source.
11. Remove or truthfully resolve the unsupported edits, approve the answer, and enter guided practice.
12. Reveal cues, run the timer, record confidence, and inspect likely follow-ups.
13. Create a baseline résumé, preview its PDF, then tailor it for the saved job and review every evidence classification.
14. Create and edit a cover letter; confirm it omits unrelated evidence, then update status and create a local reminder.
15. Create both reduced-sensitivity and complete exports; inspect the reduced archive for omitted sensitive fields.
16. Add a local record, restore the archive, review the preview, and confirm restore does not delete or overwrite the local record.
17. Attempt malformed, wrong-identifier, future-version, duplicate, cyclic résumé, and partial archives; confirm clear errors and no workspace loss.

## Accessibility and visual matrix

Review the first-use journey, example editor, answer source review, practice, Settings restore preview, empty states, and errors under:

- light and dark appearance;
- default and accessibility XXXL Dynamic Type;
- VoiceOver with logical reading order, descriptive labels, values, and hints;
- Reduce Motion;
- Increase Contrast where available;
- a compact iPhone and a large iPhone; and
- iPad portrait and landscape with split-screen widths.

Important actions must remain visible without gesture-only discovery, minimum touch targets must remain usable, and sheets must scroll to their confirmation controls.

## Realistic-size and failure checks

- Import multi-page PDFs, `.docx`, RTF, and plain text near—but below—the 20 MB and 250,000-character limits.
- Verify a scanned PDF with no selectable text produces a useful paste-manually warning or empty-document error.
- Exercise a career history that yields no strong example and a role that has no verified match.
- Populate a large example library and role with many requirement themes; check preparation interaction and matching latency.
- Preview a near-20 MB archive and watch for a temporary main-thread pause during validation.
- Background the app on every sensitive screen and confirm the privacy shield appears.
- Force a persistence or file-access failure where practical and confirm existing data remains intact.

## Release checklist

- [ ] Windows repository verification passes with the five-tab career-workspace contract.
- [ ] `bash scripts/test-ios.sh` passes on Xcode 26 with no warnings.
- [ ] The complete first-use UI path passes from clean install through approved practice.
- [ ] Reduced and complete export contents are manually inspected.
- [ ] Version 1, version 2 and version 3 restore pass with duplicates, invalid records, and existing local data.
- [ ] App Lock cancellation, lockout recovery, background privacy shield, local notifications, and complete deletion are verified on a physical device.
- [ ] VoiceOver, accessibility XXXL, Reduce Motion, dark mode, and high-contrast appearance receive a final manual pass.
- [ ] Compact iPhone and iPad portrait, landscape, and split-view layouts receive a final manual pass.
- [ ] No realistic or sensitive user data appears in source fixtures, screenshots intended for publication, logs, `.xcresult` attachments, or crash output.
- [ ] A distribution archive is signed with the intended Apple Developer team and App Store privacy and notification disclosures are reviewed by the publisher.

## Known validation limitations

- `scripts/test-ios.sh` selects an iPhone and does not replace manual iPad, dark-mode, VoiceOver, or physical-device checks.
- UI tests launch with an in-memory SwiftData store; on-disk upgrade and long-lived workspace checks need a manual installed-build pass.
- App Lock and notification behaviour depend on system state and require physical-device verification before distribution.
- Restore validation currently reads SwiftData state on the main actor, so a near-maximum-size archive can cause a brief pause.
- Windows verification never compiles Swift, expands SwiftData macros, launches Simulator, or validates signing.
