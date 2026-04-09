// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MigraineTrackerQuality",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "MigraineTrackerCore",
            targets: ["MigraineTrackerCore"]
        )
    ],
    targets: [
        .target(
            name: "MigraineTrackerCore",
            path: "MigraineTrackerApp/Sources/Shared"
        ),
        .testTarget(
            name: "MigraineTrackerCoreTests",
            dependencies: ["MigraineTrackerCore"],
            path: "Tests/MigraineTrackerCoreTests"
        )
    ]
)
