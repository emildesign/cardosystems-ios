// StateChip.swift
import DeviceConnectivitySDK
import SwiftUI
struct StateChip: View {
    let state: ConnectionState
    private var label: String {
        switch state {
        case .idle: return "Idle"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting…"
        case .failed(let r): return "Failed: \(r)"
        }
    }
    private var color: Color {
        switch state {
        case .idle: return .gray
        case .connecting, .disconnecting: return .orange
        case .connected: return .green
        case .failed: return .red
        }
    }
    var body: some View {
        Text(label).font(.caption.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.15)).foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
