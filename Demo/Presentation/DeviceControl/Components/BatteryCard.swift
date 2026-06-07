// BatteryCard.swift
import DeviceConnectivitySDK
import SwiftUI
struct BatteryCard: View {
    let deviceData: DeviceData?
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Battery").font(.headline)
                    Spacer()
                    Text("device-originated").font(.caption).foregroundStyle(.secondary)
                }
                let battery = deviceData?.battery ?? 0
                HStack(spacing: 8) {
                    ProgressView(value: Double(battery), total: 100)
                        .tint(battery > 20 ? Color(red: 0.298, green: 0.686, blue: 0.314) : .red)
                        .frame(maxWidth: .infinity)
                    Text("\(battery)%").font(.body.bold())
                }
            }
        }
    }
}
