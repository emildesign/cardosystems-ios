# Device Connectivity SDK — Design Document (iOS)

---

## Public API Surface

The SDK exposes a single entry point: `DeviceConnector`.
The goal was to keep the surface as small as possible — if it's not needed by a consumer, it's not public.

```swift
public protocol DeviceConnector {
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    var deviceData: AnyPublisher<DeviceData?, Never> { get }
    func connect(deviceId: String) async
    func disconnect() async
    func setVolume(level: Int) async -> Result<Void, Error>
    func release()
}
```

**Rationale per method:**

- `connectionState` — always-available publisher of the current lifecycle state. Backed by `CurrentValueSubject` so new subscribers immediately receive the current value without missing state.
- `deviceData` — nullable because there is no data until the device sends its first update after connecting.
- `connect(deviceId)` — suspends until the transport has processed the request. No-op if already connecting or connected.
- `disconnect()` — suspends until teardown is complete. No-op if already idle or failed.
- `setVolume(level)` — returns `Result` rather than throwing. A failure means the consumer called it at the wrong time (not connected), which is a recoverable situation not a crash.
- `release()` — cleans up internal tasks. Should be called when the consumer is done with the SDK (e.g. in `deinit` of the `ObservableObject`).

**Why a protocol instead of a concrete class:**
It makes it easy to swap the real implementation for a test double without changing any consumer code. The consumer always holds `any DeviceConnector`, never `DeviceConnectorImpl`.

**Factory:**
```swift
let connector = makeDeviceConnector()
```
A free function is used instead of a static method on the protocol because Swift does not allow calling static methods on existential protocol types (`any DeviceConnector`). The implementation class (`DeviceConnectorImpl`) is `internal` — consumers cannot instantiate it directly.

**Public types:**

- `ConnectionState` — enum with five cases: `idle`, `connecting`, `connected(deviceId:)`, `disconnecting`, `failed(DisconnectReason)`.
- `DeviceData` — struct with `volume: Int` (0–10) and `battery: Int` (0–100).
- `DisconnectReason` — enum with `timeout`, `unexpectedDisconnect`, `consumerDisconnected`.

---

## Concurrency Model

- All publisher emissions are delivered on the **main thread** (`receive(on: DispatchQueue.main)`).
- `connect()`, `disconnect()`, and `setVolume()` are `async` functions — the caller controls which context they run on.
- `DeviceConnectorImpl` is marked `@MainActor` — all mutations to internal state are serialized on the main actor. Swift enforces this at compile time.
- Internal transport work (delays, simulated IO) runs in detached `Task`s on the cooperative thread pool.

**What happens on concurrent calls:**
- `connect()` while already connecting or connected → no-op, guarded by state check.
- `disconnect()` while idle or failed → no-op, guarded by state check.
- Multiple `setVolume()` calls in parallel → serialized by `@MainActor` isolation. All calls hop to the main actor and are processed one at a time.

---

## Error Model

Runtime errors are **state transitions**, not thrown errors.

- `connect()` does not throw. A timeout or unexpected drop transitions state to `.failed(reason)`.
- `setVolume()` returns `.failure(DeviceConnectorError.illegalState(...))` if called while not connected — this is a usage error the consumer should handle, but it should not crash the app.
- There are no delegates or completion callbacks on the public API. The consumer observes `connectionState` and reacts to `.failed`.

**Why state transitions instead of thrown errors:**
Errors as state transitions are safer — the consumer reacts by observing state, not by catching errors in the right place. A missed `try/catch` is silent; a missed `.failed` case in a `switch` produces a compiler warning.

---

## State Model

```
idle ──connect()──► connecting ──success──► connected
                        │                       │
                     timeout                disconnect()
                     or error                    │
                        │                        ▼
                        └──────────────► disconnecting ──► idle
                        │
                        ▼
                      failed
                        │
                     connect()
                        ▼
                     connecting
```

**Legal transitions:**

| From          | To            | Trigger                   |
|---------------|---------------|---------------------------|
| idle          | connecting    | `connect()`               |
| connecting    | connected     | transport success         |
| connecting    | failed        | timeout / transport error |
| connected     | disconnecting | `disconnect()`            |
| connected     | failed        | unexpected disconnect     |
| disconnecting | idle          | teardown complete         |
| failed        | connecting    | `connect()` retry         |

**Deliberately disallowed:**
- `connected → connecting` — must disconnect first.
- `idle → disconnecting` — nothing to tear down.
- `connecting → disconnecting` — not supported in v1; cancel and retry instead.

---

## Lifecycle and Resource Handling

The SDK does not manage its own lifecycle. The consumer (`ObservableObject` / ViewModel) is responsible for calling `release()` when done.

**Why the consumer controls lifecycle:**
Some apps need the connection to stay alive when the screen is backgrounded — for example an app that monitors a device in the background. If the SDK shut itself down automatically, that use case would be impossible. Giving the consumer full control means they decide whether to tie the connector to a view or keep it alive at the app level.

**What happens in each scenario:**
- Consumer calls `disconnect()` → graceful teardown, state goes to `.idle`.
- Consumer forgets to call `release()` → the mock transport will eventually fire an `.unexpectedDisconnect`. A real transport would rely on CoreBluetooth delegate teardown.
- Process is killed → Swift's structured concurrency cancels all tasks naturally. No persistent state exists.
- App goes to background → connection stays alive. The `ObservableObject` is not destroyed on background, so the connector keeps running. The consumer should decide in `deinit` or `.onDisappear` whether to disconnect or leave the connection alive.

---

## v2 Change

**Separate volume and battery into independent publishers.**
Currently a battery update re-emits `DeviceData` with an unchanged volume, triggering an unnecessary SwiftUI view update for the volume component. In v2 I'd expose `var volumeState: AnyPublisher<Int, Never>` and `var batteryState: AnyPublisher<Int, Never>` separately.

I didn't do this in v1 because the single `DeviceData` struct is simpler and perfectly adequate for a mock SDK. It's an optimization, not a correctness issue.
