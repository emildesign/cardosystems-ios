# AI Usage

## Tools Used

- **Claude (Anthropic)** — used throughout as a pair programmer for architecture design, code generation, and documentation. Primary tool for thinking through design decisions, generating implementation drafts, and writing all three markdown documents.
- **Google Gemini (Android Studio inline)** — used for inline code suggestions and quick fixes while writing Android code directly in the IDE.
- **OpenAI Codex** — used for inline code suggestions during development.

---

## Where AI Helped

| Area | How it helped |
|---|---|
| Architecture & design | Used Claude to think through the state model, concurrency model, and error model. Claude presented options and trade-offs, I made the final decisions on each |
| Code generation | Claude generated first drafts of all SDK and sample app files for both platforms |
| Compiler error fixes | Gemini (Android Studio) and Claude helped diagnose and suggest fixes for build and compiler errors |
| Documentation | Claude drafted all three markdown files based on my answers to structured questions |

---

## What I Reviewed, Kept, or Rejected

I treated Claude as a first draft generator — everything it produced was read carefully before being added to the project. Nothing was accepted without being understood first.

**Kept after review:**
- The overall state machine design and the protocol/interface pattern for the public API surface.
- The transport layer structure — `DeviceTransport` as an internal interface with `MockDeviceTransport` as the implementation.
- The `FakeTransport` test double pattern (hand-rolled, not a mock framework) for unit tests.
- The `DeviceData` as a single bundled type, accepting the v2 trade-off documented in DESIGN.md.

**Modified after review:**
- iOS `@MainActor` isolation required several iterations — Claude's initial suggestions for the factory method caused compiler errors (`Static member cannot be used on protocol metatype`), which needed a different approach (free function `makeDeviceConnector()`).
- Android coroutine scope management — adjusted the `SupervisorJob` setup after reviewing how scope cancellation interacts with `release()`.
- Several files had access modifier issues (`public` vs `internal`) that needed correction after review.

**Rejected:**
- Claude suggested a `DeviceConnectorFactory` class on Android — rejected in favour of a simple `companion object` factory method which is more idiomatic Kotlin.
- Claude initially suggested `callbackFlow` for the iOS transport — rejected in favour of `AsyncStream` which is a better fit for a producer that lives longer than a single collection.
- Some over-engineered abstractions in early drafts that added layers without adding value.

---

## Where AI Fell Short

**Android — project configuration:**
The first generated Android project had multiple errors in the Gradle configuration and module setup. The build scripts had wrong dependency versions, incorrect module references, and missing configurations. These were fixed using Gemini inside Android Studio, which has better awareness of the local project context than a chat-based AI.

**iOS — Xcode project setup:**
Claude could not reliably generate a working `.xcodeproj` / `.xcworkspace` from scratch. Multiple attempts produced projects that either failed to open, failed to resolve the SDK framework dependency, or had malformed `project.pbxproj` files with UUID or syntax errors. This had to be done manually by creating the projects through Xcode's own wizards and then wiring them together by hand.

**iOS — Swift compiler errors:**
Several Swift-specific issues required manual debugging. Claude suggested fixes that were either incorrect or introduced new errors — for example, the `@MainActor` propagation issue and the `internal` visibility conflict on `DeviceTransport`. These were resolved by reading the compiler errors carefully and understanding the root cause rather than accepting Claude's first suggested fix.

---

## How I Verified Correctness

- **Read every generated file** before adding it to the project. Traced the state machine transitions manually against the diagram in DESIGN.md to confirm the implementation matched the design.
- **Built and ran the app** on a real simulator (iOS) and emulator (Android) and manually verified all scenarios — connect, disconnect, volume change, battery drain, timeout, and unexpected disconnect.
- **Reviewed with additional AI agents** — after the initial implementation, used Gemini and Codex to review the code for improvements, catching issues that Claude missed and validating that the overall approach was sound.
- **Compiler as a verification tool** — treated compiler errors as a signal that something was wrong with the design or the AI output, not just as noise to suppress.
