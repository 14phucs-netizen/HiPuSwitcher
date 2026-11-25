// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HiPuLauncher",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.16.0"),
        .package(url: "https://github.com/krisk/fuse-swift.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "HiPuShared",
            dependencies: [
                "KeyboardShortcuts"
            ],
            path: "Sources/HiPuShared"
        ),
        .executableTarget(
            name: "HiPuSwitcher",
            dependencies: [
                "HiPuShared",
                "KeyboardShortcuts",
                .product(name: "Fuse", package: "fuse-swift")
            ],
            path: "Sources/HiPuSwitcher",
            resources: [
                .process("Shared/Resources")
            ]
        ),
        .testTarget(
            name: "HiPuSwitcherTests",
            dependencies: ["HiPuSwitcher"],
            path: "Tests/HiPuSwitcherTests"
        )
    ]
)
