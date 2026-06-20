//
//  ClaudeCredentials.swift
//  ManawellAgentCore
//
//  Reads the OAuth credentials that Claude Code stores locally, so the agent can call
//  Anthropic's usage endpoint as "Claude Code". Source order: env override → macOS
//  keychain (`Claude Code-credentials`) → `~/.claude/.credentials.json`.
//

import Foundation
import Security

/// Decoded Claude Code OAuth credentials.
struct ClaudeCredentials: Sendable {
    var accessToken: String
    var refreshToken: String?
    /// Absolute expiry, derived from the stored epoch-millis value. `nil` when unknown.
    var expiresAt: Date?
    var scopes: [String]
    var subscriptionType: String?

    var isExpired: Bool {
        guard let expiresAt else { return false }
        // Treat "about to expire" as expired so we never fire a request that 401s mid-flight.
        return Date().addingTimeInterval(60) >= expiresAt
    }
}

enum ClaudeCredentialError: LocalizedError {
    case notFound
    case keychain(OSStatus)
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "No Claude Code credentials found (keychain item \"Claude Code-credentials\" or "
                + "~/.claude/.credentials.json). Run `claude` to sign in."
        case let .keychain(status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
            return "Keychain read failed: \(message)"
        case let .malformed(detail):
            return "Claude credentials were not in the expected format: \(detail)"
        }
    }
}

enum ClaudeCredentialStore {
    static let keychainService = "Claude Code-credentials"
    static let environmentTokenKey = "MANAWELL_CLAUDE_OAUTH_TOKEN"

    /// Loads credentials from the first available source.
    static func load() throws -> ClaudeCredentials {
        // 1. Explicit token override — handy for testing without touching the keychain.
        if let token = ProcessInfo.processInfo.environment[environmentTokenKey],
           !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ClaudeCredentials(accessToken: token, refreshToken: nil, expiresAt: nil, scopes: [], subscriptionType: nil)
        }

        // 2. macOS keychain (default on this platform). Triggers a one-time access prompt.
        if let data = try keychainData() {
            return try parse(data)
        }

        // 3. Plaintext credentials file (Linux / non-keychain installs).
        if let data = fileData() {
            return try parse(data)
        }

        throw ClaudeCredentialError.notFound
    }

    private static func keychainData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw ClaudeCredentialError.keychain(status)
        }
    }

    private static func fileData() -> Data? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        return try? Data(contentsOf: url)
    }

    /// Parses the credentials blob. Claude Code nests the OAuth fields under a
    /// `claudeAiOauth` key; we also accept a bare object for forward compatibility.
    static func parse(_ data: Data) throws -> ClaudeCredentials {
        let decoder = JSONDecoder()
        if let file = try? decoder.decode(CredentialsFile.self, from: data), let blob = file.claudeAiOauth {
            return blob.asCredentials()
        }
        if let blob = try? decoder.decode(OAuthBlob.self, from: data) {
            return blob.asCredentials()
        }
        throw ClaudeCredentialError.malformed("missing claudeAiOauth.accessToken")
    }

    private struct CredentialsFile: Decodable {
        let claudeAiOauth: OAuthBlob?
    }

    /// The stored OAuth fields. Keys are camelCase exactly as Claude Code writes them.
    struct OAuthBlob: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresAt: Double? // epoch milliseconds
        let scopes: [String]?
        let subscriptionType: String?

        func asCredentials() -> ClaudeCredentials {
            ClaudeCredentials(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiresAt.map { Date(timeIntervalSince1970: $0 / 1000) },
                scopes: scopes ?? [],
                subscriptionType: subscriptionType
            )
        }
    }
}
