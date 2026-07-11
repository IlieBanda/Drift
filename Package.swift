// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Swarm",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Swarm", targets: ["Swarm"])],
    targets: [
        .executableTarget(name: "Swarm", path: "Sources/Swarm"),
        .testTarget(name: "SwarmTests", dependencies: ["Swarm"], path: "Tests/SwarmTests")
    ]
)
