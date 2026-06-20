//
//  AgentSecretStore.swift
//  manawell-menubar
//

import Foundation
import ManawellAgentCore

/// Persists the bearer secret so a paired phone keeps working across agent restarts.
/// v1 uses UserDefaults; a later build can move this to the keychain.
enum AgentSecretStore {
    private static let key = "ManawellAgentBearerSecret"

    static func loadOrCreate() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let secret = AgentConfiguration.makeBearerSecret()
        defaults.set(secret, forKey: key)
        return secret
    }
}
