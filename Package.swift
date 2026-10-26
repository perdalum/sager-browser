// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SagerBrowser",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "SagerBrowser",
            path: "Sources/SagerBrowser"
        )
    ]
)
