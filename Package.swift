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
        ),
        .library(
            name: "LoggerPrint",
            targets: ["LoggerPrint"]
        ),
        .library(
            name: "LoggerFiltering",
            targets: ["LoggerFiltering"]
        )
    ],
    targets: [
        .target(name: "Loggers"),
        .target(
            name: "LoggerPrint",
            dependencies: ["Loggers"]
        ),
        .target(
            name: "LoggerFiltering",
            dependencies: ["Loggers"]
        ),
        .testTarget(
            name: "LoggersTests",
            dependencies: ["Loggers"]
        ),
        .testTarget(
            name: "LoggerPrintTests",
            dependencies: ["LoggerPrint", "Loggers"]
        ),
        .testTarget(
            name: "LoggerFilteringTests",
            dependencies: ["LoggerFiltering", "Loggers"]
        )
    ]
)
