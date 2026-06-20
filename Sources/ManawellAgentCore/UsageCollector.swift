//
//  UsageCollector.swift
//  ManawellAgentCore
//

import ManawellCore

/// A source of usage data for one provider. Each provider (Claude, later GPT/Gemini)
/// gets its own collector; the agent fans out across all registered collectors and
/// merges their snapshots. Adding a provider = adding a `UsageCollector` — the server
/// and cache never change.
///
/// A `collect()` may return more than one snapshot (e.g. Claude returns both the
/// "5h session" and "Weekly cap" windows).
public protocol UsageCollector: Sendable {
    /// Stable name for logs/diagnostics, e.g. "Claude".
    var providerName: String { get }

    /// Fetch the latest snapshots for this provider. Throwing means "no fresh data
    /// this cycle" — the cache keeps serving the last good values rather than failing
    /// the request.
    func collect() async throws -> [UsageSnapshot]
}
