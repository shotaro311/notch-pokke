// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HoverPocket",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HoverPocket", targets: ["HoverPocket"])
    ],
    targets: [
        .executableTarget(
            name: "HoverPocket",
            path: "Sources/HoverPocket"
        )
    ]
)
