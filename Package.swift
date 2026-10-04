// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumenMac",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "LumenMac", targets: ["LumenMac"])
    ],
    targets: [
        .target(name: "LumenMacCore"),
        .executableTarget(
            name: "LumenMac",
            dependencies: ["LumenMacCore"]
        ),
        .testTarget(
            name: "LumenMacCoreTests",
            dependencies: ["LumenMacCore"]
        )
    ]
)
