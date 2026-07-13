# RoleReady

RoleReady is a privacy-first iOS career preparation app that turns verified work, study, volunteer, and project experience into stronger job applications and interview answers.

The product is deliberately evidence-led: users capture an experience once, strengthen missing parts, match it transparently to a role, and create answer formats whose claims remain traceable to the original story. The core matching and writing pipeline runs on-device and does not require an account, subscription, API key, or network connection.

## Product highlights

- A guided Evidence Bank with STAR structure, ownership prompts, confidentiality controls, and a constructive evidence-strength score.
- Job-description analysis for pasted text and imported PDF, RTF, or plain-text documents.
- Explainable requirement-to-evidence matching, including alternatives and honest gaps.
- Grounded answer generation in quick prompt, 30-second, 60-second, 90-second, written STAR, résumé bullet, and cover-letter formats.
- Interview preparation with likely questions, follow-up prompts, confidence tracking, and a distraction-free interview mode.
- Application pipeline, evidence coverage insights, deadline/interview reminders, JSON export, full deletion, and optional Face ID/passcode app lock.
- A realistic sample workspace for evaluation; it can be removed from Settings at any time.
- Responsive iPhone and iPad layouts, Dynamic Type, VoiceOver labels, Reduce Motion support, dark mode, and iOS 26 Liquid Glass enhancements with iOS 18 fallbacks.

## Architecture

- SwiftUI with the Observation framework for view and navigation state.
- SwiftData for the local database; all career content stays on the device.
- Apple frameworks only: PDFKit, UniformTypeIdentifiers, LocalAuthentication, UserNotifications, and NaturalLanguage.
- Small deterministic domain services for scoring, parsing, matching, generation, export, and reminders. They are independently unit tested and have no UI dependencies.
- A filesystem-synchronised Xcode project, so new source files in each target folder are picked up without editing the project file.

## Run

Requirements: Xcode 26 or newer and an iOS 18+ simulator or device.

1. Open `RoleReady.xcodeproj`.
2. Select the `RoleReady` scheme and any iOS 18+ simulator.
3. Press **Run**.

No environment variables, third-party packages, backend, or credentials are required. Notification and biometric prompts only appear after the related feature is enabled.

## Test

In Xcode, select **Product → Test**, or run:

```sh
xcodebuild test \
  -project RoleReady.xcodeproj \
  -scheme RoleReady \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The test suite covers evidence scoring, job parsing, matching explanations, grounded answer generation, export redaction, and first-run seed integrity. UI tests cover onboarding, adding evidence, analysing a role, and generating an answer.

## Privacy model

RoleReady has no analytics SDK, advertising identifier, remote account, or cloud dependency. Confidential experiences can be excluded from answer generation and exports. App Lock uses the device owner authentication policy, so biometric data never enters the app. Export files are created only after an explicit action and use complete file protection where the platform permits it.

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
```

