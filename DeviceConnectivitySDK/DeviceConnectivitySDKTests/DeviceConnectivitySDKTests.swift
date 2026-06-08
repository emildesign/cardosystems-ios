//
//  DeviceConnectivitySDKTests.swift
//  DeviceConnectivitySDKTests
//
//  Created by Emil Adz on 07/06/2026.
//

import XCTest
@testable import DeviceConnectivitySDK

@MainActor
final class DeviceConnectivitySDKTests: XCTestCase {

    override func setUpWithError() throws {}
    override func tearDownWithError() throws {}

    // MARK: - Helpers

    private func makeConnector(transport: any DeviceTransport) -> any DeviceConnector {
        makeDeviceConnectorWithTransport(transport)
    }

    private func collectStates(
        from connector: any DeviceConnector,
        count: Int,
        drainMs: UInt64 = 200,
        during block: () async -> Void
    ) async -> [ConnectionState] {
        actor StateCollector {
            var states: [ConnectionState] = []
            func append(_ state: ConnectionState) { states.append(state) }
            func count() -> Int { states.count }
            func all() -> [ConnectionState] { states }
        }
        let collector = StateCollector()
        let task = Task {
            for await state in connector.connectionState.values {
                await collector.append(state)
                if await collector.count() >= count { break }
            }
        }
        await block()
        try? await Task.sleep(nanoseconds: drainMs * 1_000_000)
        task.cancel()
        return await collector.all()
    }

    // MARK: - Tests

    func testGivenNewConnector_thenInitialStateIsIdle() async {
        let connector = makeConnector(transport: FakeTransport())
        let state = await connector.connectionState.values.first(where: { _ in true })
        XCTAssertEqual(state, .idle)
    }

    func testGivenIdle_whenConnectCalled_thenTransitionsToConnected() async {
        let transport = FakeTransport()
        let connector = makeConnector(transport: transport)
        let states = await collectStates(from: connector, count: 2) {
            await connector.connect(deviceId: "device-01")
            await transport.emit(.connected)
        }
        XCTAssertTrue(states.contains(.connecting), "States: \(states)")
        XCTAssertTrue(states.contains(.connected(deviceId: "device-01")), "States: \(states)")
    }

    func testGivenConnecting_whenTimeoutReceived_thenTransitionsToFailed() async {
        let transport = FakeTransport()
        let connector = makeConnector(transport: transport)
        let states = await collectStates(from: connector, count: 2) {
            await connector.connect(deviceId: "device-01")
            await transport.emit(.disconnected(.timeout))
        }
        XCTAssertTrue(states.contains(.failed(.timeout)), "States: \(states)")
    }

    func testGivenConnected_whenUnexpectedDisconnect_thenTransitionsToFailed() async {
        let transport = FakeTransport()
        let connector = makeConnector(transport: transport)
        let states = await collectStates(from: connector, count: 3) {
            await connector.connect(deviceId: "device-01")
            await transport.emit(.connected)
            try? await Task.sleep(nanoseconds: 10_000_000)
            await transport.emit(.disconnected(.unexpectedDisconnect))
        }
        XCTAssertTrue(states.contains(.failed(.unexpectedDisconnect)), "States: \(states)")
    }

    func testGivenConnected_whenDisconnectCalled_thenTransitionsToIdle() async {
        let transport = FakeTransport()
        let connector = makeConnector(transport: transport)
        let states = await collectStates(from: connector, count: 4, drainMs: 500) {
            await connector.connect(deviceId: "device-01")
            await transport.emit(.connected)
            try? await Task.sleep(nanoseconds: 50_000_000)
            await connector.disconnect()
            try? await Task.sleep(nanoseconds: 50_000_000)
            await transport.emit(.disconnected(.consumerDisconnected))
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        guard states.count >= 4 else {
            XCTFail("Expected 4 states but got \(states.count): \(states)")
            return
        }
        XCTAssertEqual(states[2], .disconnecting)
        XCTAssertEqual(states[3], .idle)
    }

    func testGivenConnected_whenDataUpdateReceived_thenDeviceDataUpdated() async {
        let transport = FakeTransport()
        let connector = makeConnector(transport: transport)

        actor DataCollector {
            var values: [DeviceData?] = []
            func append(_ value: DeviceData?) { values.append(value) }
            func count() -> Int { values.count }
            func last() -> DeviceData? { values.last.flatMap { $0 } }
        }
        let collector = DataCollector()

        let task = Task {
            for await data in connector.deviceData.values {
                await collector.append(data)
                if await collector.count() >= 2 { break }
            }
        }
        await connector.connect(deviceId: "device-01")
        await transport.emit(.connected)
        try? await Task.sleep(nanoseconds: 10_000_000)
        await transport.emit(.dataUpdate(DeviceData(volume: 7, battery: 80)))
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        let lastData = await collector.last()
        XCTAssertEqual(lastData, DeviceData(volume: 7, battery: 80))
    }

    func testGivenIdle_whenSetVolumeCalled_thenReturnsFailure() async {
        let connector = makeConnector(transport: FakeTransport())
        let result = await connector.setVolume(level: 5)
        if case .success = result { XCTFail("Expected failure") }
    }

    func testGivenConnecting_whenConnectCalledAgain_thenNoOp() async {
        let transport = FakeTransport()
        let connector = makeConnector(transport: transport)
        await connector.connect(deviceId: "device-01")
        await connector.connect(deviceId: "device-02")
        let count = await transport.connectCallCount
        XCTAssertEqual(count, 1)
    }

    func testGivenConnected_whenDisconnected_thenDeviceDataCleared() async {
        let transport = FakeTransport()
        let connector = makeConnector(transport: transport)
        await connector.connect(deviceId: "device-01")
        await transport.emit(.connected)
        await transport.emit(.dataUpdate(DeviceData(volume: 5, battery: 70)))
        try? await Task.sleep(nanoseconds: 100_000_000)
        await connector.disconnect()
        await transport.emit(.disconnected(.consumerDisconnected))
        try? await Task.sleep(nanoseconds: 100_000_000)
        // Collect the current value directly — after disconnect deviceData should be nil
        var currentData: DeviceData? = DeviceData(volume: 0, battery: 0) // non-nil sentinel
        let task = Task {
            for await data in connector.deviceData.values {
                currentData = data
                break // take first emission only
            }
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        XCTAssertNil(currentData, "Expected deviceData to be nil after disconnect but got \(String(describing: currentData))")
    }

    func testGivenConnector_whenReleased_thenEventListenerCancelled() async {
        let transport = FakeTransport()
        let connector = makeConnector(transport: transport)
        await connector.connect(deviceId: "device-01")
        await transport.emit(.connected)
        try? await Task.sleep(nanoseconds: 100_000_000)
        connector.release()
        try? await Task.sleep(nanoseconds: 100_000_000)
        await transport.emit(.dataUpdate(DeviceData(volume: 10, battery: 100)))
        try? await Task.sleep(nanoseconds: 100_000_000)
        var currentData: DeviceData? = DeviceData(volume: 0, battery: 0)
        let task = Task {
            for await data in connector.deviceData.values {
                currentData = data
                break
            }
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()
        XCTAssertNil(currentData, "Expected deviceData to be nil after release but got \(String(describing: currentData))")
    }

    func testGivenMockTransport_whenSuccess_thenConnects() async {
        let transport = MockDeviceTransport(scenario: .success)
        let connector = makeConnector(transport: transport)
        let states = await collectStates(from: connector, count: 3, drainMs: 500) {
            await connector.connect(deviceId: "device-01")
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
        XCTAssertTrue(states.contains(where: { if case .connected = $0 { return true }; return false }))
    }
}

// MARK: - FakeTransport

actor FakeTransport: DeviceTransport {
    private let continuation: AsyncStream<TransportEvent>.Continuation
    nonisolated let events: AsyncStream<TransportEvent>
    var connectCallCount = 0
    var disconnectCallCount = 0
    var lastCommand: DeviceCommand?

    init() {
        var cont: AsyncStream<TransportEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    func emit(_ event: TransportEvent) { continuation.yield(event) }
    func connect(deviceId: String) async { connectCallCount += 1 }
    func disconnect() async { disconnectCallCount += 1 }
    func sendCommand(_ command: DeviceCommand) async { lastCommand = command }
}
