//
//  PairingService.swift
//  ManawellAgentCore
//

import Foundation
import ManawellCore

/// Assembles everything the phone needs to pair: resolves the best reachable host and
/// wraps it, the port, and the bearer secret into a `PairingPayload` (the QR contents).
public struct PairingService: Sendable {
    public var deviceName: String
    public var port: Int
    public var bearerSecret: String

    public init(deviceName: String, port: Int, bearerSecret: String) {
        self.deviceName = deviceName
        self.port = port
        self.bearerSecret = bearerSecret
    }

    public struct Result: Sendable {
        public var payload: PairingPayload
        public var host: ResolvedHost
    }

    public func makePairing(run: HostResolver.CommandRunner = HostResolver.runProcess) -> Result {
        let host = HostResolver.resolve(run: run)
        let payload = PairingPayload(
            name: deviceName,
            host: host.host,
            port: port,
            bearerSecret: bearerSecret
        )
        return Result(payload: payload, host: host)
    }
}
