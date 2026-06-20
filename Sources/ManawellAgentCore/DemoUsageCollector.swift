//
//  DemoUsageCollector.swift
//  ManawellAgentCore
//

import ManawellCore

/// A collector that serves `DemoUsageProvider`'s deterministic data. Used to bring the
/// server up and exercise the full pairing/HTTP path before the real Claude collector
/// exists, and as a last-resort fallback so the app always sees *something*.
public struct DemoUsageCollector: UsageCollector {
    public let providerName = "Demo"

    public init() {}

    public func collect() async throws -> [UsageSnapshot] {
        DemoUsageProvider.snapshots()
    }
}
