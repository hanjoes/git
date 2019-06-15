// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SwiftGit",
    products: [
        .library(
            name: "SwiftGitLib",
            targets: ["SwiftGitLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hanjoes/swift-pawn", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwiftGitLib", 
            dependencies: ["SwiftPawn"]),
        .testTarget(
            name: "SwiftGitLibTests",
            dependencies: ["SwiftGitLib"]),
    ]
)
