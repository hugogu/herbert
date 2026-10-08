// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Herbert",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HerbertCore", targets: ["HerbertCore"]),
        .library(name: "HerbertCommunity", targets: ["HerbertCommunity"]),
    ],
    targets: [
        .target(name: "HerbertCore", resources: [.process("Resources")]),
        .target(name: "HerbertCommunity", dependencies: ["HerbertCore"], resources: [.process("Resources")]),
        .testTarget(
            name: "HerbertCoreTests", dependencies: ["HerbertCore", "HerbertCommunity"],
            resources: [.process("Fixtures")]),
    ]
)
