# Local AI evaluation

Last updated: 15 July 2026

RoleReady does not treat “free model weights” as unlimited free infrastructure. A local model avoids per-token API charges, but it still consumes the user’s storage, memory, battery and time. The app therefore keeps a zero-download deterministic provider as the universal baseline and uses Apple’s on-device model automatically when it is available.

## Repeatable harness

`AIEvaluationHarness` runs synthetic, non-personal fixtures for:

- résumé field extraction;
- job-requirement extraction;
- grounded interview-answer generation;
- unsupported-clause detection; and
- ownership escalation.

Each provider is evaluated behind the same `RoleReadyLanguageService` boundary. The report records successful structured cases, task scores, latency, unsupported claims and fields reserved for physical-device memory, download, battery, thermal and crash measurements.

## Current measured baseline

Environment: iPhone 17 Pro Simulator, iOS 26.2, Debug build.

| Provider | Cases | Extraction recall | Requirement recall | Supported answer clauses | Ownership safety | Network |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| RoleReady deterministic | 3/3 | 4/4 | 3/3 | 100% | Pass | None |

The XCTest covering the harness completed in 0.043 seconds. Simulator timing is a regression signal, not a physical-device performance claim.

Apple Foundation Models cannot be meaningfully benchmarked in Simulator because the system model is unavailable there. The integration is compiled and availability-gated for iOS 26+. On a supported physical device, Apple output is treated as a suggestion: RoleReady reconciles every changed clause with approved evidence and blocks approval for unsupported wording.

## Open-weight candidates

### Qwen3.5-2B

Qwen’s official model card identifies a two-billion-parameter model under Apache 2.0 and describes the 2B release as intended for prototyping and task-specific development. It is the first downloadable-model candidate because its size is more plausible for optional four-bit on-device use than the larger alternatives.

It is not selected for production yet. RoleReady still needs one exact iOS-compatible quantised artifact, an audited runtime, an exact byte count and checksum, then physical-device measurements for memory pressure, long-input stability, battery, heat and crash recovery.

### Gemma 3n E2B

Google describes Gemma 3n as device-optimised, but also documents that standard E2B execution loads more than five billion total parameters before effective-parameter techniques reduce active memory. It remains a valuable comparison, not an automatic winner. Its separate terms also require an explicit licence decision before RoleReady downloads or redistributes weights.

### Llama and DeepSeek

They are not first-round device candidates. Llama’s small models use Meta’s community licence rather than Apache 2.0, while current flagship DeepSeek models are too large for this iOS use case. Small distilled variants can be reconsidered only if they outperform Qwen and Gemma on RoleReady’s factual-grounding fixtures.

## Current decision

1. Use deterministic local extraction, matching, validation, tailoring and cover-letter generation on every supported device.
2. Use Apple Foundation Models for optional on-device language refinement when the system reports the model available.
3. Keep Qwen3.5-2B as the first downloadable-model experiment, but do not make it an app dependency or expose a fake download button before an artifact and runtime pass the harness.
4. Keep Gemma 3n E2B as the comparison candidate pending licence acceptance and device measurements.
5. Keep premium GPT-5.6 access behind a future secure backend. No OpenAI or other provider key is embedded in the app, and cloud transmission requires explicit per-request consent.

## Required physical-device run before a downloadable model ships

- cold and warm latency for every fixture;
- peak resident memory and memory-warning recovery;
- exact compressed and installed size;
- ten consecutive long résumé and job-description runs;
- foreground and background cancellation;
- battery change and thermal state during a 15-minute workload;
- corrupted and interrupted download recovery;
- checksum rejection;
- model deletion and deterministic fallback; and
- the same unsupported-claim and ownership thresholds as the baseline.

## Sources used for candidate facts

- [Apple Foundation Models](https://developer.apple.com/documentation/FoundationModels)
- [Qwen3.5-2B official model card](https://huggingface.co/Qwen/Qwen3.5-2B)
- [Gemma 3n model overview](https://ai.google.dev/gemma/docs/gemma-3n)
- [OpenAI model catalogue](https://developers.openai.com/api/docs/models/all)
