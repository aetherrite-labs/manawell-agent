// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "manawell-agent",
    platforms: [
        .macOS(.v14), // Hummingbird 2 requires macOS 14+
    ],
    products: [
        // The usage-reading layer: collectors + cache, no server dependencies. The macOS
        // app links this to show its own usage even when it isn't serving other devices.
        .library(name: "ManawellUsageCollectors", targets: ["ManawellUsageCollectors"]),
        // The serving layer: the Hummingbird HTTP surface + QR pairing, built on top of
        // (and re-exporting) the collectors. The macOS app links this when "host" mode is
        // on; the headless agentd links it too.
        .library(name: "ManawellAgentServer", targets: ["ManawellAgentServer"]),
        // Headless agent for running on another host.
        .executable(name: "manawell-agentd", targets: ["manawell-agentd"]),
        // Stopgap AppKit menu-bar host — superseded by the macOS Manawell app once it
        // embeds ManawellAgentServer; kept building until that target lands.
        .executable(name: "manawell-menubar", targets: ["manawell-menubar"]),
    ],
    dependencies: [
        .package(path: "../AetherriteKit"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/fwcd/swift-qrcode-generator.git", from: "2.0.0"),
    ],
    targets: [
        // Reads provider usage (Claude, demo) into the shared UsageSnapshot contract.
        // Foundation + ManawellCore only — deliberately free of server dependencies.
        .target(
            name: "ManawellUsageCollectors",
            dependencies: [
                .product(name: "ManawellCore", package: "AetherriteKit"),
            ]
        ),
        // HTTP server + bearer auth + QR pairing. Depends on the collectors and the
        // networking stack.
        .target(
            name: "ManawellAgentServer",
            dependencies: [
                "ManawellUsageCollectors",
                .product(name: "ManawellCore", package: "AetherriteKit"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "QRCodeGenerator", package: "swift-qrcode-generator"),
            ]
        ),
        .executableTarget(
            name: "manawell-agentd",
            dependencies: [
                "ManawellAgentServer",
                .product(name: "ManawellCore", package: "AetherriteKit"),
            ]
        ),
        .executableTarget(
            name: "manawell-menubar",
            dependencies: [
                "ManawellAgentServer",
                .product(name: "ManawellCore", package: "AetherriteKit"),
            ]
        ),
        .testTarget(
            name: "ManawellUsageCollectorsTests",
            dependencies: ["ManawellUsageCollectors"]
        ),
        .testTarget(
            name: "ManawellAgentServerTests",
            dependencies: ["ManawellAgentServer"]
        ),
    ]
)
