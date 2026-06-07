import XCTest
@testable import DeviceConnectivitySDK

/**
 Tests for `DeviceConnector`.
 Uses `FakeTransport` to simulate transport-layer behavior.

 Mirrors `com.emildesign.sdk.DeviceConnectorTest`.
 */
final class DeviceConnectorTest: XCTestCase {

    private var transport: FakeTransport!
    private var connector: DeviceConnector!

    override func setUp() async throws {
        try await super.setUp()
        transport = FakeTransport()
        connector = DeviceConnector.createWithTransport(transport)
    }

    override func tearDown() async throws {
        connector.release()
        transport = nil
        connector = nil
        try await super.tearDown()
    }

    // ---- Lifecycle Tests ----

    func test_givenNewConnector_thenInitialStateIsIdle() async {
        XCTAssertEqual(connector.currentConnectionState, .idle)
    }

    func test_givenIdle_whenConnectCalled_thenTransitionsToConnected() async throws {
        // Collecting in a Task so the AsyncStream values flow through the connector's
        // buffering policy (we expect Connecting, then Connected).
        let expectation = expectation(description: "states received")
        var states: [ConnectionState] = [.idle]
        let consumer = Task {
            for await state in connector.connectionState {
                states.append(state)
                if states.count >= 3 {
                    expectation.fulfill()
                    return
                }
            }
        }

        Task {
            await connector.connect(deviceId: "device-01")
            // Simulate transport "Connected" response shortly after connect.
            try? await Task.sleep(nanoseconds: 50_000_000)
            transport.emit(.connected)
        }

        await fulfillment(of: [expectation], timeout: 2.0)
        consumer.cancel()

        XCTAssertEqual(states[0], .idle)
        XCTAssertEqual(states[1], .connecting)
        if case let .connected(deviceId) = states[2] {
            XCTAssertEqual(deviceId, "device-01")
        } else {
            XCTFail("Expected .connected, got \(states[2])")
        }
    }

    func test_givenConnecting_whenTimeoutReceived_thenTransitionsToFailedWithTimeout() async throws {
        let expectation = expectation(description: "failed received")
        var last: ConnectionState = .idle
        let consumer = Task {
            var collected: [ConnectionState] = []
            for await state in connector.connectionState {
                collected.append(state)
                last = state
                if case .failed = state { expectation.fulfill(); return }
                if collected.count > 5 { return }
            }
        }

        Task {
            await connector.connect(deviceId: "device-01")
            try? await Task.sleep(nanoseconds: 50_000_000)
            transport.emit(.disconnected(.timeout))
        }

        await fulfillment(of: [expectation], timeout: 2.0)
        consumer.cancel()

        if case let .failed(reason) = last {
            XCTAssertEqual(reason, .timeout)
        } else {
            XCTFail("Expected .failed(.timeout), got \(last)")
        }
        XCTAssertNil(connector.currentDeviceData)
    }

    func test_givenConnected_whenUnexpectedDisconnectReceived_thenTransitionsToFailedAndClearsData() async throws {
        let expectation = expectation(description: "failed received")
        var last: ConnectionState = .idle
        let consumer = Task {
            var collected: [ConnectionState] = []
            for await state in connector.connectionState {
                collected.append(state)
                last = state
                if case .failed = state { expectation.fulfill(); return }
                if collected.count > 5 { return }
            }
        }

        Task {
            await connector.connect(deviceId: "device-01")
            try? await Task.sleep(nanoseconds: 20_000_000)
            transport.emit(.connected)
            try? await Task.sleep(nanoseconds: 50_000_000)
            transport.emit(.disconnected(.unexpectedDisconnect))
        }

        await fulfillment(of: [expectation], timeout: 2.0)
        consumer.cancel()

        if case let .failed(reason) = last {
            XCTAssertEqual(reason, .unexpectedDisconnect)
        } else {
            XCTFail("Expected .failed(.unexpectedDisconnect), got \(last)")
        }
        XCTAssertNil(connector.currentDeviceData)
    }

    func test_givenConnected_whenDisconnectCalled_thenTransitionsToIdleAfterTransportEvent() async throws {
        let expectation = expectation(description: "idle received")
        var last: ConnectionState = .idle
        let consumer = Task {
            var collected: [ConnectionState] = []
            for await state in connector.connectionState {
                collected.append(state)
                last = state
                if case .idle = state, collected.count > 1 { expectation.fulfill(); return }
                if collected.count > 6 { return }
            }
        }

        Task {
            await connector.connect(deviceId: "device-01")
            try? await Task.sleep(nanoseconds: 20_000_000)
            transport.emit(.connected)
            try? await Task.sleep(nanoseconds: 50_000_000)
            await connector.disconnect()
            try? await Task.sleep(nanoseconds: 50_000_000)
            transport.emit(.disconnected(.consumerDisconnected))
        }

        await fulfillment(of: [expectation], timeout: 2.0)
        consumer.cancel()

        XCTAssertEqual(last, .idle)
        XCTAssertNil(connector.currentDeviceData)
    }

    // ---- Data & Commands Tests ----

    func test_givenConnected_whenDataUpdateReceived_thenDeviceDataIsUpdated() async throws {
        let expectation = expectation(description: "data update received")
        var last: DeviceData? = nil
        let consumer = Task {
            var collected: [DeviceData?] = []
            for await data in connector.deviceData {
                collected.append(data)
                last = data
                if data != nil { expectation.fulfill(); return }
                if collected.count > 5 { return }
            }
        }

        Task {
            await connector.connect(deviceId: "device-01")
            try? await Task.sleep(nanoseconds: 20_000_000)
            transport.emit(.connected)
            try? await Task.sleep(nanoseconds: 50_000_000)
            transport.emit(.dataUpdate(DeviceData(volume: 7, battery: 80)))
        }

        await fulfillment(of: [expectation], timeout: 2.0)
        consumer.cancel()

        XCTAssertEqual(last, DeviceData(volume: 7, battery: 80))
    }

    func test_givenIdle_whenSetVolumeCalled_thenReturnsFailure() async {
        let result = await connector.setVolume(5)
        switch result {
        case .success:
            XCTFail("Expected failure when not connected")
        case .failure(let error):
            XCTAssertTrue(error is NSError)
        }
    }

    func test_givenConnected_whenMultipleVolumeCommandsSentRapidly_thenProcessedSequentially() async throws {
        // Setup: connect first.
        await connector.connect(deviceId: "device-01")
        transport.emit(.connected)
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Action: send 5 volume commands in parallel.
        await withTaskGroup(of: Void.self) { group in
            for vol in 1...5 {
                group.addTask {
                    _ = await self.connector.setVolume(vol)
                }
            }
        }
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(transport.sentCommands.count, 5)
        if case let .setVolume(level) = transport.lastCommand {
            XCTAssertEqual(level, 5)
        } else {
            XCTFail("Expected last command to be .setVolume(5)")
        }
    }

    func test_givenConnecting_whenConnectCalledAgain_thenSecondCallIsNoOp() async throws {
        await connector.connect(deviceId: "device-01")
        let firstState = connector.currentConnectionState
        await connector.connect(deviceId: "device-02") // should be ignored
        XCTAssertEqual(firstState, connector.currentConnectionState)
        XCTAssertEqual(transport.connectCallCount, 1)
    }

    func test_givenConnector_whenReleased_thenInternalScopeIsCancelled() async throws {
        await connector.connect(deviceId: "device-01")
        transport.emit(.connected)
        try? await Task.sleep(nanoseconds: 50_000_000)

        connector.release()
        try? await Task.sleep(nanoseconds: 50_000_000)

        transport.emit(.dataUpdate(DeviceData(volume: 10, battery: 100)))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertNil(connector.currentDeviceData)
    }

    func test_givenFailedState_whenConnectCalled_thenCanReconnectSuccessfully() async throws {
        // 1. Fail first
        await connector.connect(deviceId: "device-01")
        transport.emit(.disconnected(.timeout))
        try? await Task.sleep(nanoseconds: 50_000_000)

        if case .failed = connector.currentConnectionState {} else {
            XCTFail("Expected .failed state")
        }

        // 2. Try again
        await connector.connect(deviceId: "device-01")
        transport.emit(.connected)
        try? await Task.sleep(nanoseconds: 50_000_000)

        if case .connected = connector.currentConnectionState {} else {
            XCTFail("Expected .connected state, got \(connector.currentConnectionState)")
        }
    }
}
