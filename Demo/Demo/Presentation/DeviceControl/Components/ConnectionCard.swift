// ConnectionCard.swift
import DeviceConnectivitySDK
import SwiftUI
struct ConnectionCard: View {
    let deviceId: String
    let state: ConnectionState
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    private var isConnected: Bool { if case .connected = state { return true }; return false }
    private var canConnect: Bool { switch state { case .idle, .failed: return true; default: return false } }
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connection").font(.headline)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Device ID").font(.caption).foregroundStyle(.secondary)
                        Text(deviceId).font(.body.bold())
                    }
                    Spacer()
                    StateChip(state: state)
                }
                HStack(spacing: 8) {
                    Button("Connect", action: onConnect).buttonStyle(.bordered)
                        .disabled(!canConnect).frame(maxWidth: .infinity)
                    Button("Disconnect", action: onDisconnect).buttonStyle(.bordered).tint(.red)
                        .disabled(!isConnected).frame(maxWidth: .infinity)
                }
            }
        }
    }
}
