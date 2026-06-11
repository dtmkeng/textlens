// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TextLens",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", exact: "1.9.4")
    ],
    targets: [
        .executableTarget(
            name: "TextLens",
            dependencies: [
                "KeyboardShortcuts"
            ],
            path: "Sources/TextLens"
        )
    ]
)
