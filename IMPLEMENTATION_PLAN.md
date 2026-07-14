# RoleReady implementation plan

## Product outcome

Make RoleReady an all-encompassing, private career workspace that turns one approved career record into strong résumés, job-specific applications, cover letters and interview preparation without inventing claims.

## Implemented direction

- Five connected destinations: **Today**, **Résumés**, **Jobs**, **Interview** and **Career**.
- PDF, `.docx`, RTF and text import with explicit review before extracted facts become approved evidence.
- A reusable career profile with sources, source spans, work, education, certifications, skills and examples.
- Multiple editable résumé versions, truthful job-specific tailoring, ATS-safe selectable-text PDF preview/export and share-sheet delivery.
- Grounded cover letters with editable sections, targeted regeneration, warnings and an evidence trail.
- A private application tracker with status history, notes, contacts, interview handoff and user-created local reminders.
- Provider-neutral generation: deterministic local baseline, Apple Foundation Models when available, gated open-weight infrastructure and a disabled premium-cloud boundary.
- Version 3 workspace backup and preview-first add-only restore, with backward compatibility for versions 1 and 2.

## Trust decisions

- Imported content is a draft until the user approves it.
- Every factual output is limited by approved evidence; irrelevant records are omitted instead of used as filler.
- Match classifications are Direct, Transferable, Weak or partial, and No verified evidence rather than a misleading hiring percentage.
- Deterministic application policy owns privacy, source selection, claim validation, approval, export and restore even when a language model proposes wording.
- No model or provider credential is embedded. The free mode is useful with zero download and zero per-token cost.
- Local open-weight models are optional experiments, not “unlimited free infrastructure”; storage, memory, battery, heat, runtime security and licence terms remain real costs.

## Release gate completed in this implementation pass

- Swift 6 build with complete strict concurrency and warnings-as-errors.
- 103 unit tests passed across ingestion, persistence, matching, grounding, résumé and cover-letter generation, AI routing/evaluation, export and restore.
- The complete nine-scenario UI suite passed, plus focused résumé, application, story-capture and cover-letter-grounding journeys.
- A clean non-test install launched successfully on an iPhone 17 Pro Simulator running iOS 26.2.
- No third-party package, API key, model weight or cloud dependency was added.

## Remaining release work

- Run App Lock, notifications, background privacy shielding and Apple Foundation Models on supported physical iPhones.
- Benchmark one exact quantised Qwen artifact and the Gemma comparison on device before exposing a download.
- Complete legal review and explicit licence acceptance before distributing any third-party model weights.
- Add a secure metered backend before enabling premium cloud models.
- Complete VoiceOver, Reduce Motion, compact-iPhone, iPad split-view, near-limit document and signed App Store archive checks.
- Consider native `.docx` output, account-based sync and email delivery only after the local product is stable.
