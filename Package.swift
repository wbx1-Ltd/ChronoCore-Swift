// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ChronoCore",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "ChronoCore", targets: ["ChronoCore"]),
        .library(name: "ChronoCoreFoundation", targets: ["ChronoCoreFoundation"]),
        .library(name: "ChronoCoreTables", targets: ["ChronoCoreTables"]),
        .library(name: "ChronoCoreAstronomy", targets: ["ChronoCoreAstronomy"]),
        .library(name: "ChronoCoreLunarCoreAdapter", targets: ["ChronoCoreLunarCoreAdapter"]),
        .library(name: "ChronoCoreTesting", targets: ["ChronoCoreTesting"])
    ],
    dependencies: [
        .package(url: "https://github.com/wbx1-Ltd/LunarCore-Swift.git", from: "1.2.0"),
        .package(url: "https://github.com/wbx1-Ltd/AstroCore-Swift.git", from: "2.0.0")
    ],
    targets: [
        // Pure core: value types, engine protocol, registry, Gregorian engine.
        .target(name: "ChronoCore"),

        // Availability-gated Foundation providers (Hebrew, Hijri Umm al-Qura).
        .target(
            name: "ChronoCoreFoundation",
            dependencies: ["ChronoCore"]
        ),

        // Table-driven engines (Nepali Bikram Sambat, Bangla).
        .target(
            name: "ChronoCoreTables",
            dependencies: ["ChronoCore"]
        ),

        // Astronomy engines (Korean, Vietnamese lunisolar, Indian Panchanga).
        .target(
            name: "ChronoCoreAstronomy",
            dependencies: [
                "ChronoCore",
                .product(name: "AstroCore", package: "AstroCore-Swift")
            ]
        ),

        // Chinese lunar engine backed by LunarCore.
        .target(
            name: "ChronoCoreLunarCoreAdapter",
            dependencies: [
                "ChronoCore",
                .product(name: "LunarCore", package: "LunarCore-Swift")
            ]
        ),

        // Test support: fixture schema, loader, parity and range helpers.
        .target(
            name: "ChronoCoreTesting",
            dependencies: ["ChronoCore"]
        ),

        // Single cohesive test target across all layers, with golden fixtures.
        .testTarget(
            name: "ChronoCoreTests",
            dependencies: [
                "ChronoCore",
                "ChronoCoreFoundation",
                "ChronoCoreTables",
                "ChronoCoreAstronomy",
                "ChronoCoreLunarCoreAdapter",
                "ChronoCoreTesting"
            ],
            resources: [.process("Fixtures")]
        )
    ]
)
