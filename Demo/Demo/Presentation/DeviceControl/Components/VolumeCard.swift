// VolumeCard.swift
import DeviceConnectivitySDK
import SwiftUI
struct VolumeCard: View {
    let deviceData: DeviceData?
    let isConnected: Bool
    let onVolumeChange: (Int) -> Void
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Volume").font(.headline)
                    Spacer()
                    Text("app + device originated").font(.caption).foregroundStyle(.secondary)
                }
                let volume = deviceData?.volume ?? 0
                Text("\(volume) /10").font(.system(size: 34, weight: .regular))
                Slider(value: Binding(get: { Double(volume) }, set: { onVolumeChange(Int($0)) }), in: 0...10, step: 1).disabled(!isConnected)
                HStack {
                    Text("0").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("10").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Button("-") { if volume > 0 { onVolumeChange(volume - 1) } }
                        .buttonStyle(.bordered).disabled(!isConnected || volume == 0).frame(maxWidth: .infinity)
                    Button("Mute") { onVolumeChange(0) }
                        .buttonStyle(.borderedProminent).disabled(!isConnected).frame(maxWidth: .infinity)
                    Button("+") { if volume < 10 { onVolumeChange(volume + 1) } }
                        .buttonStyle(.bordered).disabled(!isConnected || volume == 10).frame(maxWidth: .infinity)
                }
            }
        }
    }
}
