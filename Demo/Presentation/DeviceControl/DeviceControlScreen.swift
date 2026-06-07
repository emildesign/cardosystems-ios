// DeviceControlScreen.swift
import DeviceConnectivitySDK
import SwiftUI
struct DeviceControlScreen: View {
    @StateObject private var viewModel = DeviceControlViewModel()
    private var isConnected: Bool { if case .connected = viewModel.connectionState { return true }; return false }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Device Control").font(.largeTitle.bold())
                Text("Connectivity SDK — sample app").font(.caption).foregroundStyle(.secondary)
                TextField("Device ID", text: $viewModel.deviceIdInput).textFieldStyle(.roundedBorder)
                ConnectionCard(deviceId: viewModel.deviceIdInput, state: viewModel.connectionState,
                    onConnect: { viewModel.connect() }, onDisconnect: { viewModel.disconnect() })
                BatteryCard(deviceData: viewModel.deviceData)
                VolumeCard(deviceData: viewModel.deviceData, isConnected: isConnected,
                    onVolumeChange: { viewModel.setVolume($0) })
            }.padding(16)
        }
    }
}
