// DeviceConnector.swift
import Combine

public protocol DeviceConnector: AnyObject {
    var connectionState: AnyPublisher<ConnectionState, Never> { get }
    var deviceData: AnyPublisher<DeviceData?, Never> { get }
    func connect(deviceId: String) async
    func disconnect() async
    func setVolume(level: Int) async -> Result<Void, Error>
    func release()
}

@MainActor public func makeDeviceConnector() -> any DeviceConnector {
    DeviceConnectorImpl()
}


public extension DeviceConnector {
//    @MainActor internal static func create() -> any DeviceConnector { DeviceConnectorImpl() }
    @MainActor internal static func createWithTransport(_ transport: any DeviceTransport) -> any DeviceConnector {
        DeviceConnectorImpl(transport: transport)
    }
}


