import SwiftUI
import DeviceConnectivitySDK

/**
 Mirrors `com.emildesign.app.presentation.device_control.components.ConnectionCard`.
 */
struct ConnectionCard: View {
    let deviceId: String
    let state: ConnectionState
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    private var canConnect: Bool {
        switch state {
        case .idle, .failed: return true
        default: return false
        }
    }
    private var canDisconnect: Bool {
        if case .connected = state { return true } else { return false }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connection").font(.headline)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Device ID").font(.caption2).foregroundStyle(.secondary)
                        Text(deviceId).font(.body)
                    }
                    Spacer()
                    StateChip(state: state)
                }
                HStack(spacing: 8) {
                    Button(action: onConnect) {
                        Text("Connect").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canConnect)

                    Button(role: .destructive, action: onDisconnect) {
                        Text("Disconnect").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canDisconnect)
                }
            }
        }
    }
}
