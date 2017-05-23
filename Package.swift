// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "git",
    targets: [
        Target(name: "Git", dependencies: ["GitRuntime"]),
        Target(name: "GitRuntime", dependencies: [])
    ]
)
