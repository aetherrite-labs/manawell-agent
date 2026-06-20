//
//  AgentConfiguration.swift
//  ManawellAgentCore
//

import Foundation

/// Runtime configuration for the agent's HTTP server.
public struct AgentConfiguration: Sendable {
    /// Address the server binds to. Defaults to loopback for safe local testing;
    /// the menu-bar app will bind `0.0.0.0` so the phone can reach it over Tailscale/LAN.
    public var bindHost: String
    /// TCP port to listen on.
    public var port: Int
    /// Shared secret the phone must present as `Authorization: Bearer <secret>`.
    public var bearerSecret: String

    public init(bindHost: String = "127.0.0.1", port: Int = 8787, bearerSecret: String) {
        self.bindHost = bindHost
        self.port = port
        self.bearerSecret = bearerSecret
    }

    /// Generates a URL-safe random secret suitable for bearer auth / QR pairing.
    public static func makeBearerSecret() -> String {
        let bytes = (0..<32).map { _ in UInt8.random(in: 0...255) }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
