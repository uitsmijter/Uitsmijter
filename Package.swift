// swift-tools-version:6.2

import PackageDescription

let package = Package(
        name: "Uitsmijter",
        platforms: [
            .macOS(.v15)
        ],
        products: [
            .executable(name: "Uitsmijter", targets: ["Uitsmijter"])
        ],
        dependencies: [
            .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
            .package(url: "https://github.com/vapor/vapor.git", from: "4.106.1"),
            .package(url: "https://github.com/vapor/redis.git", from: "4.0.0"),
            .package(url: "https://github.com/vapor/leaf.git", from: "4.0.0"),
            .package(url: "https://github.com/vapor/jwt.git", from: "4.1.0"),
            .package(url: "https://github.com/swift-server-community/SwiftPrometheus.git", from: "1.0.0-alpha"),
            .package(url: "https://github.com/aus-der-Technik/JXKit.git", branch: "main"),
            .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", .upToNextMajor(from: "1.6.0")),
            .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.1"),
            .package(url: "https://github.com/soto-project/soto.git", from: "6.0.0"),
            .package(url: "https://github.com/swiftkube/client.git", from: "0.15.0"),
            .package(url: "https://github.com/aus-der-Technik/FileMonitor.git", from: "1.2.1"),
            .package(url: "https://github.com/DimaRU/PackageBuildInfo", from: "1.0.4"),
            .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.9.0"),
            .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        ],

        targets: [
            .target(
                    name: "FoundationExtensions",
                    dependencies: [
                        
                    ],
                    swiftSettings: [
                        .unsafeFlags(["-warnings-as-errors"])
                    ],
                    plugins: []
            ),
            .target(
                    name: "Logger",
                    dependencies: [
                        .target(name: "FoundationExtensions"),
                        .product(name: "Logging", package: "swift-log"),
                    ],
                    swiftSettings: [
                        .unsafeFlags(["-warnings-as-errors"])
                    ],
                    plugins: []
            ),
            .target(
                    name: "Uitsmijter-AuthServer",
                    dependencies: [
                        .target(name: "FoundationExtensions"),
                        .target(name: "Logger"),
                        "JXKit",
                        .product(name: "AsyncHTTPClient", package: "async-http-client"),
                        .product(name: "Vapor", package: "vapor"),
                        .product(name: "Redis", package: "redis"),
                        .product(name: "Leaf", package: "leaf"),
                        .product(name: "JWT", package: "jwt"),
                        "CryptoSwift",
                        .product(name: "SotoS3", package: "soto"),
                        "SwiftPrometheus",
                        "Yams",
                        .product(name: "SwiftkubeClient", package: "client"),
                        .product(name: "FileMonitor", package: "FileMonitor"),
                    ],
                    swiftSettings: [
                        // Enable better optimizations when building in Release configuration. Despite the use of
                        // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                        // builds. See
                        // <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production>
                        // for details.
                        .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
                        .unsafeFlags(["-warnings-as-errors"])
                    ],
                    plugins: [
                        .plugin(name: "PackageBuildInfoPlugin", package: "PackageBuildInfo")
                    ]
            ),
            
            // TESTS
            .testTarget(name: "FoundationExtensionsTests", dependencies: [
                .target(name: "FoundationExtensions"),
            ]),
            .testTarget(name: "LoggerTests", dependencies: [
                .target(name: "Logger"),
            ]),
            .testTarget(name: "Uitsmijter-AuthServerTests", dependencies: [
                .target(name: "Uitsmijter-AuthServer"),
                .product(name: "VaporTesting", package: "vapor"),
            ], exclude: ["Entities/Loader/Stubs"]),

            // EXECUTE
            .executableTarget(
                    name: "Uitsmijter",
                    dependencies: [
                        .target(name: "Uitsmijter-AuthServer")
                    ],
                    plugins: []
            )
        ]
)
