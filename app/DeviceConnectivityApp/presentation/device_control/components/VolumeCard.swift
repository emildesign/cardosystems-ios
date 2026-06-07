import SwiftUI
import DeviceConnectivitySDK

/**
 Mirrors `com.emildesign.app.presentation.device_control.components.VolumeCard`.
 */
struct VolumeCard: View {
    let deviceData: DeviceData?
    let isConnected: Bool
    let onVolumeChange: (Int) -> Void

    private var volume: Int { deviceData?.volume ?? 0 }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume").font(.headline)
                    Spacer()
                    Text("app + device originated")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("\(volume) /10")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Slider(
                    value: Binding(
                        get: { Double(volume) },
                        set: { onVolumeChange(Int($0.rounded())) }
                    ),
                    in: 0...10,
                    step: 1
                )
                .disabled(!isConnected)
                HStack {
                    Text("0").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("10").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button(action: { onVolumeChange(max(volume - 1, 0)) }) {
                        Text("-").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isConnected || volume <= 0)

                    Button(action: { onVolumeChange(0) }) {
                        Text("Mute").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isConnected)

                    Button(action: { onVolumeChange(min(volume + 1, 10)) }) {
                        Text("+").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!isConnected || volume >= 10)
                }
            }
        }
    }
}
