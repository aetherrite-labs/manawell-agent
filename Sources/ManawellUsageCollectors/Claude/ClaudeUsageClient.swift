//
//  ClaudeUsageClient.swift
//  ManawellUsageCollectors
//
//  Calls Anthropic's OAuth usage endpoint the same way Claude Code's `/usage` does.
//  See claude-usage-recipe: GET /api/oauth/usage, bearer + `anthropic-beta` + a
//  claude-code User-Agent, returning per-window { utilization, resets_at }.
//

import Foundation

/// One usage window from the OAuth usage endpoint.
struct ClaudeUsageWindow: Decodable, Sendable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

/// The subset of `/api/oauth/usage` we map to the app's two windows. (The endpoint also
/// returns seven_day_opus/sonnet/oauth_apps/routines and extra_usage, unused for now.)
struct ClaudeUsageResponse: Decodable, Sendable {
    let fiveHour: ClaudeUsageWindow?
    let sevenDay: ClaudeUsageWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

enum ClaudeUsageError: LocalizedError {
    case invalidResponse
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case server(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Claude usage response was not a valid HTTP response."
        case .unauthorized:
            return "Claude usage request was unauthorized (401). The stored token may be invalid — run `claude`."
        case let .rateLimited(retryAfter):
            let suffix = retryAfter.map { " Retry after ~\(Int($0))s." } ?? ""
            return "Claude usage endpoint is rate limited (429).\(suffix)"
        case let .server(code, body):
            let detail = body.map { ": \($0.prefix(300))" } ?? ""
            return "Claude usage endpoint returned HTTP \(code)\(detail)"
        }
    }
}

enum ClaudeUsageClient {
    static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    static let betaHeader = "oauth-2025-04-20"

    static func fetchUsage(accessToken: String, userAgent: String, debug: Bool) async throws -> ClaudeUsageResponse {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(betaHeader, forHTTPHeaderField: "anthropic-beta")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeUsageError.invalidResponse
        }

        if debug {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
            log("HTTP \(http.statusCode) from \(usageURL.absoluteString)")
            log("raw body: \(body)")
        }

        switch http.statusCode {
        case 200:
            return try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
        case 401:
            throw ClaudeUsageError.unauthorized
        case 429:
            let retryAfter = (http.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
            throw ClaudeUsageError.rateLimited(retryAfter: retryAfter)
        default:
            throw ClaudeUsageError.server(http.statusCode, String(data: data, encoding: .utf8))
        }
    }

    /// Parses an ISO-8601 `resets_at`, with and without fractional seconds.
    static func parseISO8601(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func log(_ message: String) {
        FileHandle.standardError.write(Data("[claude] \(message)\n".utf8))
    }
}

/// Resolves the `claude-code/<version>` User-Agent. Tries the installed CLI, falls back
/// to a known-good version, and honors a `MANAWELL_CLAUDE_CODE_VERSION` override.
enum ClaudeCodeVersion {
    static let fallback = "2.1.0"

    static func userAgent() -> String {
        "claude-code/\(detect())"
    }

    static func detect() -> String {
        if let override = ProcessInfo.processInfo.environment["MANAWELL_CLAUDE_CODE_VERSION"],
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }
        return runClaudeVersion() ?? fallback
    }

    private static func runClaudeVersion() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["claude", "--version"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            // e.g. "2.1.0 (Claude Code)" → "2.1.0"
            let token = output.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).first
            return token.map(String.init)
        } catch {
            return nil
        }
    }
}
