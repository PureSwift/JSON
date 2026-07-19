// swift-tools-version: 6.1
import PackageDescription
import CompilerPluginSupport
import class Foundation.ProcessInfo

// get environment variables
let environment = ProcessInfo.processInfo.environment
let enableMacros = environment["SWIFTPM_ENABLE_MACROS"] != "0"
// the macro expansion tests use swift-syntax host tooling and cannot be
// cross-compiled for Android (fully compiled-out test files break the
// index store during test discovery)
let android = environment["TARGET_OS_ANDROID"] == "1"

let package = Package(
    name: "JSON",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "JSON",
            targets: ["JSON"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/PureSwift/swift-embedded-foundation.git",
            branch: "master"
        )
    ],
    targets: [
        .target(
            name: "JSON",
            dependencies: [
                .product(
                    name: "FoundationEmbedded",
                    package: "swift-embedded-foundation"
                )
            ]
        ),
        .testTarget(
            name: "JSONTests",
            dependencies: ["JSON"]
        )
    ],
    swiftLanguageModes: [.v6]
)

if enableMacros {
    let version: Version
    #if swift(>=6.3)
    version = "603.0.1"
    #elseif swift(>=6.2)
    version = "602.0.0"
    #else
    version = "601.0.1"
    #endif
    package.dependencies += [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: version
        )
    ]
    package.targets[0].dependencies += [
        "JSONMacros"
    ]
    package.targets[0].swiftSettings = [
        .define("SWIFTPM_ENABLE_MACROS")
    ]
    package.targets[1].swiftSettings = [
        .define("SWIFTPM_ENABLE_MACROS")
    ]
    package.targets += [
        .macro(
            name: "JSONMacros",
            dependencies: [
                .product(
                    name: "SwiftSyntaxMacros",
                    package: "swift-syntax"
                ),
                .product(
                    name: "SwiftCompilerPlugin",
                    package: "swift-syntax"
                )
            ]
        )
    ]
    if android == false {
        package.targets += [
            .testTarget(
                name: "JSONMacrosTests",
                dependencies: [
                    "JSONMacros",
                    .product(
                        name: "SwiftSyntaxMacros",
                        package: "swift-syntax"
                    ),
                    .product(
                        name: "SwiftSyntaxMacroExpansion",
                        package: "swift-syntax"
                    ),
                    .product(
                        name: "SwiftParser",
                        package: "swift-syntax"
                    ),
                    .product(
                        name: "SwiftSyntaxMacrosTestSupport",
                        package: "swift-syntax"
                    )
                ]
            )
        ]
    }
}
