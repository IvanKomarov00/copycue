// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CopyCue",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CopyCue", targets: ["CopyCue"])
    ],
    targets: [
        .target(name: "CopyCueCore"),
        .executableTarget(
            name: "CopyCue",
            dependencies: ["CopyCueCore"]
        ),
        .testTarget(
            name: "CopyCueCoreTests",
            dependencies: ["CopyCueCore"]
        )
    ]
)
