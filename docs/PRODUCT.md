# Product brief

## Purpose

RoleReady is a private career workspace. It helps people turn things they have genuinely done into strong résumés, truthful job applications, cover letters and concise interview answers, then verify, track and practise them.

The problem is not a lack of generic writing tools. Applicants often have useful experience scattered through résumés, old applications, project notes, and memory; struggle to select the strongest example for a requirement; and cannot easily tell whether generated wording has overstated their ownership or invented a result. RoleReady connects selection, clarification, writing, verification, and rehearsal in one local workflow.

The core promise is:

> **Improve expression without inventing experience.**

## Initial audience

RoleReady is designed first for:

- Australian APS and state-government applicants;
- existing public servants applying for promotion;
- professionals preparing for behavioural interviews;
- applicants answering targeted questions, capability frameworks, and selection criteria; and
- privacy-conscious professionals handling confidential or regulated career information.

The evidence and STAR workflow remains broadly useful for students, career changers, private-sector professionals, volunteers, and people returning to work.

## Why use RoleReady

Compared with a generic chatbot or document template, RoleReady:

- uses a reusable library of the user's real examples instead of an unstructured chat history;
- marks imported résumé material as unverified until the user reviews it;
- distinguishes a direct match from transferable, partial, or absent evidence;
- links answer clauses to the source details supporting them;
- deterministically checks numbers, ownership, unsupported edits, and format limits before approval;
- remains useful offline without an API key or account; and
- carries the same approved evidence from résumé to application, cover letter and focused pre-interview rehearsal.

## Primary outcomes

A new user should be able to import an existing résumé, approve the useful facts and produce a clean baseline résumé without re-entering their career. For a saved job, they should be able to produce one truthful tailored version, a grounded cover letter and one approved role-specific answer without maintaining separate copies of their history.

The first-use path is:

```text
Understand trust and privacy
-> import or paste career history, or describe one example
-> review an unverified draft
-> import or paste a job advertisement
-> review requirement themes
-> inspect an honest example recommendation
-> answer only important missing-detail prompts
-> generate a grounded answer
-> inspect the supporting evidence
-> edit and approve safely
-> practise from short cues
-> retain the example and answer for future roles
```

## Information architecture

- **Today** — next actions, active applications, readiness and shortcuts.
- **Résumés** — source import, approved facts, version management, tailoring and PDF export.
- **Jobs** — saved opportunities, match reports, application materials, progress and reminders.
- **Interview** — approved answers, timed rehearsal, memory cues, likely follow-ups and confidence records.
- **Career** — reusable work, education, skills, certifications, sources and examples.

Profile, Insights, Privacy, Settings and post-interview reflections remain secondary destinations.

## Core capabilities

### Career-history ingestion

Users can import PDF, `.docx`, RTF, or plain text; paste résumé or rough career notes; use an existing approved example; or start with one manual example. Deterministic extraction proposes value-type drafts. These are explicitly unverified and can be edited, combined, rejected, or confirmed. Only a reviewed draft selected by the user is approved for automatic matching in the guided flow; other imported drafts remain unapproved.

### Progressive example capture

The guided path asks plain-language questions only when the answer would materially improve the story: what happened, what the user was responsible for, what they personally did, why they chose the approach, what changed, how they know, and what they learnt. The full evidence model remains available through advanced editing.

### Résumé building and tailoring

The approved career workspace is the source of truth for multiple résumé versions. Users can edit wording, reorder sections, duplicate or archive versions, select a technical or general template, and preview or share an ATS-safe selectable-text PDF. A job-specific version ranks approved evidence against confirmed requirements and exposes direct evidence, transferable evidence and honest gaps; it does not add unsupported keywords or accomplishments.

### Cover letters and application tracking

Cover letters use only approved evidence with a verified connection to the job. Users can edit the full draft, regenerate individual sections, inspect the evidence trail and keep a shorter honest letter when the profile lacks enough proof for filler-free target length. Each job also has a private workspace for status, contacts, notes, activity, reminders, tailored résumés and interview handoff.

### Role analysis and matching

Role text is grouped into editable requirement themes. Matching requires relevant verified evidence and reports one of four tiers:

- **Direct evidence** — specific, verified detail closely demonstrates the requirement.
- **Transferable evidence** — credible evidence demonstrates the capability in another context.
- **Weak or partial evidence** — some connection exists, but important proof is missing.
- **No verified evidence** — RoleReady cannot make an honest recommendation from the current library.

The primary UI avoids percentage scores that could be mistaken for hiring probability. A secondary “Why this example?” explanation exposes useful reasoning and gaps.

### Grounded answer creation

The default spoken output targets an approximately 60-second STAR answer of 105–145 words. Written STAR, selection-criteria, and targeted-question responses are central outputs; shorter cues, other spoken lengths, résumé bullets, and cover-letter material remain available where useful. Generation uses only the selected example and allowed question or role context, then enforces the selected format's actual word-count range and estimates speaking time at 130 words per minute.

### Source review and approval

Generated clauses retain source field, source text, origin, and support status. When content is materially edited, RoleReady reconciles the clauses again. Unsupported additions—including new numbers or stronger ownership—are marked as needing a source and cannot be approved. Connecting a clause to a field triggers validation; it does not automatically make the clause true.

Approval is an application decision, not a model opinion. It requires non-empty source claims, no unsupported clause, no blocking factual warning, and compliance with the selected format's word range. Changes to an approved source example or linked role invalidate the existing approval.

### Practice

Approved answers move directly into rehearsal with the interview question, three to five memory cues, a timer, optional full-answer reveal, confidence rating, likely follow-up questions, and a route back to strengthen the evidence. Practice is deliberately before the interview; there is no live listening, covert prompting, emotion inference, or personality scoring.

### Export and restore

The user can create a reduced-sensitivity or complete version 3 JSON archive. Restore accepts version 1, 2 and 3 exports, validates a maximum 20 MB file, previews importable records, duplicates, rejected dependencies and sensitivity warnings, then requires explicit confirmation. It is add-only, skips UUID duplicates, rejects cyclic résumé ancestry, never deletes local records and rolls back a failed import. Version 1 answers restore as unapproved drafts because their provenance state cannot be established safely.

## Product boundaries

RoleReady is not:

- a generic AI chatbot;
- a recruiter-facing CRM, browser job scraper, job board, or social network;
- a decorative résumé-layout marketplace;
- covert or real-time interview assistance; or
- a system that invents achievements, ownership, tools, organisations, or metrics.

The shipped product has no cloud provider, analytics, third-party tracking, account, backend, or synchronisation. Optional future language providers must remain behind the provider-neutral boundary and an explicit privacy design; deterministic policy remains authoritative.

## Success criteria

- A first-time user can reach one grounded, approved answer and its practice cues in roughly five minutes with realistic inputs.
- Imported career examples never appear as verified until the user confirms them.
- A lexical overlap without relevant evidence cannot produce a direct or transferable match.
- No approved answer contains a number, ownership statement, tool, organisation, action, or outcome that cannot be traced to supplied evidence or allowed question context.
- Material edits revoke support and approval until they are revalidated.
- The default interview answer meets its real word-count range and presents a credible speaking-duration estimate.
- Users can export, restore, or permanently delete their local data without contacting support.
- The complete core journey remains useful with no network, account, API key, or language model.

## Known limitations

- Deterministic résumé extraction works best with text-led documents and may split or group complex layouts imperfectly.
- Deterministic requirement grouping can miss implicit or unusually formatted criteria; every theme remains editable.
- Automatic AI uses Apple Foundation Models on supported iOS 26+ devices and otherwise falls back to the deterministic local provider. Every generated clause still passes RoleReady’s local grounding and approval rules.
- Optional open-weight and premium-cloud boundaries are implemented, but no model weights or provider credentials are bundled. A downloadable model is not exposed until its exact artifact passes the documented device evaluation and licence gate.
- Restore is an add-only UUID-based process rather than a semantic, field-by-field merge.
- There is no cross-device sync or collaborative workspace.
