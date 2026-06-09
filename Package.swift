// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NotchPocket",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NotchPocket", targets: ["NotchPocket"])
    ],
    targets: [
        .executableTarget(
            name: "NotchPocket",
            path: "Sources/HoverMenuPreview"
        )
    ]
)
