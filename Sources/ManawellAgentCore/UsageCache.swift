//
//  UsageCache.swift
//  ManawellAgentCore
//

import Foundation
import ManawellCore

/// Throttled, fault-tolerant cache between the collectors and the HTTP server.
///
/// The phone polls `GET /v1/usage` roughly every 30s, but upstream provider endpoints
/// (notably Claude's `/api/oauth/usage`) are themselves rate limited. So the cache
/// fetches at most once per `minRefreshInterval`; every request in between is served
/// from memory. On a collector failure it keeps serving the last good snapshots rather
/// than surfacing an error, and on a cold start where everything fails it falls back to
/// demo data so the app never sees an empty dashboard.
public actor UsageCache {
    private let collectors: [any UsageCollector]
    private let minRefreshInterval: TimeInterval
    private let now: @Sendable () -> Date

    private var cached: [UsageSnapshot] = []
    private var lastFetch: Date?

    public init(
        collectors: [any UsageCollector],
        minRefreshInterval: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.collectors = collectors
        self.minRefreshInterval = minRefreshInterval
        self.now = now
    }

    /// Current snapshots, refreshing first if the cache is stale. Never throws.
    public func snapshots() async -> [UsageSnapshot] {
        if shouldRefresh() {
            await refresh()
        }
        return cached
    }

    /// Force a refresh regardless of the throttle window (used on first launch / manual refresh).
    @discardableResult
    public func refreshNow() async -> [UsageSnapshot] {
        await refresh()
        return cached
    }

    private func shouldRefresh() -> Bool {
        guard let lastFetch else { return true }
        return now().timeIntervalSince(lastFetch) >= minRefreshInterval
    }

    private func refresh() async {
        var collected: [UsageSnapshot] = []
        for collector in collectors {
            do {
                collected.append(contentsOf: try await collector.collect())
            } catch {
                // Keep going; a single provider failing shouldn't blank the others.
                FileHandle.standardError.write(
                    Data("[manawell-agent] collector \(collector.providerName) failed: \(error)\n".utf8))
            }
        }

        if !collected.isEmpty {
            cached = collected.sorted { $0.percentUsed > $1.percentUsed }
            lastFetch = now()
        } else if cached.isEmpty {
            // Cold start with every collector down — serve demo data so the app
            // shows something rather than an empty list.
            cached = DemoUsageProvider.snapshots()
            lastFetch = now()
        }
        // Otherwise: everything failed but we have prior data — keep serving it.
    }
}
