# RoleReady

RoleReady is a private, evidence-to-interview companion for iPhone and iPad. It turns a person's real career history into role-specific STAR answers, selection-criteria responses, and short practice material without inventing accomplishments, ownership, or metrics.

The first experience is organised around one urgent task: **Prepare for a role**. A user can paste or import a résumé, career notes, or one example; add a job advertisement; review the suggested evidence; fill only the most important gaps; generate and verify an answer; then practise from memory cues. The complete path works locally with no account, API key, subscription, backend, or network connection.

## What it does

- Imports PDF, Word (`.docx`), RTF, or plain-text career history and job advertisements, or accepts pasted text.
- Extracts possible career examples as **unverified drafts**. The user can edit, combine, reject, or confirm them before they become matchable evidence.
- Groups job-advertisement text into editable requirement themes.
- Recommends examples using honest **Direct**, **Transferable**, **Weak or partial**, and **No verified evidence** tiers. A lexical similarity cannot create a confident recommendation by itself.
- Asks adaptive, plain-language questions about missing responsibility, rationale, outcomes, evidence, and learning.
- Generates grounded interview answers, written STAR and selection-criteria responses, plus secondary résumé and cover-letter formats.
- Enforces each format's word-count target and shows an approximate speaking duration for spoken answers.
- Keeps each answer clause connected to its source. Material edits lose supported status until they are removed, rewritten, or connected to evidence and revalidated.
- Allows only deterministically supported answers to be approved for practice.
- Provides rehearsal with the question, three to five memory cues, a timer, optional answer reveal, confidence rating, and likely follow-up questions. RoleReady is not live interview assistance.
- Preserves advanced example editing, role tracking, insights, post-interview reflections, confidentiality controls, App Lock, privacy shielding, local reminders, complete deletion, and a removable sample workspace.
- Exports a versioned JSON workspace and safely restores version 1 or version 2 archives through a preview-first, add-only process.
- Supports iPhone and iPad, Dynamic Type, VoiceOver, Reduce Motion, dark mode, and iOS 26 Liquid Glass with iOS 18 fallbacks.

## Product structure

RoleReady has three primary tabs:

- **Prepare** — the guided role-preparation entry point, active roles, next actions, and readiness overview.
- **My Examples** — searchable, reusable experience records and advanced evidence editing.
- **Practise** — approved answers, focused rehearsal, confidence records, and preparation decks.

Saved roles, Profile, Insights, Privacy, and Settings remain available as secondary destinations from Prepare. This keeps the recurring preparation journey coherent without turning RoleReady into a general job-search CRM.

## Architecture

- SwiftUI with the Observation framework for view and navigation state.
- SwiftData for seven local models: career profile, experience, opportunity, job requirement, generated answer, practice session, and interview reflection.
- Apple frameworks only: PDFKit, UniformTypeIdentifiers, LocalAuthentication, and UserNotifications.
- Provider-neutral `RoleReadyLanguageService` with a complete deterministic local implementation for career extraction, requirement grouping, and answer composition.
- Deterministic domain services remain authoritative for matching, privacy eligibility, source provenance, number and ownership validation, approval, word limits, persistence, export, and restore.
- Version 2 answer claims use backward-compatible metadata inside the existing stored claims field, so the SwiftData schema does not change.
- A filesystem-synchronised Xcode project, so source files under each target folder are discovered without manual project membership changes.
- Swift 6 language mode with complete strict concurrency and warnings treated as errors.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the trust, language-provider, and restore boundaries.

## Run on macOS

Requirements: Xcode 26 or newer with an iOS 18 or newer Simulator runtime.

1. Open `RoleReady.xcodeproj` in Xcode.
2. Select the `RoleReady` scheme and an available iPhone or iPad simulator.
3. Press **Run**.

No environment variables, API keys, accounts, or third-party packages are required. Notification and device-authentication prompts appear only after the related feature is enabled.

Command-line build, after choosing an installed simulator UUID:

```sh
xcodebuild build \
  -project RoleReady.xcodeproj \
  -scheme RoleReady \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UUID>' \
  CODE_SIGNING_ALLOWED=NO
```

List available simulators with `xcrun simctl list devices available`.

### Run on a physical iPhone

1. Connect and unlock an iPhone running iOS 18 or later, trust the Mac, and enable **Developer Mode** under **Settings > Privacy & Security** when prompted.
2. In Xcode, open the RoleReady app target's **Signing & Capabilities** tab.
3. Leave **Automatically manage signing** enabled and choose an Apple Developer team or free Personal Team. If the bundle identifier is unavailable for that team, replace it with a unique reverse-domain identifier.
4. Select the connected iPhone as the run destination and press **Run**.

Simulator use requires no account. Installing on a physical device requires an Apple Account for development signing. Free Personal Team provisioning expires periodically, so Xcode may need to rebuild and reinstall the app.

## Test on macOS

Use **Product > Test** in Xcode, or run the repository script from the repository root:

```sh
bash scripts/test-ios.sh
```

The script selects and boots an available iPhone simulator, runs unit and UI tests with code signing disabled, and writes a timestamped `.xcresult` under `TestResults/`. To choose stable output locations:

```sh
RESULT_BUNDLE_PATH="$PWD/TestResults/RoleReady-local.xcresult" \
DERIVED_DATA_PATH="$PWD/.derived-data" \
bash scripts/test-ios.sh
```

The result-bundle path must not already exist. The suites cover ingestion, matching edge cases, grounded generation, edit provenance, approval, export redaction, versioned restore, persistence, practice, the first-use preparation path, and large Dynamic Type.

## Verify on Windows

Windows cannot compile or execute this SwiftUI app because Xcode, the iOS SDK, and Simulator are unavailable. It can run dependency-free repository checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-windows.ps1
```

These checks are not a substitute for the macOS build-and-test gate. See [docs/QA.md](docs/QA.md).

## Privacy, export, and restore

RoleReady has no analytics SDK, advertising identifier, remote account, cloud dependency, embedded secret, or network client. The app shell is marked privacy-sensitive, and App Lock uses iOS device-owner authentication so biometric or passcode data never enters the app.

The default reduced-sensitivity export includes Standard and Private examples. It omits Confidential and Highly sensitive examples, answers and practice sessions derived from omitted examples, full job-ad source text, private role notes, and all interview reflections. A separate explicit option includes the complete dataset.

Restore accepts RoleReady version 1 and version 2 JSON files up to 20 MB. It validates the archive, previews new, duplicate, rejected, and sensitive records, and requires explicit confirmation. Restore adds valid new records, skips UUID duplicates, never clears the current workspace, and only fills a genuinely empty starter profile. Legacy version 1 answers return as drafts because their edited-source status cannot be proven.

See [docs/PRIVACY.md](docs/PRIVACY.md) before sharing or restoring an exported file.

## Current limitations

- Career-history extraction and requirement grouping are deterministic heuristics. Complex résumé layouts and ambiguous job advertisements may need user edits.
- Apple on-device and optional cloud language providers are architectural extension points only; the shipped app uses the deterministic local provider.
- There is no account, cross-device sync, browser scraping, résumé design, or live-interview assistance.
- Restore is add-only rather than a field-by-field merge, and near-maximum-size archives may take a moment to validate on the device.
- App Lock, notification delivery, and some operating-system privacy surfaces still need physical-device validation before distribution.

## Repository layout

```text
RoleReady/              app target
  App/                  root wiring and navigation
  DesignSystem/         semantic tokens and reusable components
  Models/               SwiftData entities and domain enums
  Services/             ingestion, matching, generation, trust, export, restore
  Features/             product screens grouped by journey
RoleReadyTests/         domain and persistence unit tests
RoleReadyUITests/       critical-flow UI tests
docs/                   product, architecture, privacy, and QA notes
scripts/                Windows verification and macOS test entry points
```
