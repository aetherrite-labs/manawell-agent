//
//  ClaudeUsageCollector.swift
//  ManawellAgentCore
//
//  Turns Anthropic's OAuth usage windows into the app's UsageSnapshot contract.
//  five_hour → "5h session", seven_day → "Weekly cap".
//

import Foundation
import ManawellCore

public enum ClaudeCollectorError: LocalizedError {
    case tokenExpired
    case noUsableWindows

    public var errorDescription: String? {
        switch self {
        case .tokenExpired:
            return "Claude token is expired. Run any `claude` command to refresh it, then retry."
        case .noUsableWindows:
            return "Claude usage response contained neither a 5h nor a weekly window."
        }
    }
}

/// Collects real Claude subscription usage. Reads Claude Code's stored OAuth token and
/// calls Anthropic's usage endpoint; maps the two windows the app shows.
///
/// Deliberately does **not** refresh an expired token in v1 — refreshing can rotate the
/// shared refresh token and desync Claude Code itself, so instead we surface a clear
/// "run `claude`" error and pick up the freshened token on the next cycle.
public struct ClaudeUsageCollector: UsageCollector {
    public let providerName = "Claude"

    /// `percentScale` normalizes the endpoint's `utilization` to the app's 0–100 scale.
    /// Confirmed against a live response (see the probe): the field is already 0–100.
    private let percentScale: Double
    private let debug: Bool

    public init(percentScale: Double = 1.0, debug: Bool = false) {
        self.percentScale = percentScale
        self.debug = debug
    }

    public func collect() async throws -> [UsageSnapshot] {
        let credentials = try ClaudeCredentialStore.load()
        guard !credentials.isExpired else { throw ClaudeCollectorError.tokenExpired }

        let usage = try await ClaudeUsageClient.fetchUsage(
            accessToken: credentials.accessToken,
            userAgent: ClaudeCodeVersion.userAgent(),
            debug: debug
        )

        let now = Date()
        let snapshots = [
            snapshot(from: usage.fiveHour, label: "5h session", now: now),
            snapshot(from: usage.sevenDay, label: "Weekly cap", now: now),
        ].compactMap { $0 }

        guard !snapshots.isEmpty else { throw ClaudeCollectorError.noUsableWindows }
        return snapshots
    }

    private func snapshot(from window: ClaudeUsageWindow?, label: String, now: Date) -> UsageSnapshot? {
        guard let window, let utilization = window.utilization else { return nil }
        let percent = min(100, max(0, utilization * percentScale))
        let resetsAt = ClaudeUsageClient.parseISO8601(window.resetsAt) ?? now
        return UsageSnapshot(
            providerName: providerName,
            windowLabel: label,
            percentUsed: percent,
            resetsAt: resetsAt,
            lastUpdated: now
        )
    }
}
