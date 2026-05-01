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
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "9.9.0"),
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
                .product(name: "XcodeProj", package: "XcodeProj"),
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
                .product(name: "XcodeProj", package: "XcodeProj"),
            ]
        ),
    ]
)
