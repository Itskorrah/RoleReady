# Privacy summary

RoleReady processes career history, job advertisements, evidence matching, answer generation, practice, and interview reflections on the user's device. The shipped application does not create an account, send content to a RoleReady server, sell data, include advertising or analytics SDKs, or require a network connection.

The current language provider is deterministic and local. The codebase defines extension points for a future Apple on-device or optional cloud provider, but neither is implemented or enabled. Adding a provider that transmits data would require an explicit privacy design and user-facing disclosure; it must not silently change the local-first default.

## What is stored

SwiftData stores the user's profile, reviewed examples, saved roles and requirement themes, generated answers and source-claim metadata, practice sessions, and interview reflections in the app's local container.

Career documents are read only after the user selects them through the system file importer. Career-history extraction produces temporary unverified drafts; RoleReady persists the reviewed example records the user chooses to save, not the original résumé file. Saved opportunities may retain the imported or pasted job-ad text. Imported documents and restore files are capped at 20 MB; imported text is capped at 250,000 characters.

The app target contains no `print`, `Logger`, analytics, or crash-reporting path that writes user career content. Tests use synthetic fixtures rather than real user data.

## Confidentiality levels

Every example has one of four user-controlled levels:

- **Standard** — ordinary career evidence.
- **Private** — personally sensitive evidence that remains eligible for the default export.
- **Confidential** — omitted from the default reduced-sensitivity export and accompanied by use cautions.
- **Highly sensitive** — omitted from the default reduced-sensitivity export and always excluded from automatic evidence matching. Explicit answer use requires the user's matching/use approval.

Changing an example's details or confidentiality can invalidate approval for answers that depend on it. RoleReady never treats imported résumé text as verified simply because it was found in a document.

## Reduced-sensitivity and complete exports

The default reduced-sensitivity version 2 JSON export includes Standard and Private examples. It excludes:

- Confidential and Highly sensitive examples;
- generated answers linked to excluded examples;
- practice sessions linked to excluded answers;
- complete job-advertisement source text;
- private role notes; and
- all interview reflections.

Role metadata and confirmed requirements remain included so the reduced export is still useful. A separate explicit complete-export action includes all four example levels, full opportunity text and notes, derived answers and practice sessions, and reflections.

Export is initiated by the user. RoleReady writes the temporary JSON file atomically with complete file protection where the platform supports it, removes leftover RoleReady temporary exports at startup and after relevant cleanup, then hands sharing or saving to the system. Once an export leaves the protected app container, the user or destination app controls its security. A complete export can contain highly sensitive career information and should be handled accordingly.

## Safe restore

Settings can restore RoleReady version 1 or version 2 JSON exports up to 20 MB. Before any mutation, RoleReady checks the format identifier and version, validates record types and dependencies, detects duplicate UUIDs, identifies invalid records, checks confidentiality metadata, and revalidates whether saved answers still deserve approval. The preview shows records to add, duplicates to skip, records to reject, and sensitivity or migration warnings. The user must explicitly confirm.

Restore is add-only:

- it never deletes the current workspace;
- an existing UUID is retained and the imported duplicate is skipped;
- entered profile information is never replaced;
- a single genuinely empty, non-sample starter profile may be filled from the archive;
- valid independent records can restore while invalid dependent records are skipped; and
- a save failure rolls back the restore context.

Legacy version 1 answers restore as drafts because the older format cannot prove whether edited clauses still match their sources. Highly sensitive version 1 examples return disabled for automatic matching unless their historical metadata explicitly supports use, and the matcher still excludes them from automatic recommendations.

Restoring a file necessarily copies its contents into the local workspace. A sensitivity warning is not proof that the file is safe or authentic; users should restore only exports they trust.

## Answer grounding and approval

Saved factual clauses retain their source field, source text, origin, and support status. Material edits are rechecked locally. Unsupported numbers, stronger ownership, or wording that cannot be linked to supplied evidence are marked as needing a source and block approval. Connecting a source lets RoleReady validate a clause; it does not assert that an unsupported addition is true.

The application, not a language model, decides whether an answer may be approved. An approved answer becomes stale when its linked example or role content changes.

## Device protection

If App Lock is enabled, authentication is performed by iOS using device-owner authentication. RoleReady receives only success or failure; Face ID, Touch ID, and passcode data remain under operating-system control.

The app covers its interface whenever it becomes inactive and marks the complete app shell as privacy-sensitive for supported system surfaces. Users can remove the sample workspace independently, delete all local data from Settings, cancel scheduled reminders, and disable App Lock at any time.

Complete deletion removes all seven SwiftData record types, RoleReady preference flags, scheduled reminders, and RoleReady temporary export files. Files the user previously saved or shared outside the app's container are outside RoleReady's control and must be deleted from their destination separately.

iOS may include RoleReady data in an encrypted device backup according to the user's system settings. RoleReady does not run a separate cloud-backup service, and deleting local app data cannot remove backups the operating system created earlier.

## Notifications

Notification permission is requested only when the user enables an interview reminder. Reminders are local notifications for upcoming interviews. RoleReady does not use push notifications or schedule closing-date reminders.
