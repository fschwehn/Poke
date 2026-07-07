// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Poke",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "Poke", targets: ["Poke"]),
    ],
    targets: [
        .target(name: "Poke"),
        .testTarget(name: "PokeTests", dependencies: ["Poke"]),
    ]
)
