import Foundation
import Testing
import ManawellCore
@testable import ManawellAgentServer

@Test("Resolver prefers a Tailscale IPv4 when the CLI returns one")
func resolverPrefersTailscale() {
    let run: HostResolver.CommandRunner = { path, args in
        if path.contains("Tailscale"), args == ["ip", "-4"] {
            return "100.111.122.133\nfd7a:115c:a1e0::1\n"
        }
        return nil
    }
    let resolved = HostResolver.resolve(run: run)
    #expect(resolved == ResolvedHost(host: "100.111.122.133", source: .tailscale))
}

@Test("Resolver falls back to the .local hostname when Tailscale is absent")
func resolverFallsBackToLocal() {
    let run: HostResolver.CommandRunner = { path, args in
        if path.hasSuffix("scutil"), args == ["--get", "LocalHostName"] {
            return "Jude-Mac\n"
        }
        return nil // no tailscale
    }
    let resolved = HostResolver.resolve(run: run)
    #expect(resolved == ResolvedHost(host: "Jude-Mac.local", source: .localHostname))
}

@Test("Resolver falls back to loopback when nothing is reachable")
func resolverFallsBackToLoopback() {
    let run: HostResolver.CommandRunner = { _, _ in nil }
    let resolved = HostResolver.resolve(run: run)
    #expect(resolved == ResolvedHost(host: "127.0.0.1", source: .loopback))
}

@Test("PairingService builds a payload that round-trips and uses the resolved host")
func pairingServiceBuildsPayload() {
    let run: HostResolver.CommandRunner = { path, args in
        path.contains("Tailscale") && args == ["ip", "-4"] ? "100.1.2.3\n" : nil
    }
    let service = PairingService(deviceName: "Studio", port: 8787, bearerSecret: "sek-ret")
    let result = service.makePairing(run: run)

    #expect(result.host.source == .tailscale)
    #expect(result.payload.host == "100.1.2.3")
    #expect(result.payload.port == 8787)
    #expect(result.payload.bearerSecret == "sek-ret")

    let reparsed = PairingPayload(urlString: result.payload.urlString())
    #expect(reparsed == result.payload)
}

@Test("Terminal QR renders deterministic, non-empty output")
func qrRendersSomething() throws {
    let qr = try QRCodeRenderer.terminalString(for: "manawell://pair?name=x&host=y&port=1&secret=z")
    #expect(!qr.isEmpty)
    #expect(qr.contains("\u{2588}") || qr.contains("\u{2580}") || qr.contains("\u{2584}"))
}
