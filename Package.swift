// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "build-settings-police",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "build-settings-police", targets: ["BuildSettingsPolice"]),
        .library(name: "BuildSettingsPoliceCore", targets: ["BuildSettingsPoliceCore"]),
        .library(name: "XCConfigKit", targets: ["XCConfigKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/mokagio/XcodeProj-Tuist.git", revision: "4bf86bc0ac775aa67a1ac8d3f6fe7df48259b53d"),
    ],
    targets: [
        .executableTarget(
            name: "BuildSettingsPolice",
            dependencies: [
                "BuildSettingsPoliceCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "BuildSettingsPoliceCore",
            dependencies: [
                "XCConfigKit",
                .product(name: "XcodeProj", package: "XcodeProj-Tuist"),
            ]
        ),
        .target(
            name: "XCConfigKit"
        ),
        .testTarget(
            name: "BuildSettingsPoliceCoreTests",
            dependencies: [
                "BuildSettingsPoliceCore",
                "BuildSettingsPolice",
            ]
        ),
        .testTarget(
            name: "XCConfigKitTests",
            dependencies: [
                "XCConfigKit",
            ]
        ),
        .testTarget(
            name: "XCConfigKitIntegrationTests",
            dependencies: [
                "XCConfigKit",
                .product(name: "XcodeProj", package: "XcodeProj-Tuist"),
            ]
        ),
    ]
)
