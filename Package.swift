// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "MinecraftFriendsKit",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "MinecraftFriendsKit", targets: ["MinecraftFriendsKit"]),
    ],
    targets: [
        .target(
            name: "MinecraftFriendsKit",
            path: "Sources/MinecraftFriendsKit",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MinecraftFriendsKitTests",
            dependencies: ["MinecraftFriendsKit"],
            path: "Tests/MinecraftFriendsKitTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
