# Architecture decisions

## Local-first boundary

RoleReady intentionally replaces a remote backend and account system with a device-owned application service layer and SwiftData store. This removes credentials, remote breach surface, subscription dependencies, and career-data transfer from the critical path. Device-owner authentication provides an additional local security boundary when App Lock is enabled.

The intelligence layer remains replaceable: `GroundedAnswerEngine`, `JobParser`, and `EvidenceMatcher` expose deterministic inputs and outputs. A future server-backed implementation could sit behind equivalent service boundaries, but no remote dependency is required for the complete current product.

## Data flow

```text
Capture/import -> normalise -> score evidence -> store
Job text -> extract editable requirements -> rank evidence -> explain factors and gaps
Question + selected evidence -> compose formats -> validate claims -> save provenance
Saved answers -> pre-interview practice -> confidence record -> post-interview reflection
```

## Persistence

SwiftData owns seven models:

1. `CareerProfile`
2. `Experience`
3. `Opportunity`
4. `JobRequirement`
5. `GeneratedAnswer`
6. `PracticeSession`
7. `InterviewReflection`

Cross-feature references use stable UUIDs. Enums are persisted as raw strings, and collections are encoded into scalar storage where needed, keeping the schema explicit and migrations predictable. Deletion paths repair or remove dependent UUID references so an experience or opportunity cannot leave misleading derived records behind.

## Application structure

- `App` owns the four-tab shell, navigation routes, app-lock state, lifecycle privacy shield, and model container.
- `Features` groups screens around Today, Evidence, Roles, Practise, onboarding, and secondary profile/settings destinations.
- `Models` contains the seven SwiftData entities and shared domain types.
- `Services` contains parsing, scoring, matching, answer generation and validation, provenance approval, import, export, reminders, haptics, and device authentication.
- `DesignSystem` provides semantic colour, typography, spacing, surfaces, and accessible reusable controls.

The Xcode project uses filesystem-synchronised source groups. The checked-in project and `project.yml` both select Swift 6, complete strict concurrency checking, and warnings-as-errors so local and CI builds use the same language safety gate.

## Reliability

- Parsing and generation never mutate the database implicitly.
- Saved answers retain source fields, source claims, experience revision, and role-content revision.
- Editing source material invalidates stale fact confirmation rather than silently presenting it as current.
- Destructive actions require confirmation, and persistence failures roll back where the model context can recover.
- First-run sample insertion is idempotent and sample removal cleans related records.
- Export uses a versioned Codable envelope and explicit confidentiality filtering.
- Interview-reminder failures are surfaced locally and never block saving a role.

## Security and privacy

- App Lock calls the device-owner authentication policy, allowing biometrics or device passcode without exposing credentials to RoleReady.
- The lifecycle privacy shield covers content when the scene becomes inactive.
- The entire `AppShell` is marked `.privacySensitive()`, so all tab content inherits protected treatment in supported system surfaces; especially sensitive practice content also marks itself directly.
- The default export omits Confidential and Highly sensitive stories, their derived answers and practice sessions, full job-ad source text, private role notes, and every interview reflection.
- There are no embedded secrets, analytics SDKs, third-party trackers, accounts, network clients, or remote permissions.

## Platform and validation boundary

The deployment target is iOS 18. Xcode 26 is the release toolchain. Windows can perform repository and configuration checks only; compilation, Swift concurrency diagnostics, SwiftData macro expansion, UI tests, and Simulator validation require macOS with Xcode and are enforced by `scripts/test-ios.sh` and the macOS CI workflow.
