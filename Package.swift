// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "mottzi",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.110.1"),
        .package(url: "https://github.com/vapor/leaf.git", from: "4.4.0"),
        //.package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        //.package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.29.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Leaf", package: "leaf"),
                //.product(name: "NIOCore", package: "swift-nio"),
                //.product(name: "NIOSSL", package: "swift-nio-ssl"),
            ],
            swiftSettings: swiftSettings
        ),
    ],
    swiftLanguageModes: [.v5]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("DisableOutwardActorInference"),
    .enableExperimentalFeature("StrictConcurrency"),
] }
