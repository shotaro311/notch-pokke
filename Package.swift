// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HoverMenuPreview",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HoverMenuPreview", targets: ["HoverMenuPreview"])
    ],
    targets: [
        .executableTarget(
            name: "HoverMenuPreview"
        )
    ]
)
