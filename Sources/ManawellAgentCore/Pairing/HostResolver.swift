//
//  HostResolver.swift
//  ManawellAgentCore
//
//  Works out the best address to advertise in the pairing QR: a Tailscale IP if the
//  machine is on a tailnet, else the `.local` mDNS name for same-LAN use, else loopback.
//

import Foundation

public struct ResolvedHost: Equatable, Sendable {
    public enum Source: String, Sendable {
        case tailscale
        case localHostname
        case loopback
    }

    public var host: String
    public var source: Source

    /// Human-friendly one-liner for the CLI / menu bar.
    public var summary: String {
        switch source {
        case .tailscale: "\(host) (Tailscale)"
        case .localHostname: "\(host) (same Wi-Fi/LAN)"
        case .loopback: "\(host) (loopback only — your phone can't reach this)"
        }
    }
}

public enum HostResolver {
    /// Runs a command and returns trimmed stdout, or `nil` on launch failure / non-zero exit.
    /// Injected in tests; defaults to a real `Process`.
    public typealias CommandRunner = @Sendable (_ launchPath: String, _ arguments: [String]) -> String?

    public static func resolve(run: CommandRunner = runProcess) -> ResolvedHost {
        if let ip = tailscaleIPv4(run: run) {
            return ResolvedHost(host: ip, source: .tailscale)
        }
        if let name = localHostname(run: run) {
            return ResolvedHost(host: name, source: .localHostname)
        }
        return ResolvedHost(host: "127.0.0.1", source: .loopback)
    }

    static func tailscaleCandidatePaths() -> [String] {
        [
            "/Applications/Tailscale.app/Contents/MacOS/Tailscale",
            "/opt/homebrew/bin/tailscale",
            "/usr/local/bin/tailscale",
            "/usr/bin/tailscale",
        ]
    }

    static func tailscaleIPv4(run: CommandRunner) -> String? {
        for path in tailscaleCandidatePaths() {
            // A missing binary just makes `run` return nil — no need to stat first.
            guard let output = run(path, ["ip", "-4"]) else { continue }
            let firstLine = output.split(whereSeparator: \.isNewline).first
                .map(String.init)?.trimmingCharacters(in: .whitespaces)
            if let firstLine, !firstLine.isEmpty {
                return firstLine
            }
        }
        return nil
    }

    static func localHostname(run: CommandRunner) -> String? {
        guard let name = run("/usr/sbin/scutil", ["--get", "LocalHostName"]) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(trimmed).local"
    }

    public static let runProcess: CommandRunner = { launchPath, arguments in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
