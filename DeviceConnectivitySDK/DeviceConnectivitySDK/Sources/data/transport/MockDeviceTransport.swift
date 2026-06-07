// MockDeviceTransport.swift
import Foundation

public final class MockDeviceTransport: DeviceTransport {

    public enum MockScenario { case success, timeout, unexpectedDisconnect }

    private let scenario: MockScenario
    private let continuation: AsyncStream<TransportEvent>.Continuation
    internal let events: AsyncStream<TransportEvent>
    private var simulationTask: Task<Void, Never>?
    private var currentVolume: Int = 5
    private var lastBattery: Int = 80

    public init(scenario: MockScenario = .success) {
        self.scenario = scenario
        var cont: AsyncStream<TransportEvent>.Continuation!
        self.events = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    public func connect(deviceId: String) async {
        switch scenario {
        case .timeout:
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            continuation.yield(.disconnected(.timeout))
        case .success, .unexpectedDisconnect:
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            continuation.yield(.connected)
            startDeviceSimulation()
        }
    }

    public func disconnect() async {
        simulationTask?.cancel()
        simulationTask = nil
        try? await Task.sleep(nanoseconds: 300_000_000)
        continuation.yield(.disconnected(.consumerDisconnected))
    }

    internal func sendCommand(_ command: DeviceCommand) async {
        switch command {
        case .setVolume(let level):
            currentVolume = min(10, max(0, level))
            continuation.yield(.dataUpdate(DeviceData(volume: currentVolume, battery: lastBattery)))
        }
    }

    private func startDeviceSimulation() {
        simulationTask = Task {
            var tickCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { break }
                tickCount += 1
                if scenario == .unexpectedDisconnect && tickCount >= 5 {
                    continuation.yield(.disconnected(.unexpectedDisconnect))
                    break
                }
                lastBattery = max(0, lastBattery - Int.random(in: 0...2))
                if tickCount % 3 == 0 {
                    currentVolume = min(10, max(0, currentVolume + Int.random(in: -1...1)))
                }
                continuation.yield(.dataUpdate(DeviceData(volume: currentVolume, battery: lastBattery)))
            }
        }
    }
}
