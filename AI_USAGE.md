# AI Usage

## Tools Used

- **Claude (Anthropic)** — used throughout as a pair programmer for architecture design, code generation, and documentation.
- **Google Gemini (Android Studio inline)** — used for inline code suggestions and quick fixes.
- **OpenAI Codex** — used for inline code suggestions during development.

---

## What I Reviewed, Kept, or Rejected

I treated Claude as a first draft generator — everything it produced was read carefully before being added to the project. Nothing was accepted without being understood first.

**Kept after review:**
- The overall state machine design and the protocol pattern for the public API surface.
- The transport layer structure — `DeviceTransport` as an internal protocol with `MockDeviceTransport` as the implementation.
- The `FakeTransport` test double pattern (hand-rolled, not a mock framework).
- `DeviceData` as a single bundled struct, accepting the v2 trade-off documented in DESIGN.md.

**Modified after review:**
- `@MainActor` isolation required several iterations — Claude's initial suggestions for the factory method caused compiler errors (`Static member cannot be used on protocol metatype`), which needed a different approach (free function `makeDeviceConnector()`).
- `AsyncStream` single-consumer limitation required a redesign — `FakeTransport` and `MockDeviceTransport` were updated to create a fresh stream per `connect()` call to support reconnect scenarios.
- Several files had access modifier issues (`public` vs `internal`) that needed correction after review.
- Removed unnecessary `AnyObject` constraint from `DeviceConnector` and `DeviceTransport` protocols.

**Rejected:**
- Claude suggested using `callbackFlow` for the transport — rejected in favour of `AsyncStream` which is a better fit for a producer that lives longer than a single collection.
- Some over-engineered abstractions in early drafts that added layers without adding value.

---

## Where AI Fell Short

**Xcode project setup:**
Claude could not reliably generate a working `.xcodeproj` / `.xcworkspace` from scratch. Multiple attempts produced projects that either failed to open, failed to resolve the SDK framework dependency, or had malformed `project.pbxproj` files with UUID or syntax errors. This had to be done manually by creating the projects through Xcode's own wizards and then wiring them together by hand.

**Swift compiler errors:**
Several Swift-specific issues required manual debugging. Claude suggested fixes that were either incorrect or introduced new errors — for example the `@MainActor` propagation issue, the `internal` visibility conflict on `DeviceTransport`, and the `AsyncStream` single-consumer reconnect problem. These were resolved by reading the compiler errors carefully and understanding the root cause rather than accepting Claude's first suggested fix.

---

## How I Verified Correctness

- Read every generated file before adding it to the project. Traced the state machine transitions manually against the diagram in DESIGN.md.
- Built and ran the app on an iOS 16.2 simulator and manually verified all scenarios — connect, disconnect, volume change, battery drain, timeout, and unexpected disconnect.
- Ran all unit tests with `⌘U` in Xcode to confirm they pass.
- Used Gemini and Codex to review the code for improvements after the initial implementation.
- Treated compiler errors and test failures as signals that something was wrong with the design or the AI output, not just noise to suppress.
