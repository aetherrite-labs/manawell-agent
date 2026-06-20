//
//  PairingWindowController.swift
//  manawell-menubar
//

import AppKit
import ManawellAgentCore

/// Shows a window with the pairing QR (rendered from the same payload the CLI prints)
/// plus the host/port/secret in selectable text.
@MainActor
final class PairingWindowController {
    private var window: NSWindow?

    func show(configuration: AgentConfiguration, deviceName: String) {
        let pairing = PairingService(
            deviceName: deviceName,
            port: configuration.port,
            bearerSecret: configuration.bearerSecret
        )
        let result = pairing.makePairing()
        let link = result.payload.urlString()

        let title = NSTextField(labelWithString: "Scan with Manawell on your phone")
        title.font = .boldSystemFont(ofSize: 14)

        let qrView = NSImageView()
        qrView.translatesAutoresizingMaskIntoConstraints = false
        qrView.widthAnchor.constraint(equalToConstant: 260).isActive = true
        qrView.heightAnchor.constraint(equalToConstant: 260).isActive = true
        qrView.imageScaling = .scaleProportionallyUpOrDown
        if let cgImage = try? QRCodeRenderer.cgImage(for: link, moduleSize: 8) {
            qrView.image = NSImage(cgImage: cgImage, size: NSSize(width: 260, height: 260))
        }

        let details = NSTextField(wrappingLabelWithString: """
        Device:  \(deviceName)
        Address: \(result.host.summary)
        Port:    \(configuration.port)
        Secret:  \(configuration.bearerSecret)
        """)
        details.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        details.isSelectable = true

        let hint: NSTextField
        if case .loopback = result.host.source {
            hint = NSTextField(wrappingLabelWithString: "⚠︎ No Tailscale/LAN address found — your phone can't reach this Mac yet.")
        } else {
            hint = NSTextField(wrappingLabelWithString: "Keep this Mac awake and the agent running to stay connected.")
        }
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [title, qrView, details, hint])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        let window = self.window ?? makeWindow()
        window.contentView = stack
        window.setContentSize(NSSize(width: 340, height: 470))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 470),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pair Manawell"
        window.isReleasedWhenClosed = false
        return window
    }
}
