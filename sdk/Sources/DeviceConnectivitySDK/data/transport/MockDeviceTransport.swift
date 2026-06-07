import Foundation

/**
 Simulates a remote device. Think of it as a puppet that follows a script:
 - connects after a short delay
 - randomly changes battery / volume over time
 - occasionally drops the connection unexpectedly

 The scenario is controllable via `MockScenario` for testing.

 Mirrors `com.emildesign.sdk.data.transport.MockDeviceTransport`.
 */
final class MockDeviceTransport: DeviceTransport {

    enum MockScenario {
        case success
        case timeout
        case unexpectedDisconnect
    }

    private let scenario: MockScenario
    private var continuation: AsyncStream<TransportEvent>.Continuation?
    private var deviceTask: Task<Void, Never>?
    private var currentVolume: Int = 5
    private var lastBattery: Int = 80

    private lazy var stream: AsyncStream<TransportEvent> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()

    var events: AsyncStream<TransportEvent> { stream }

    init(scenario: MockScenario = .success) {
        self.scenario = scenario
    }

    func connect(deviceId: String) async {
        switch scenario {
        case .timeout:
            try? await Task.sleep(nanoseconds: connectTimeoutNanos)
            continuation?.yield(.disconnected(.timeout))
        case .success, .unexpectedDisconnect:
            try? await Task.sleep(nanoseconds: connectDelayNanos)
            continuation?.yield(.connected)
            startDeviceSimulation()
        }
    }

    func disconnect() async {
        deviceTask?.cancel()
        deviceTask = nil
        try? await Task.sleep(nanoseconds: disconnectDelayNanos)
        continuation?.yield(.disconnected(.consumerDisconnected))
    }

    func sendCommand(_ command: DeviceCommand) async {
        switch command {
        case .setVolume(let level):
            currentVolume = min(max(level, 0), 10)
            continuation?.yield(.dataUpdate(DeviceData(volume: currentVolume, battery: lastBattery)))
        }
    }

    // ---- Private ----

    private func startDeviceSimulation() {
        deviceTask = Task { [weak self] in
            guard let self = self else { return }
            var tickCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: tickIntervalNanos)
                tickCount += 1

                if self.scenario == .unexpectedDisconnect && tickCount >= unexpectedDisconnectAfterTicks {
                    self.continuation?.yield(.disconnected(.unexpectedDisconnect))
                    break
                }

                // Device-originated: battery slowly drains
                let drain = Int.random(in: 0..<3)
                self.lastBattery = max(self.lastBattery - drain, 0)

                // Device-originated: volume nudges occasionally
                if tickCount % volumeChangeIntervalTicks == 0 {
                    let nudge = Int.random(in: -1...1)
                    self.currentVolume = min(max(self.currentVolume + nudge, 0), 10)
                }

                self.continuation?.yield(
                    .dataUpdate(DeviceData(volume: self.currentVolume, battery: self.lastBattery))
                )
            }
        }
    }

    private enum Timing {
        static let connectDelay: UInt64 = 1_000_000_000          // 1.0 s
        static let connectTimeout: UInt64 = 5_000_000_000        // 5.0 s
        static let disconnectDelay: UInt64 = 300_000_000        // 0.3 s
        static let tickInterval: UInt64 = 2_000_000_000         // 2.0 s
        static let unexpectedDisconnectAfterTicks = 5
        static let volumeChangeIntervalTicks = 3
    }

    private var connectDelayNanos: UInt64 { Timing.connectDelay }
    private var connectTimeoutNanos: UInt64 { Timing.connectTimeout }
    private var disconnectDelayNanos: UInt64 { Timing.disconnectDelay }
    private var tickIntervalNanos: UInt64 { Timing.tickInterval }
    private var unexpectedDisconnectAfterTicks: Int { Timing.unexpectedDisconnectAfterTicks }
    private var volumeChangeIntervalTicks: Int { Timing.volumeChangeIntervalTicks }
}
