import Foundation

/**
 Represents the current state of the device connection.

 Mirrors `com.emildesign.sdk.domain.model.ConnectionState`.
 */
public enum ConnectionState: Equatable {
    case idle
    case connecting
    case connected(deviceId: String)
    case disconnecting
    case failed(reason: DisconnectReason)
}
