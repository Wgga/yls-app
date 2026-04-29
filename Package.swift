// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "yls-app",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .executable(
            name: "yls-app",
            targets: ["YLSMacOSApp"]
        ),
        .library(
            name: "YLSiOSApp",
            targets: ["YLSiOSApp"]
        ),
        .library(
            name: "YLSShared",
            targets: ["YLSShared"]
        ),
        .library(
            name: "YLSSharedUI",
            targets: ["YLSSharedUI"]
        ),
    ],
    targets: [
        .target(
            name: "YLSShared",
            path: "Sources/YLSShared"
        ),
        .target(
            name: "YLSSharedUI",
            dependencies: ["YLSShared"],
            path: "Sources/YLSSharedUI"
        ),
        .executableTarget(
            name: "YLSMacOSApp",
            dependencies: ["YLSShared", "YLSSharedUI"],
            path: "Sources/YLSMacOSApp",
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "YLSiOSApp",
            dependencies: ["YLSShared", "YLSSharedUI"],
            path: "Sources/YLSiOSApp"
        ),
    ]
)
