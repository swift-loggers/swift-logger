// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-logger",
    platforms: [
        .iOS(.v13),
        .tvOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "Loggers",
            targets: ["Loggers"]
        )
    ],
    targets: [
        .target(name: "Loggers"),
        .testTarget(
            name: "LoggersTests",
            dependencies: ["Loggers"]
        )
    ]
)
