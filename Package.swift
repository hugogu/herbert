// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Herbert",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "HerbertCore", targets: ["HerbertCore"])],
    targets: [
        .target(name: "HerbertCore", resources: [.process("Resources")]),
        .testTarget(name: "HerbertCoreTests", dependencies: ["HerbertCore"]),
    ]
)
