import Foundation

/**
 Internal commands sent to the `DeviceTransport`.

 Mirrors `com.emildesign.sdk.data.transport.model.DeviceCommand`.
 */
enum DeviceCommand {
    case setVolume(level: Int)
}
