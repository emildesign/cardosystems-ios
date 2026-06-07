# Device Connectivity SDK

A small SDK that simulates a connection to a remote device, with a sample app that exercises the public API. No real Bluetooth or hardware is required — the transport layer is a mock.

---

## How to Build and Run

### Android

**Requirements:** Android Studio Hedgehog (2023.1.1) or newer, JDK 17, Android SDK 34.

```bash
git clone <repo-url>
cd cardosystems-android
./gradlew assembleDebug          # build SDK + app
./gradlew :sdk:test              # run unit tests
./gradlew :app:installDebug      # install sample app on device or emulator
```

Or open in Android Studio: `File → Open → select project root`, then run the `app` configuration.

### iOS

**Requirements:** Xcode 14.2 or newer, iOS 16+ simulator or device.

1. Open `DeviceConnectivity.xcworkspace` (not the `.xcodeproj` directly).
2. Select the `Demo` scheme.
3. Pick a simulator and press ▶.

To run tests: select the `DeviceConnectivitySDK` scheme and press `⌘U`.

---

## Project Structure

### Android
```
sdk/                        # Android library module (the SDK)
  src/main/kotlin/com/emildesign/sdk/
    api/DeviceConnector.kt          # Public interface + factory
    DeviceConnectorImpl.kt          # Implementation (internal)
    domain/model/                   # Public types: ConnectionState, DeviceData, DisconnectReason
    data/transport/                 # Internal: DeviceTransport, MockDeviceTransport
    data/transport/model/           # Internal: TransportEvent, DeviceCommand
  src/test/kotlin/com/emildesign/sdk/
    DeviceConnectorTest.kt          # Unit tests
    FakeTransport.kt                # Test double

app/                        # Sample application
  src/main/kotlin/com/emildesign/app/
    presentation/device_control/    # ViewModel + Screen + Components
```

### iOS
```
DeviceConnectivitySDK/      # Framework target (the SDK)
  Sources/
    api/DeviceConnector.swift       # Public protocol + factory function
    DeviceConnectorImpl.swift       # Implementation (internal)
    domain/model/                   # Public types
    data/transport/                 # Internal transport layer

Demo/                       # Sample app target
  Presentation/DeviceControl/       # ViewModel + Screen + Components
```

---

## API Evolution and Backward Compatibility

The public surface is intentionally small: one interface/protocol, two observables, and four methods. This makes evolution manageable.

**Non-breaking changes (safe to ship as minor versions):**
- Adding new methods with default implementations.
- Adding new `ConnectionState` cases — consumers using exhaustive `when`/`switch` will get a compile warning, not a crash.
- Adding new fields to `DeviceData` with default values.
- Adding new `DisconnectReason` cases.

**Breaking changes (require a major version bump):**
- Removing or renaming existing `ConnectionState` cases.
- Changing the type of `connectionState` or `deviceData`.
- Changing the signature of `connect()`, `disconnect()`, `setVolume()`, or `release()`.

**Strategy:** deprecate before removing. Any method or type marked `@Deprecated` should survive for at least one minor version before being removed in a major version. This gives consumers time to migrate without being forced to update immediately.

---

## Testing Strategy

Tests focus on the **SDK core only** — state machine transitions, error cases, and no-op guards. The sample app is a test harness, not a product, so UI tests were not written. The risk in the UI layer is low enough that manual testing during development is sufficient.

**What is tested:**
- All state machine transitions (Idle → Connecting → Connected, timeout, unexpected disconnect, consumer disconnect).
- `deviceData` updates on connected state, and clearing on disconnect.
- `setVolume()` returns failure when not connected.
- `connect()` is a no-op when already connecting or connected.
- `release()` cancels the internal event listener so future transport events are ignored.
- `MockDeviceTransport` success scenario as a light integration test.

**What is not tested:**
- Compose/SwiftUI views — low risk, manually verified.
- ViewModel — thin layer with no logic of its own; tested indirectly through the SDK tests.
- Mock transport timing — non-deterministic delays are not unit tested; only the scenario outcomes are verified.

**Tools:**
- Android: `kotlinx-coroutines-test`, `Turbine` (for Flow assertions), `FakeTransport` (hand-rolled test double).
- iOS: `XCTest`, `FakeTransport` (hand-rolled test double using `AsyncStream`).

A hand-rolled fake was chosen over a mock framework (Mockito, etc.) because it gives full control over emitted events without timing dependencies, and it makes the test intent clearer.

---

## Telemetry and Logging

**Would collect:**
- State transition events with timestamps (e.g. Connecting started, Connected, Failed + reason).
- Transport error types and frequency.
- SDK version and OS/platform version.
- Command latency — time between `setVolume()` call and transport acknowledgment.

**Would intentionally exclude:**
- Device ID — this could identify a specific user's physical hardware and is therefore PII.
- Volume levels — user behavior data that the consumer may consider private.
- Battery levels — device health data that belongs to the device owner, not the SDK.
- Any content from `DeviceData` payloads.

The rule is simple: log what helps debug the SDK, never log what the user is doing or what device they own.

**Implementation:** Android would use `android.util.Log` with a `connectivity-sdk` tag, guarded by `BuildConfig.DEBUG` so release builds are not polluted. iOS would use `os.Logger` with a `connectivity-sdk` subsystem at `.debug` level.

---

## Distribution

### Current approach — private GitHub repository (internal use)

For now the SDK lives in a private GitHub repository and is consumed as a local dependency within the workspace (iOS) or as a Gradle module (Android). This is the right choice while the SDK is for internal use only.

**Why:** Setting up Maven Central for Android requires a Sonatype account, GPG key signing, and a multi-step verification process that can take days. Swift Package Manager on a private repo requires all consumers to have GitHub access and token configuration in Xcode. Both are unnecessary overhead for an internal SDK.

**Implications of staying private:**
- Consumers must have access to the GitHub org to add the dependency.
- No versioning enforcement — consumers can reference a branch instead of a tagged release, which can lead to unexpected breakage.
- No discovery — other teams can't find the SDK unless they're told about it.

### If the SDK goes public — Maven Central (Android) + Swift Package Manager (iOS)

If the SDK needs to be open-sourced or shared outside the org, the right approach is:

**Android:** publish to Maven Central via Sonatype. Consumers add one line:
```kotlin
implementation("com.emildesign:device-connectivity-sdk:1.0.0")
```

**iOS:** publish as a Swift Package on a public GitHub repo. Consumers add via Xcode:
`File → Add Package Dependencies → paste GitHub URL`

**Implications of going public:**
- Semantic versioning becomes a hard contract. A breaking change to the public API surface requires a major version bump (2.0.0). Consumers who pin to `1.x` must not be broken.
- The `internal` keyword on Android and `internal` access on iOS become critical — anything accidentally made `public` becomes part of the API contract and is hard to remove without a major version.
- Android: use the [Binary Compatibility Validator](https://github.com/Kotlin/binary-compatibility-validator) plugin in CI to catch unintentional public API changes.
- iOS: use `swift-api-digester` in CI for the same purpose.
- `MockDeviceTransport` should be moved to a separate `-testing` artifact/target so it does not ship in the production SDK but is still available to consumers for their own UI tests.
