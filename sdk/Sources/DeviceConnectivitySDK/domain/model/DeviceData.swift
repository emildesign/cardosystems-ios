import Foundation

/**
 Data received from the device.

 Mirrors `com.emildesign.sdk.domain.model.DeviceData`.
 */
public struct DeviceData: Equatable {
    /// 0..10
    public let volume: Int
    /// 0..100
    public let battery: Int

    public init(volume: Int, battery: Int) {
        self.volume = volume
        self.battery = battery
    }
}
