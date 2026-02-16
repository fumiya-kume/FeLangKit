// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FeLangKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v17)
    ],
    products: [
        .library(name: "FeLangCore", type: .static, targets: ["FeLangCore"]),
        .library(name: "FeLangKit", type: .static, targets: ["FeLangKit"]),
        .library(name: "FeLangRuntime", type: .static, targets: ["FeLangRuntime"]),
        .library(name: "FeLangServer", type: .static, targets: ["FeLangServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.5.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "FeLangCABI",
            dependencies: [],
            path: "Sources/FeLangCABI",
            publicHeadersPath: "include"
        ),
        .target(
            name: "FeLangCore",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing")
            ],
            exclude: [
                "Tokenizer/docs",
                "Expression/docs", 
                "Parser/docs",
                "Utilities/docs"
            ]
        ),
        .target(
            name: "FeLangKit",
            dependencies: [
                "FeLangCore",
                "FeLangRuntime"
            ]
        ),
        .target(
            name: "FeLangRuntime",
            dependencies: [
                "FeLangCore",
                "FeLangCABI"
            ]
        ),
        .target(
            name: "FeLangServer",
            dependencies: [
                "FeLangCore",
                "FeLangKit"
            ]
        ),
        .executableTarget(
            name: "felang",
            dependencies: [
                "FeLangCore",
                "FeLangRuntime",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "FeLangCoreTests",
            dependencies: [
                "FeLangCore"
            ],
            resources: [
                .copy("ParseError/GoldenFiles")
            ]
        ),
        .testTarget(
            name: "FeLangKitTests",
            dependencies: [
                "FeLangKit"
            ]
        ),
        .testTarget(
            name: "FeLangRuntimeTests",
            dependencies: [
                "FeLangRuntime"
            ],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "FeLangServerTests",
            dependencies: [
                "FeLangServer"
            ]
        ),
        .testTarget(
            name: "FeLangE2ETests",
            dependencies: [
                "FeLangCore",
                "FeLangRuntime",
                .product(name: "Atomics", package: "swift-atomics")
            ]
        )
    ]
)
