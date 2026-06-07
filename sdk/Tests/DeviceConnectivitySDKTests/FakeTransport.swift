import XCTest
@testable import DeviceConnectivitySDK

/**
 Mirrors `com.emildesign.sdk.FakeTransport`.
 */
final class FakeTransport: DeviceTransport {

    let eventsContinuation: AsyncStream<TransportEvent>.Continuation
    let events: AsyncStream<TransportEvent>

    private(set) var connectCallCount = 0
    private(set) var disconnectCallCount = 0
    private(set) var sentCommands: [DeviceCommand] = []
    var lastCommand: DeviceCommand? { sentCommands.last }

    init() {
        var continuation: AsyncStream<TransportEvent>.Continuation!
        self.events = AsyncStream(bufferingPolicy: .bufferingUnbounded) { c in
            continuation = c
        }
        self.eventsContinuation = continuation
    }

    func connect(deviceId: String) async {
        connectCallCount += 1
    }

    func disconnect() async {
        disconnectCallCount += 1
    }

    func sendCommand(_ command: DeviceCommand) async {
        sentCommands.append(command)
    }

    // Test helpers.
    func emit(_ event: TransportEvent) {
        eventsContinuation.yield(event)
    }
}
