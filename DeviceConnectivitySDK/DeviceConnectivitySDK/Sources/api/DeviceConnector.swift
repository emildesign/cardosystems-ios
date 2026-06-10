// DeviceConnector.swift
import Combine

public protocol DeviceConnector {
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    var deviceData: AnyPublisher<DeviceData?, Never> { get }
    func connect(deviceId: String) async
    func disconnect() async
    func setVolume(level: Int) async -> Result<Void, Error>
    func release()
}

/// Production factory — use this in your ViewModel.
@MainActor
public func makeDeviceConnector() -> any DeviceConnector {
    DeviceConnectorImpl()
}
 
/// Test factory — inject a custom transport (e.g. FakeTransport).
@MainActor
func makeDeviceConnectorWithTransport(_ transport: any DeviceTransport) -> any DeviceConnector {
    DeviceConnectorImpl(transport: transport)
}
