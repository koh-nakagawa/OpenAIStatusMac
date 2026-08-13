// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenAIStatusCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "OpenAIStatusCore", targets: ["OpenAIStatusCore"]),
        .executable(name: "StatusVerifier", targets: ["StatusVerifier"])
    ],
    targets: [
        .target(
            name: "OpenAIStatusCore",
            path: "OpenAIStatus/Shared"
        ),
        .executableTarget(
            name: "StatusVerifier",
            dependencies: ["OpenAIStatusCore"],
            path: "Verification"
        ),
        .testTarget(
            name: "OpenAIStatusCoreTests",
            dependencies: ["OpenAIStatusCore"],
            path: "Tests/OpenAIStatusCoreTests"
        )
    ]
)
