// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ayllu",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AylluCore",
            targets: ["AylluCore"]
        ),
    ],
    dependencies: [
        // Database - GRDB for SQLite with full SQL control, migrations, offline reliability
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),

        // Coordinate Transforms (UTM)
        .package(url: "https://github.com/wtw-software/UTMConversion.git", from: "1.4.0"),

        // GPX Export
        .package(url: "https://github.com/vincentneo/CoreGPX.git", from: "0.9.0"),

        // Maps - MapLibre for offline tile support
        .package(url: "https://github.com/maplibre/maplibre-gl-native-distribution.git", from: "6.0.0"),

        // Snapshot Testing for UI tests
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.15.0"),
    ],
    targets: [
        .target(
            name: "AylluCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "UTMConversion", package: "UTMConversion"),
                .product(name: "CoreGPX", package: "CoreGPX"),
                .product(name: "MapLibre", package: "maplibre-gl-native-distribution"),
            ],
            path: "Ayllu/Core"
        ),
        .testTarget(
            name: "AylluTests",
            dependencies: [
                "AylluCore",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "AylluTests"
        ),
    ]
)
