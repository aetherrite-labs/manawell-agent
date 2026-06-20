//
//  main.swift
//  manawell-agentd
//
//  Headless entrypoint + dev harness for the Manawell agent. The menu-bar app will
//  reuse ManawellAgentServer the same way; this binary is the way to run, pair, and curl
//  the agent without Xcode.
//
//  Modes:
//    (default)        run the HTTP server
//    --probe-claude   one-shot: read the Claude token, fetch usage, print it
//    --pair           print the pairing details + a scannable QR for the phone
//

import Foundation
import ManawellAgentServer
import ManawellCore

let env = ProcessInfo.processInfo.environment
let bindHost = env["MANAWELL_AGENT_HOST"] ?? "127.0.0.1"
let port = env["MANAWELL_AGENT_PORT"].flatMap(Int.init) ?? 8787
let secret = env["MANAWELL_AGENT_SECRET"] ?? AgentConfiguration.makeBearerSecret()
let deviceName = env["MANAWELL_AGENT_NAME"] ?? Host.current().localizedName ?? "My Mac"

// One-shot live verify: read the Claude token, hit the usage endpoint, print what we got.
if CommandLine.arguments.contains("--probe-claude") {
    let collector = ClaudeUsageCollector(debug: true)
    do {
        let snapshots = try await collector.collect()
        print("=== mapped UsageSnapshots ===")
        for snapshot in snapshots {
            print("  \(snapshot.windowLabel): \(snapshot.formattedPercent)  resets \(snapshot.resetsAt)")
        }
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("probe failed: \(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

// Show the pairing QR. Set MANAWELL_AGENT_SECRET so this matches the secret the server uses.
if CommandLine.arguments.contains("--pair") {
    let pairing = PairingService(deviceName: deviceName, port: port, bearerSecret: secret)
    let result = pairing.makePairing()
    print("Scan this with Manawell on your phone:\n")
    do {
        print(try QRCodeRenderer.terminalString(for: result.payload.urlString()))
    } catch {
        FileHandle.standardError.write(Data("QR render failed: \(error.localizedDescription)\n".utf8))
    }
    print("")
    print("  device: \(deviceName)")
    print("  host:   \(result.host.summary)")
    print("  port:   \(port)")
    print("  secret: \(secret)")
    print("  link:   \(result.payload.urlString())")
    if env["MANAWELL_AGENT_SECRET"] == nil {
        print("\n  note: secret is random this run — set MANAWELL_AGENT_SECRET to match the server.")
    }
    exit(0)
}

let configuration = AgentConfiguration(bindHost: bindHost, port: port, bearerSecret: secret)

// Real Claude usage by default; `MANAWELL_AGENT_DEMO=1` forces demo data. Either way the
// UsageCache serves demo data as an automatic fallback if a collector fails on cold start.
let collectors: [any UsageCollector] = env["MANAWELL_AGENT_DEMO"] == "1"
    ? [DemoUsageCollector()]
    : [ClaudeUsageCollector()]
let cache = UsageCache(collectors: collectors)

print("manawell-agent listening on http://\(bindHost):\(port)")
print("bearer secret: \(secret)")
print("probe:  curl -i http://\(bindHost):\(port)/v1/health")
print("usage:  curl -s -H 'Authorization: Bearer \(secret)' http://\(bindHost):\(port)/v1/usage")

let server = AgentServer(configuration: configuration, cache: cache)
try await server.run()
