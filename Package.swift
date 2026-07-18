// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "JSON",
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
