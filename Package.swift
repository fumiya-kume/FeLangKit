// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FeLangKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "FeLangCore", targets: ["FeLangCore"]),
        .library(name: "FeLangKit", targets: ["FeLangKit"]),
        .library(name: "FeLangRuntime", targets: ["FeLangRuntime"]),
        .library(name: "FeLangServer", targets: ["FeLangServer"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.5.0")
    ],
    targets: [
        .target(
            name: "FeLangCore",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing")
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
                "FeLangCore"
            ]
        ),
        .target(
            name: "FeLangServer",
            dependencies: [
                "FeLangCore",
                "FeLangKit"
            ]
        ),
        .testTarget(
            name: "FeLangCoreTests",
            dependencies: [
                "FeLangCore",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
        .testTarget(
            name: "FeLangKitTests",
            dependencies: [
                "FeLangKit",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
        .testTarget(
            name: "FeLangRuntimeTests",
            dependencies: [
                "FeLangRuntime",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
        .testTarget(
            name: "FeLangServerTests",
            dependencies: [
                "FeLangServer",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
