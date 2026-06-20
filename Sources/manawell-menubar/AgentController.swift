//
//  AgentController.swift
//  manawell-menubar
//
//  Owns the embedded HTTP server's lifecycle and the shared UsageCache, so the menu-bar
//  status item and the `/v1/usage` endpoint always show the same numbers.
//

import Foundation
import ManawellAgentCore
import ManawellCore

@MainActor
final class AgentController {
    let configuration: AgentConfiguration
    let cache: UsageCache
    private(set) var isRunning = false
    private var serverTask: Task<Void, Never>?

    init(configuration: AgentConfiguration) {
        self.configuration = configuration
        self.cache = UsageCache(collectors: [ClaudeUsageCollector()])
    }

    func start() {
        guard !isRunning else { return }
        let configuration = configuration
        let cache = cache
        serverTask = Task.detached {
            do {
                try await AgentServer(configuration: configuration, cache: cache).run()
            } catch {
                FileHandle.standardError.write(Data("[manawell-menubar] server stopped: \(error)\n".utf8))
            }
        }
        isRunning = true
    }

    func stop() {
        serverTask?.cancel()
        serverTask = nil
        isRunning = false
    }

    func snapshots() async -> [UsageSnapshot] {
        await cache.snapshots()
    }

    func refreshNow() async -> [UsageSnapshot] {
        await cache.refreshNow()
    }
}
