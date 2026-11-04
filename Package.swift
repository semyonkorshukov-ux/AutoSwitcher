// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AutoSwitcher",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "AutoSwitcherCore",
            resources: [.copy("Resources")]
        ),
        .executableTarget(
            name: "AutoSwitcher",
            dependencies: ["AutoSwitcherCore"]
        ),
        .executableTarget(
            name: "TestsRunner",
            dependencies: ["AutoSwitcherCore"]
        )
    ]
)
