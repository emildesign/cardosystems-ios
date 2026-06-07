import Foundation

/**
 Represents reasons why a device might be disconnected.

 Mirrors `com.emildesign.sdk.domain.model.DisconnectReason`.
 */
public enum DisconnectReason: Equatable {
    case timeout
    case unexpectedDisconnect
    case consumerDisconnected
}
