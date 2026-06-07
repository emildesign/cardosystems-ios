import Foundation

/**
 Contract for the communication layer.
 Swap this for a real BLE / Wi-Fi implementation without touching the SDK public surface.

 Mirrors `com.emildesign.sdk.data.transport.DeviceTransport`.
 */
protocol DeviceTransport: AnyObject {
    var events: AsyncStream<TransportEvent> { get }
    func connect(deviceId: String) async
    func disconnect() async
    func sendCommand(_ command: DeviceCommand) async
}
