# Architecture decisions

## Local-first boundary

RoleReady intentionally replaces a remote backend and account system with a device-owned application service layer and SwiftData store. This removes credentials, breach surface, subscription dependencies, and AI data transfer from the critical path. Device-owner authentication provides the security boundary when App Lock is enabled.

The architecture leaves network intelligence replaceable: `GroundedAnswerEngine`, `JobParser`, and `EvidenceMatcher` expose deterministic inputs and outputs. A future server-backed implementation can conform to the same service boundaries, but no remote dependency is required for a complete product today.

## Data flow

```text
Capture/import → normalise → score evidence → store
Job text → extract requirements → rank evidence → explain factors
Question + approved evidence → compose formats → validate claims → save provenance
```

## Persistence

SwiftData owns six compact entities: career profile, experience, opportunity, requirement, generated answer, and practice session. Cross-feature references are stable UUIDs. Enums are stored as raw strings and collections as encoded strings to keep schema evolution predictable.

## Reliability

- Parsing and generation never mutate the database implicitly.
- Destructive actions require a confirmation dialog.
- First-run sample insertion is idempotent.
- Export uses a versioned Codable envelope and explicit confidentiality filtering.
- Notification scheduling failures are surfaced locally and never block saving a role.

## Security

- App Lock calls `deviceOwnerAuthentication`, allowing biometrics or the device passcode.
- The privacy shield covers app content when the scene becomes inactive.
- Confidential content is marked `.privacySensitive()` and omitted from exports unless explicitly included.
- There are no embedded secrets, analytics SDKs, third-party trackers, or network permissions.

