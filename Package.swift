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

// The JSON parser converts floating point numbers itself under Embedded
// Swift, so it never needs FoundationEmbedded's `strtod` shims. From Swift
// 6.4 the standard library doesn't reference them either, so the default
// `FloatingPointParsingShims` trait is turned off there. Earlier toolchains
// keep it, for code that calls `Double(String)` itself.
#if compiler(>=6.4)
let foundationEmbedded: Package.Dependency = .package(
    url: "https://github.com/PureSwift/swift-embedded-foundation.git",
    branch: "master",
    traits: []
)
#else
let foundationEmbedded: Package.Dependency = .package(
    url: "https://github.com/PureSwift/swift-embedded-foundation.git",
    branch: "master"
)
#endif

let package = Package(
    name: "JSON",
    // Must match swift-embedded-foundation, which needs these minimums for
    // `UInt128` (its UUID). SwiftPM rejects a library whose dependency
    // requires a newer OS than it does.
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .watchOS(.v11),
        .tvOS(.v18),
        .macCatalyst(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "JSON",
            targets: ["JSON"]
        )
    ],
    dependencies: [
        foundationEmbedded
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
