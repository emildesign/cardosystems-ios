import SwiftUI
import DeviceConnectivitySDK

/**
 Mirrors `com.emildesign.app.presentation.device_control.components.BatteryCard`.
 */
struct BatteryCard: View {
    let deviceData: DeviceData?

    private var battery: Int { deviceData?.battery ?? 0 }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Battery").font(.headline)
                    Spacer()
                    Text("device-originated")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ProgressView(value: Double(battery), total: 100)
                        .progressViewStyle(.linear)
                        .tint(battery > 20 ? .green : .red)
                    Text("\(battery)%")
                        .font(.body.monospacedDigit())
                }
            }
        }
    }
}
