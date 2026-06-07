import Foundation

/**
 Internal events emitted by the `DeviceTransport`.

 Mirrors `com.emildesign.sdk.data.transport.model.TransportEvent`.
 */
enum TransportEvent {
    case connected
    case disconnected(DisconnectReason)
    case dataUpdate(DeviceData)
}
