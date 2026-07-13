# Privacy summary

RoleReady processes career history, job descriptions, matching, answer generation, practice, and interview reflections on the user's device. It does not create an account, send content to a RoleReady server, sell data, include advertising or analytics SDKs, or depend on a network connection.

## Confidentiality levels

Every experience has one of four user-controlled levels:

- **Standard** — ordinary career evidence.
- **Private** — personally sensitive evidence that remains eligible for the default export.
- **Confidential** — omitted from the default redacted export.
- **Highly sensitive** — omitted from the default redacted export and blocked from automatic evidence use.

The default reduced-sensitivity JSON export includes Standard and Private experiences. It excludes Confidential and Highly sensitive experiences, generated answers and practice sessions derived from excluded experiences, full job-ad source text, private role notes, and all interview reflections. Role metadata and confirmed requirements remain included so the export is still useful. An explicit full export includes all four experience levels, complete opportunity text and notes, and reflections.

Export is initiated by the user and written with atomic, complete file protection where the platform supports it. Exported files leave the app's protected container when the user shares or saves them and should be handled accordingly.

The JSON format is versioned for portability and inspection, but this app version does not import or restore exports. It is a data export, not an in-app backup-and-restore feature.

## Device protection

If App Lock is enabled, authentication is performed by iOS using device-owner authentication. RoleReady receives only success or failure; Face ID, Touch ID, and passcode data remain under operating-system control.

The app covers its interface when it becomes inactive and marks the complete app shell as privacy-sensitive for supported system surfaces. Users can remove the sample workspace independently, delete all local data from Settings, cancel scheduled reminders, and disable App Lock at any time.

## Notifications

Notification permission is requested only when the user enables an interview reminder. Reminders are local notifications for upcoming interviews; RoleReady does not schedule closing-date reminders or use push notifications.
