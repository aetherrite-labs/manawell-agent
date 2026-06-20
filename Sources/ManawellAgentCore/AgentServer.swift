//
//  AgentServer.swift
//  ManawellAgentCore
//

import Foundation
import HTTPTypes
import Hummingbird
import ManawellCore
import NIOCore

/// The agent's HTTP surface — two routes:
///
/// - `GET /v1/health`  → `200`, no auth. The phone's pairing/connection-test probe.
/// - `GET /v1/usage`   → bearer-authed JSON array of `UsageSnapshot`, served from `UsageCache`.
public struct AgentServer {
    private let configuration: AgentConfiguration
    private let cache: UsageCache

    public init(configuration: AgentConfiguration, cache: UsageCache) {
        self.configuration = configuration
        self.cache = cache
    }

    public func run() async throws {
        let router = Router()

        router.get("v1/health") { _, _ in
            Response(status: .ok)
        }

        let cache = self.cache
        router.group("v1")
            .add(middleware: BearerAuthMiddleware<BasicRequestContext>(secret: configuration.bearerSecret))
            .get("usage") { _, _ -> Response in
                let snapshots = await cache.snapshots()
                // Fresh encoder per request keeps this Sendable-safe and is cheap at our scale.
                // Default date strategy is intentional: it matches the iOS app's JSONDecoder().
                let data = try JSONEncoder().encode(snapshots)
                var headers = HTTPFields()
                headers[.contentType] = "application/json"
                return Response(
                    status: .ok,
                    headers: headers,
                    body: .init(byteBuffer: ByteBuffer(bytes: data))
                )
            }

        let app = Application(
            router: router,
            configuration: ApplicationConfiguration(
                address: .hostname(configuration.bindHost, port: configuration.port),
                serverName: "manawell-agent"
            )
        )
        try await app.runService()
    }
}
