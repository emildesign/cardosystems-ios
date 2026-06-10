// FakeTransport.swift
// DeviceConnectivitySDKTests

@testable import DeviceConnectivitySDK

actor FakeTransport: DeviceTransport {
    private let continuation: AsyncStream<TransportEvent>.Continuation
    nonisolated let events: AsyncStream<TransportEvent>

    var connectCallCount = 0
    var disconnectCallCount = 0
    var sentCommands: [DeviceCommand] = []
    var lastCommand: DeviceCommand? { sentCommands.last }

    init() {
        var cont: AsyncStream<TransportEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    func emit(_ event: TransportEvent) { continuation.yield(event) }
    func connect(deviceId: String) async { connectCallCount += 1 }
    func disconnect() async { disconnectCallCount += 1 }
    func sendCommand(_ command: DeviceCommand) async { sentCommands.append(command) }
}
