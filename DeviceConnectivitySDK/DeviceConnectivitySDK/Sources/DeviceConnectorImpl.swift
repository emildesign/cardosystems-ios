// DeviceConnectorImpl.swift
import Combine
import Foundation

@MainActor
final class DeviceConnectorImpl: DeviceConnector {

    var connectionState: AnyPublisher<ConnectionState, Never> {
        _connectionState.eraseToAnyPublisher()
    }
    var deviceData: AnyPublisher<DeviceData?, Never> {
        _deviceData.eraseToAnyPublisher()
    }

    private let _connectionState = CurrentValueSubject<ConnectionState, Never>(.idle)
    private let _deviceData = CurrentValueSubject<DeviceData?, Never>(nil)
    private let transport: any DeviceTransport
    private var eventListenerTask: Task<Void, Never>?
    private var storedDeviceId: String?

    init(transport: (any DeviceTransport)? = nil) {
        self.transport = transport ?? MockDeviceTransport()
    }

    func connect(deviceId: String) async {
        guard !isConnectingOrConnected(_connectionState.value) else { return }
        storedDeviceId = deviceId
        _connectionState.send(.connecting)
        startListeningToTransport()
        await transport.connect(deviceId: deviceId)
    }

    func disconnect() async {
        guard !isIdleOrFailed(_connectionState.value) else { return }
        _connectionState.send(.disconnecting)
        await transport.disconnect()
    }

    func setVolume(level: Int) async -> Result<Void, Error> {
        guard case .connected = _connectionState.value else {
            return .failure(DeviceConnectorError.illegalState(
                "setVolume called while not Connected. State: \(_connectionState.value)"))
        }
        await transport.sendCommand(.setVolume(level))
        return .success(())
    }

    func release() {
        Task {
            await disconnect();
            eventListenerTask?.cancel()
            eventListenerTask = nil
        }
    }

    private func startListeningToTransport() {
        guard eventListenerTask == nil else { return }
        eventListenerTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.transport.events {
                await self.handleTransportEvent(event)
            }
        }
    }

    private func handleTransportEvent(_ event: TransportEvent) {
        switch event {
        case .connected:
            _connectionState.send(.connected(deviceId: storedDeviceId ?? "unknown"))
        case .disconnected(let reason):
            _connectionState.send(reason == .consumerDisconnected ? .idle : .failed(reason))
            _deviceData.send(nil)
        case .dataUpdate(let data):
            if case .connected = _connectionState.value { _deviceData.send(data) }
        }
    }

    private func isConnectingOrConnected(_ s: ConnectionState) -> Bool {
        switch s { case .connecting, .connected: return true; default: return false }
    }
    private func isIdleOrFailed(_ s: ConnectionState) -> Bool {
        switch s { case .idle, .failed: return true; default: return false }
    }
}
