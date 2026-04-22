// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ziwf",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "Shared",
            path: "Sources/Shared"
        ),
        .executableTarget(
            name: "Attendance",
            dependencies: ["Shared"],
            path: "Sources/Attendance"
        ),
        .executableTarget(
            name: "Leaves",
            dependencies: ["Shared"],
            path: "Sources/Leaves"
        ),
    ]
)
