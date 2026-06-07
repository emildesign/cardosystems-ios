// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeviceConnectivitySDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "DeviceConnectivitySDK",
            targets: ["DeviceConnectivitySDK"]
        )
    ],
    targets: [
        .target(
            name: "DeviceConnectivitySDK",
            path: "Sources/DeviceConnectivitySDK"
        ),
        .testTarget(
            name: "DeviceConnectivitySDKTests",
            dependencies: ["DeviceConnectivitySDK"],
            path: "Tests/DeviceConnectivitySDKTests"
        )
    ]
)
