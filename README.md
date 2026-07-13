# RoleReady

RoleReady is a private, local-first iOS career preparation app that turns verified work, study, volunteer, and project experience into stronger applications and interview answers.

The product is evidence-led: capture an experience once, strengthen what is missing, match it transparently to a role, and create answers whose claims remain traceable to the original story. Matching and answer generation run on device and require no account, API key, subscription, backend, or network connection.

## What it does

- Builds a guided Evidence Bank with STAR structure, ownership prompts, confidentiality controls, and constructive evidence-strength coaching.
- Analyses pasted job advertisements and imported PDF, Word (.docx), RTF, or plain-text documents.
- Explains requirement-to-evidence matches, alternatives, cautions, and honest gaps.
- Creates grounded quick cues, 30-, 60-, and 90-second answers, written STAR responses, resume bullets, cover-letter material, and selection-criteria responses.
- Provides pre-interview practice decks with memory cues, follow-up prompts, confidence tracking, and post-interview reflections. RoleReady is not live interview assistance.
- Tracks application status and interview dates, with optional reminders scheduled only for upcoming interviews.
- Exports user-initiated JSON, supports complete local deletion, and offers optional Face ID or device-passcode App Lock.
- Includes a realistic removable sample workspace for evaluation.
- Supports iPhone and iPad, Dynamic Type, VoiceOver, Reduce Motion, dark mode, and iOS 26 Liquid Glass with iOS 18 fallbacks.

## Product structure

RoleReady has four primary tabs:

- **Today** — upcoming interviews, preparation health, and next actions.
- **Evidence** — searchable stories, guided capture, and evidence coaching.
- **Roles** — job analysis, requirements, evidence matches, and application status.
- **Practise** — saved grounded answers and pre-interview practice decks.

Profile, Insights, Privacy, and Settings are available from Today rather than occupying another tab.

## Architecture

- SwiftUI with the Observation framework for view and navigation state.
- SwiftData for seven local models: career profile, experience, opportunity, job requirement, generated answer, practice session, and interview reflection.
- Apple frameworks only: PDFKit, UniformTypeIdentifiers, LocalAuthentication, and UserNotifications.
- Deterministic domain services for scoring, parsing, matching, grounded generation, export, and interview reminders.
- A filesystem-synchronised Xcode project, so source files under each target folder are discovered without manual project-file membership changes.
- Swift 6 language mode with complete strict concurrency and warnings treated as errors.

## Run on macOS

Requirements: Xcode 26 or newer, with an iOS 18 or newer Simulator runtime.

1. Open `RoleReady.xcodeproj` in Xcode.
2. Select the `RoleReady` scheme and an available iPhone or iPad simulator.
3. Press **Run**.

No environment variables or third-party packages are required. Notification and device-authentication prompts appear only after the related feature is enabled.

## Test on macOS

Use **Product > Test** in Xcode, or run the repository script from Terminal:

```sh
bash scripts/test-ios.sh
```

The script selects an available iPhone simulator dynamically, boots it if needed, and runs unit and UI tests with code signing disabled. Set `RESULT_BUNDLE_PATH` to choose the `.xcresult` location:

```sh
RESULT_BUNDLE_PATH="$PWD/TestResults/RoleReady.xcresult" bash scripts/test-ios.sh
```

The tests cover evidence scoring, job parsing, explainable matching, grounded answer validation, export redaction, persistence integrity, sample data, answer provenance, practice, and important accessibility and end-to-end UI flows.

## Verify on Windows

Xcode, the iOS SDK, SwiftUI, and Simulator are unavailable on Windows, so a Windows machine cannot compile or execute this app. It can still run dependency-free repository checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-windows.ps1
```

These checks validate required files, project/configuration invariants, asset metadata, the seven-model schema declaration, and key privacy/navigation wiring. A clean Windows result is not a substitute for the macOS build-and-test gate. See [docs/QA.md](docs/QA.md).

## Privacy and export

RoleReady has no analytics SDK, advertising identifier, remote account, cloud dependency, embedded secret, or network permission. The app shell is marked privacy-sensitive, and App Lock uses iOS device-owner authentication so biometric data never enters the app.

The default reduced-sensitivity export includes Standard and Private stories. It omits Confidential and Highly sensitive stories, answers and practice sessions derived from omitted stories, full job-ad source text, private role notes, and all interview reflections. A separate explicit option includes the complete dataset.

Export creates a versioned JSON data file for portability and review. This release does **not** import or restore that file, so export should not be described as an in-app backup-and-restore mechanism.

## Repository layout

```text
RoleReady/              app target
  App/                  root wiring and navigation
  DesignSystem/         semantic tokens and reusable components
  Models/               SwiftData entities and domain enums
  Services/             parsing, matching, generation, security, export
  Features/             product screens grouped by journey
RoleReadyTests/         domain and persistence unit tests
RoleReadyUITests/       critical-flow UI tests
docs/                   product, architecture, privacy, and QA notes
scripts/                Windows verification and macOS test entry points
```
