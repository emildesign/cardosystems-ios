# Device Connectivity SDK — iOS

A small iOS SDK that simulates a connection to a remote device, with a sample app that exercises the public API. No real Bluetooth or hardware is required — the transport layer is a mock.

---

## How to Build and Run

**Requirements:** Xcode 14.2, iOS 16.2 simulator or device.
Note: not tested on newer versions of Xcode or iOS.

1. Open `DeviceConnectivity.xcworkspace` (not the `.xcodeproj` directly).
2. Select the `Demo` scheme.
3. Pick a simulator and press ▶.

To run tests: select the `DeviceConnectivitySDK` scheme and press `⌘U`.

---

## API Evolution and Backward Compatibility

The public surface is intentionally small: one protocol, two publishers, and four methods. This makes evolution manageable.

**Non-breaking changes (safe to ship as minor versions):**
- Adding new methods with default protocol extension implementations.
- Adding new `ConnectionState` cases — consumers using exhaustive `switch` will get a compile warning prompting them to handle it.
- Adding new fields to `DeviceData` with default values.
- Adding new `DisconnectReason` cases.

**Breaking changes (require a major version bump):**
- Removing or renaming existing `ConnectionState` cases.
- Changing the publisher types of `connectionState` or `deviceData`.
- Changing the signature of `connect()`, `disconnect()`, `setVolume()`, or `release()`.

**Strategy:** deprecate before removing. Any method or type marked `@available(*, deprecated)` should survive for at least one minor version before being removed in a major version.

---

## Telemetry and Logging

**Would collect:**
- State transition events with timestamps (e.g. connecting started, connected, failed + reason).
- Transport error types and frequency.
- SDK version and iOS version.
- Command latency — time between `setVolume()` call and transport acknowledgment.

**Would intentionally exclude:**
- Device ID — this could identify a specific user's physical hardware and is therefore PII.
- Volume levels — user behavior data that the consumer may consider private.
- Battery levels — device health data that belongs to the device owner, not the SDK.
- Any content from `DeviceData` payloads.

The rule is simple: log what helps debug the SDK, never log what the user is doing or what device they own.

---

## Testing Strategy

Tests focus on the **SDK core only** — state machine transitions, error cases, and no-op guards. The sample app is a test harness, not a product, so UI tests were not written.

**What is tested:**
- All state machine transitions (idle → connecting → connected, timeout, unexpected disconnect, consumer disconnect).
- `deviceData` updates on connected state, and clearing on disconnect.
- `setVolume()` returns failure when not connected.
- `connect()` is a no-op when already connecting or connected.
- `release()` cancels internal tasks so future transport events are ignored.
- Reconnect after a failed state.
- Multiple concurrent `setVolume()` commands are processed sequentially.

**What is not tested:**
- SwiftUI views — low risk, manually verified.
- ViewModel — thin layer with no logic of its own; tested indirectly through the SDK tests.
- Mock transport timing — non-deterministic delays are not unit tested; only the scenario outcomes are verified.

**Tools:**
- `XCTest` — no external dependencies required.
- `FakeTransport` — a hand-rolled test double in its own file (`FakeTransport.swift`), giving full control over emitted `AsyncStream` events without timing dependencies.

A hand-rolled fake was chosen over a mock framework because it makes the test intent clearer and avoids timing dependencies.

---

## Distribution

### Current approach — private GitHub repository (internal use)

The SDK is consumed as a local framework dependency within the workspace. This is the right choice while the SDK is for internal use only.

**Why:** Setting up Swift Package Manager on a public repo requires committing to a stable public API, semantic versioning enforcement, and CI that validates the package builds cleanly for all consumers. This overhead is not justified for an internal SDK.

**Implications of staying private:**
- Consumers must have access to the GitHub org.
- No versioning enforcement — consumers can reference a branch instead of a tagged release.
- No discovery — other teams can't find the SDK unless told about it.

### If the SDK goes public — Swift Package Manager

```swift
.package(url: "https://github.com/emildesign/cardosystems-ios", from: "1.0.0")
```

**Implications on API surface and versioning:**
- Semantic versioning becomes a hard contract. A breaking change to the public API surface requires a major version bump (2.0.0).
- The `internal` keyword becomes critical — anything accidentally made `public` becomes part of the API contract and is hard to remove without a breaking change. Note: on iOS `MockDeviceTransport` is `public` because Swift's module system requires explicit visibility. It should be moved to a separate `DeviceConnectivitySDKTesting` target so it does not ship in the production SDK but remains available for consumer UI tests.
- Use [swift-api-digester](https://github.com/apple/swift/blob/main/docs/APIDigester.md) in CI to catch unintentional public API changes.
