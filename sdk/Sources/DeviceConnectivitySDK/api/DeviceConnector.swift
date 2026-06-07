import Foundation

/**
 Public entry point for the Device Connectivity SDK.

 Usage:
 ```
 let connector = DeviceConnector.create()
 await connector.connect("device-01")
 for await state in connector.connectionState {
     // ...
 }
 ```

 Mirrors `com.emildesign.sdk.api.DeviceConnector`.
 */
public protocol DeviceConnector: AnyObject {
    /// Current connection lifecycle state. Always has a value (starts as `.idle`).
    var connectionState: AsyncStream<ConnectionState> { get }

    /**
     Latest device readings. `nil` until the first data arrives after connecting.
     Updates from both app-originated (`setVolume`) and device-originated events.
     */
    var deviceData: AsyncStream<DeviceData?> { get }

    /// A snapshot of the current `connectionState` value.
    var currentConnectionState: ConnectionState { get }
    /// A snapshot of the current `deviceData` value.
    var currentDeviceData: DeviceData? { get }

    /**
     Initiates a connection to the device with the given ID.
     No-op if already `.connecting` or `.connected`.
     Suspends until the transport has processed the connect request.
     */
    func connect(deviceId: String) async

    /**
     Tears down the connection gracefully.
     No-op if `.idle` or `.failed`.
     Suspends until teardown is complete.
     */
    func disconnect() async

    /**
     Sends a volume command to the connected device.
     - Parameter level: 0..10 inclusive.
     - Returns: success or failure (e.g. if not `.connected`).
     */
    func setVolume(_ level: Int) async -> Result<Void, Error>

    /**
     Releases all internal resources (cancels tasks, etc).
     The connector instance should not be used after calling this.
     */
    func release()
}

public extension DeviceConnector {
    /// Factory — production entry point.
    static func create() -> DeviceConnector {
        DeviceConnectorImpl(transport: MockDeviceTransport())
    }

    /// Test / demo entry point — inject a custom transport.
    static func createWithTransport(_ transport: DeviceTransport) -> DeviceConnector {
        DeviceConnectorImpl(transport: transport)
    }
}
