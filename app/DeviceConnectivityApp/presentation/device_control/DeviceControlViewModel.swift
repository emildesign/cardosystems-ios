import Foundation
import DeviceConnectivitySDK

/**
 Mirrors `com.emildesign.app.presentation.device_control.DeviceControlViewModel`.
 */
@MainActor
final class DeviceControlViewModel: ObservableObject {

    @Published var deviceIdInput: String = "mock-device-01"
    @Published private(set) var connectionState: ConnectionState = .idle
    @Published private(set) var deviceData: DeviceData? = nil

    private let connector: DeviceConnector
    private var stateTask: Task<Void, Never>?
    private var dataTask: Task<Void, Never>?

    var connectionStateSnapshot: ConnectionState { connectionState }
    var deviceDataSnapshot: DeviceData? { deviceData }
    var isConnected: Bool {
        if case .connected = connectionState { return true } else { return false }
    }
    var isDeviceIdEditingEnabled: Bool {
        switch connectionState {
        case .idle, .failed: return true
        default: return false
        }
    }

    init(connector: DeviceConnector = DeviceConnector.create()) {
        self.connector = connector
        startObserving()
    }

    deinit {
        stateTask?.cancel()
        dataTask?.cancel()
        connector.release()
    }

    func updateDeviceIdInput(_ newValue: String) {
        deviceIdInput = newValue
    }

    func connect() {
        Task {
            await connector.connect(deviceId: deviceIdInput)
        }
    }

    func disconnect() {
        Task {
            await connector.disconnect()
        }
    }

    func setVolume(_ level: Int) {
        Task {
            _ = await connector.setVolume(level)
        }
    }

    private func startObserving() {
        stateTask = Task { [weak self] in
            guard let self = self else { return }
            for await state in self.connector.connectionState {
                self.connectionState = state
            }
        }
        dataTask = Task { [weak self] in
            guard let self = self else { return }
            for await data in self.connector.deviceData {
                self.deviceData = data
            }
        }
    }
}
