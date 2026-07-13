# Quality assurance and release gate

## Validation layers

RoleReady uses two complementary gates:

1. `scripts/verify-windows.ps1` performs dependency-free repository checks on Windows. It validates required files, checked-in Swift/Xcode settings, target folders, asset metadata, the seven-model declaration, four-tab wiring, and global privacy-sensitive coverage.
2. `scripts/test-ios.sh` runs the complete Xcode unit and UI test plans on a dynamically selected iPhone Simulator with code signing disabled. This is the authoritative build, Swift 6 concurrency, warnings-as-errors, resource, launch, and interaction gate.

The GitHub Actions workflow in `.github/workflows/ios.yml` runs the macOS gate on `macos-26`, prints the selected Xcode version for traceability, and uploads the `.xcresult` bundle whether tests pass or fail.

## Local commands

Windows repository checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\verify-windows.ps1
```

macOS build and test:

```sh
bash scripts/test-ios.sh
```

Direct Xcode equivalent, after choosing a valid simulator identifier:

```sh
xcodebuild test \
  -project RoleReady.xcodeproj \
  -scheme RoleReady \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UUID>' \
  -resultBundlePath TestResults/RoleReady.xcresult \
  CODE_SIGNING_ALLOWED=NO
```

## Test scope

The checked-in suites cover:

- evidence scoring, parser behaviour, and explainable evidence matching;
- grounded answer formats, claim validation, source provenance, and approval freshness;
- export versioning, confidentiality redaction, practice-session provenance, and reflection scope;
- SwiftData seed integrity, sample removal, preferences reset, and dependent-record cleanup;
- onboarding, evidence capture, role analysis, requirement-to-answer flow, saved-answer reopening, pre-interview practice, and large Dynamic Type behaviour.

## Release checklist

- [ ] Windows repository verification passes.
- [ ] `xcodebuild test` passes on Xcode 26 with no warnings.
- [ ] The app launches on an iOS 18 Simulator and the four primary tabs render.
- [ ] Onboarding works with and without sample data.
- [ ] Paste/import role analysis, match report, grounded answer, save/reopen, and practice flows pass.
- [ ] App Lock cancellation, background privacy shield, reduced-sensitivity export, full export, and complete deletion are verified on a physical device where applicable.
- [ ] VoiceOver, extra-extra-extra-large accessibility text, Reduce Motion, dark mode, and high-contrast appearance receive a final manual pass.
- [ ] A distribution build is signed with the intended Apple Developer team and App Store privacy/notification disclosures are reviewed by the publisher.

## Current environment limitation

The repository was assembled in a Windows environment. Windows cannot run Xcode, expand Swift macros, compile SwiftUI, execute the iOS Simulator, or validate Apple code signing. Passing `verify-windows.ps1` therefore confirms repository consistency only. A passing macOS/Xcode 26 test run remains mandatory before TestFlight or App Store distribution.
