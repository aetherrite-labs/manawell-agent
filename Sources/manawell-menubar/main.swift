//
//  main.swift
//  manawell-menubar
//
//  Menu-bar shell for the Manawell agent: embeds the HTTP server, shows current usage in
//  the status bar, and a pairing QR window. Runs as an accessory app (no Dock icon).
//

import AppKit
import ManawellAgentServer

let env = ProcessInfo.processInfo.environment
let port = env["MANAWELL_AGENT_PORT"].flatMap(Int.init) ?? 8787
let deviceName = env["MANAWELL_AGENT_NAME"] ?? Host.current().localizedName ?? "My Mac"
let secret = AgentSecretStore.loadOrCreate()

// Bind 0.0.0.0 so a paired phone can reach the agent over Tailscale/LAN.
let configuration = AgentConfiguration(bindHost: "0.0.0.0", port: port, bearerSecret: secret)

// Top-level main runs on the main thread, so we can assume main-actor isolation to set up
// the AppKit objects (all @MainActor). `run()` then blocks on the main run loop.
MainActor.assumeIsolated {
    let controller = AgentController(configuration: configuration)
    let application = NSApplication.shared
    let delegate = AppDelegate(controller: controller, deviceName: deviceName)
    application.delegate = delegate
    application.setActivationPolicy(.accessory) // menu-bar only, no Dock icon
    application.run()
}
