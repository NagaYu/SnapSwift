// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SnapSwift",
    platforms: [
        // FoundationModels requires macOS 26 (Tahoe) or later.
        .macOS("26.0")
    ],
    products: [
        // The shared core engine, usable from both the CLI and the GUI app.
        .library(name: "SnapSwiftKit", targets: ["SnapSwiftKit"]),
        // The command-line tool.
        .executable(name: "snapswift", targets: ["snapswift"]),
        // The macOS desktop app.
        .executable(name: "SnapSwiftApp", targets: ["SnapSwiftApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        // MARK: - Shared core
        .target(
            name: "SnapSwiftKit"
        ),

        // MARK: - CLI
        .executableTarget(
            name: "snapswift",
            dependencies: [
                "SnapSwiftKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // MARK: - GUI (macOS app)
        .executableTarget(
            name: "SnapSwiftApp",
            dependencies: ["SnapSwiftKit"]
        ),

        // MARK: - Tests
        .testTarget(
            name: "SnapSwiftKitTests",
            dependencies: ["SnapSwiftKit"]
        ),
    ]
)
