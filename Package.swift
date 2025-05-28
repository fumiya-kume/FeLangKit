// swift-tools-version:6.0
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
        .package(url: "https://github.com/pointfreeco/swift-parsing.git", from: "0.5.0")
    ],
    targets: [
        .target(
            name: "FeLangCore",
            dependencies: [
                .product(name: "Parsing", package: "swift-parsing")
            ],
            exclude: [
                "Tokenizer/docs",
                "Expression/docs", 
                "Parser/docs",
                "Utilities/docs",
                "Visitor/docs"
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
            ]
        ),
        .testTarget(
            name: "FeLangServerTests",
            dependencies: [
                "FeLangServer"
            ]
        )
    ]
)
