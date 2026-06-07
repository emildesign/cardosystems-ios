import SwiftUI
import DeviceConnectivitySDK

/**
 Equivalent of `com.emildesign.app.MainActivity`.
 The `@main` attribute replaces the Android `LAUNCHER` intent-filter entry point.
 */
@main
struct DeviceConnectivityAppApp: App {
    var body: some Scene {
        WindowGroup {
            DeviceControlScreen()
        }
    }
}
