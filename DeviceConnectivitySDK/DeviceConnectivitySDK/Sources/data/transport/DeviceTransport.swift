// DeviceTransport.swift
protocol DeviceTransport {
    var events: AsyncStream<TransportEvent> { get }
    func connect(deviceId: String) async
    func disconnect() async
    func sendCommand(_ command: DeviceCommand) async
}
