// swift-tools-version:3.1

import PackageDescription

let package = Package(
    name: "git",
    targets: [
        Target(name: "GitExec", dependencies: ["GitRuntime"]),
        Target(name: "GitRuntime", dependencies: [])
    ]
)
