# RoleReady

RoleReady is a private career workspace for iPhone and iPad. It turns a person's approved career history into ATS-safe résumés, truthful job-specific applications, grounded cover letters, and role-specific interview preparation without inventing accomplishments, ownership, or metrics.

The first experience starts with the document most applicants already have: a résumé. A user can import PDF, Word, RTF, or text; review and approve the extracted facts; create multiple résumé versions; add a job advertisement; tailor an application; draft a cover letter; track progress and reminders; then prepare and practise grounded answers. The complete free path works locally with no account, API key, subscription, backend, or network connection.

## What it does

- Imports PDF, Word (`.docx`), RTF, or plain-text career history and job advertisements, or accepts pasted text.
- Extracts possible career examples as **unverified drafts**. The user can edit, combine, reject, or confirm them before they become matchable evidence.
- Groups job-advertisement text into editable requirement themes.
- Recommends examples using honest **Direct**, **Transferable**, **Weak or partial**, and **No verified evidence** tiers. A lexical similarity cannot create a confident recommendation by itself.
- Asks adaptive, plain-language questions about missing responsibility, rationale, outcomes, evidence, and learning.
- Builds editable technical and general résumé versions from one approved career profile, including reorderable sections and selectable-text A4 PDF export.
- Repositions a baseline résumé for a specific job using explicit Direct, Transferable, Weak or partial, and No verified evidence classifications.
- Creates editable, section-regenerable cover letters with validation warnings and an evidence trail.
- Tracks applications, status history, notes, contacts, interviews and user-created local reminders, then hands the same role context into interview preparation.
- Generates grounded interview answers, written STAR and selection-criteria responses.
- Enforces each format's word-count target and shows an approximate speaking duration for spoken answers.
- Keeps each answer clause connected to its source. Material edits lose supported status until they are removed, rewritten, or connected to evidence and revalidated.
- Allows only deterministically supported answers to be approved for practice.
- Provides rehearsal with the question, three to five memory cues, a timer, optional answer reveal, confidence rating, and likely follow-up questions. RoleReady is not live interview assistance.
- Preserves advanced example editing, role tracking, insights, post-interview reflections, confidentiality controls, App Lock, privacy shielding, local reminders, complete deletion, and a removable sample workspace.
- Exports a version 3 JSON workspace and safely restores version 1, 2, or 3 archives through a preview-first, add-only process.
- Supports iPhone and iPad, Dynamic Type, VoiceOver, Reduce Motion, dark mode, and iOS 26 Liquid Glass with iOS 18 fallbacks.

## Product structure

RoleReady has five primary tabs:

- **Today** — urgent actions, active roles, readiness and shortcuts.
- **Résumés** — import, build, duplicate, edit, tailor, preview and export résumé versions.
- **Jobs** — saved opportunities, match reports and the connected application workspace.
- **Interview** — approved answers, focused rehearsal, confidence records and preparation decks.
- **Career** — the approved career profile, work, education, skills, source documents and reusable examples.

Profile, Insights, Privacy and Settings remain secondary destinations. The application tracker is intentionally personal and lightweight rather than a recruiter-facing CRM.

## Architecture

- SwiftUI with the Observation framework for view and navigation state.
- SwiftData for 17 local models covering career sources, approved profile facts, résumé and cover-letter versions, applications, reminders and interview preparation.
- Apple frameworks only: PDFKit, UniformTypeIdentifiers, LocalAuthentication, and UserNotifications.
- Provider-neutral `RoleReadyLanguageService` with deterministic local generation, an availability-gated Apple Foundation Models integration, a licence/checksum-gated local open-weight slot, and a disabled premium-cloud transport boundary.
- Deterministic domain services remain authoritative for matching, privacy eligibility, source provenance, number and ownership validation, approval, word limits, persistence, export, and restore.
- The expanded additive schema uses optional or default-backed fields and SwiftData's compatible automatic migration path; no destructive migration or manual data reset is required.
- A filesystem-synchronised Xcode project, so source files under each target folder are discovered without manual project membership changes.
- Swift 6 language mode with complete strict concurrency and warnings treated as errors.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the trust, language-provider, and restore boundaries.

## Run on macOS

Requirements: Xcode 26 or newer with an iOS 18 or newer Simulator runtime.

1. Open `RoleReady.xcodeproj` in Xcode.
2. Select the `RoleReady` scheme and an available iPhone or iPad simulator.
3. Press **Run**.

No environment variables, API keys, accounts, model downloads, or third-party packages are required for the complete local experience. Notification and device-authentication prompts appear only after the related feature is enabled. Premium cloud generation remains disabled until a publisher supplies a secure backend; a provider key must never be embedded in the app.

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

Restore accepts RoleReady version 1, version 2, and current version 3 JSON files up to 20 MB. It validates the archive, previews new, duplicate, rejected, and sensitive records, and requires explicit confirmation. Restore adds valid new records, skips UUID duplicates, rejects cyclic résumé ancestry, never clears the current workspace, and only fills a genuinely empty starter profile. Legacy version 1 answers return as drafts because their edited-source status cannot be proven.

See [docs/PRIVACY.md](docs/PRIVACY.md) before sharing or restoring an exported file.

## Current limitations

- Career-history extraction and requirement grouping are conservative deterministic heuristics. Complex résumé layouts and ambiguous job advertisements may need user edits; scanned PDFs need OCR before import.
- Apple on-device language refinement requires a supported iOS 26+ device with Apple Intelligence available. The deterministic provider remains the fallback on every supported device.
- Optional open-weight runtime and weights are not bundled. Qwen3.5-2B is the first evaluation candidate, not a production dependency; Gemma 3n remains a licensed comparison candidate.
- Premium cloud generation has no embedded credential and no live transport. It requires a secure backend, explicit per-request consent, cost controls and publisher-supplied credentials.
- PDF and plain-text sharing are implemented. Native `.docx` generation, email delivery, account sync, browser job scraping and live-interview assistance are not included.
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
