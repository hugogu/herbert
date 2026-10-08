// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Herbert",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HerbertCore", targets: ["HerbertCore"]),
        .library(name: "HerbertCommunity", targets: ["HerbertCommunity"]),
        .library(name: "HerbertBattlefield", targets: ["HerbertBattlefield"]),
    ],
    targets: [
        .target(name: "HerbertCore", resources: [.process("Resources")]),
        .target(name: "HerbertCommunity", dependencies: ["HerbertCore"], resources: [.process("Resources")]),
        .target(name: "HerbertBattlefield", dependencies: ["HerbertCore"]),
        .testTarget(name: "HerbertBattlefieldTests", dependencies: ["HerbertBattlefield"]),
        .testTarget(
            name: "HerbertCoreTests", dependencies: ["HerbertCore", "HerbertCommunity"],
            resources: [.process("Fixtures")]),
    ]
)
