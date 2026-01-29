// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "VoiceEverywhere",
    platforms: [.macOS(.v13)],
    products: [
        .executable(
            name: "VoiceEverywhere",
            targets: ["VoiceEverywhere"]
        )
    ],
    targets: [
        .executableTarget(
            name: "VoiceEverywhere",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("Carbon")
            ]
        )
    ]
)
