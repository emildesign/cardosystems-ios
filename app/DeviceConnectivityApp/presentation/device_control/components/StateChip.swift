import SwiftUI
import DeviceConnectivitySDK

/**
 Mirrors `com.emildesign.app.presentation.device_control.components.StateChip`.
 */
struct StateChip: View {
    let state: ConnectionState

    private var label: String {
        switch state {
        case .idle: return "Idle"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .disconnecting: return "Disconnecting…"
        case .failed(let reason):
            switch reason {
            case .timeout: return "Failed: Timeout"
            case .unexpectedDisconnect: return "Failed: UnexpectedDisconnect"
            case .consumerDisconnected: return "Failed: ConsumerDisconnected"
            }
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
        Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
    }
}
