import SwiftUI
import DeviceConnectivitySDK

/**
 Mirrors `com.emildesign.app.presentation.device_control.DeviceControlScreen`.
 */
struct DeviceControlScreen: View {
    @StateObject private var viewModel = DeviceControlViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Device Control")
                    .font(.title2.weight(.semibold))
                Text("Connectivity SDK — sample app")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Device ID", text: Binding(
                    get: { viewModel.deviceIdInput },
                    set: { viewModel.updateDeviceIdInput($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .disabled(!viewModel.isDeviceIdEditingEnabled)

                ConnectionCard(
                    deviceId: viewModel.deviceIdInput,
                    state: viewModel.connectionStateSnapshot,
                    onConnect: { viewModel.connect() },
                    onDisconnect: { viewModel.disconnect() }
                )

                BatteryCard(deviceData: viewModel.deviceDataSnapshot)

                VolumeCard(
                    deviceData: viewModel.deviceDataSnapshot,
                    isConnected: viewModel.isConnected,
                    onVolumeChange: { viewModel.setVolume($0) }
                )
            }
            .padding(16)
        }
    }
}

#Preview {
    DeviceControlScreen()
}
