// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "yls-app",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "yls-app",
            targets: ["yls-app"]
        ),
    ],
    dependencies: [
        .package(url: "https://gh-proxy.com/github.com/gonzalezreal/swift-markdown-ui.git", from: "2.4.1"),
    ],
    targets: [
        .executableTarget(
            name: "yls-app",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            path: "Sources",
            resources: [
                .process("yls-app/Resources"),
            ]
        ),
    ]
)
