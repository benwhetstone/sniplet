// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sniplet",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "Sniplet", targets: ["Snipboard"]),
    ],
    targets: [
        .executableTarget(
            name: "Snipboard"
        ),
        .testTarget(
            name: "SnipboardTests",
            dependencies: ["Snipboard"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
