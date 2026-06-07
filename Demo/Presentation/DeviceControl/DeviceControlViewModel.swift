// DeviceControlViewModel.swift
import Combine
import DeviceConnectivitySDK
import Foundation

@MainActor
final class DeviceControlViewModel: ObservableObject {
    @Published var deviceIdInput: String = "mock-device-01"
    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var deviceData: DeviceData? = nil

    private let connector: any DeviceConnector
    private var cancellables = Set<AnyCancellable>()

    init(connector: (any DeviceConnector)? = nil) {
        self.connector = connector ?? DeviceConnector.create()
        self.connector.connectionState.receive(on: DispatchQueue.main).assign(to: &$connectionState)
        self.connector.deviceData.receive(on: DispatchQueue.main).assign(to: &$deviceData)
    }

    func connect() { Task { await connector.connect(deviceId: deviceIdInput) } }
    func disconnect() { Task { await connector.disconnect() } }
    func setVolume(_ level: Int) { Task { await connector.setVolume(level: level) } }
    deinit { connector.release() }
}
