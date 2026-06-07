// DeviceData.swift
public struct DeviceData: Equatable {
    public let volume: Int
    public let battery: Int
    public init(volume: Int, battery: Int) {
        self.volume = volume
        self.battery = battery
    }
}
