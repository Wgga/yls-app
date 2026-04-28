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
    targets: [
        .executableTarget(
            name: "yls-app",
            path: "Sources",
            resources: [
                .process("yls-app/Resources"),
            ]
        ),
    ]
)
