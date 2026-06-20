// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "manawell-agent",
    platforms: [
        .macOS(.v14), // Hummingbird 2 requires macOS 14+
    ],
    products: [
        .library(name: "ManawellAgentCore", targets: ["ManawellAgentCore"]),
        .executable(name: "manawell-agentd", targets: ["manawell-agentd"]),
    ],
    dependencies: [
        .package(path: "../AetherriteKit"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/fwcd/swift-qrcode-generator.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "ManawellAgentCore",
            dependencies: [
                .product(name: "ManawellCore", package: "AetherriteKit"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "QRCodeGenerator", package: "swift-qrcode-generator"),
            ]
        ),
        .executableTarget(
            name: "manawell-agentd",
            dependencies: ["ManawellAgentCore"]
        ),
        .executableTarget(
            name: "manawell-menubar",
            dependencies: [
                "ManawellAgentCore",
                .product(name: "ManawellCore", package: "AetherriteKit"),
            ]
        ),
        .testTarget(
            name: "ManawellAgentCoreTests",
            dependencies: ["ManawellAgentCore"]
        ),
    ]
)
