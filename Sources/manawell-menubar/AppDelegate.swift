//
//  AppDelegate.swift
//  manawell-menubar
//

import AppKit
import ManawellAgentCore
import ManawellCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller: AgentController
    private let deviceName: String
    private let pairingWindow = PairingWindowController()

    private var statusItem: NSStatusItem!
    private var refreshTimer: Timer?

    init(controller: AgentController, deviceName: String) {
        self.controller = controller
        self.deviceName = deviceName
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Manawell"

        controller.start()
        refresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    // MARK: - Refresh

    private func refresh() {
        Task { @MainActor in
            let snapshots = await controller.snapshots()
            updateStatusTitle(with: snapshots)
            rebuildMenu(with: snapshots)
        }
    }

    private func updateStatusTitle(with snapshots: [UsageSnapshot]) {
        guard controller.isRunning else {
            statusItem.button?.title = "off"
            return
        }
        if let top = snapshots.first {
            statusItem.button?.title = String(format: "%.0f%%", top.percentUsed)
        } else {
            statusItem.button?.title = "—"
        }
    }

    private func rebuildMenu(with snapshots: [UsageSnapshot]) {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(infoItem("Manawell Agent"))
        menu.addItem(infoItem(controller.isRunning
            ? "Serving on port \(controller.configuration.port)"
            : "Stopped"))

        if controller.isRunning, !snapshots.isEmpty {
            menu.addItem(.separator())
            for snapshot in snapshots {
                menu.addItem(infoItem("\(snapshot.providerName) · \(snapshot.windowLabel) — \(snapshot.formattedPercent)"))
            }
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("Show Pairing QR…", #selector(showPairing)))
        menu.addItem(actionItem(controller.isRunning ? "Stop Agent" : "Start Agent", #selector(toggleAgent)))
        menu.addItem(actionItem("Refresh Now", #selector(refreshNow)))
        menu.addItem(.separator())
        menu.addItem(actionItem("Quit Manawell Agent", #selector(quit)))

        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func showPairing() {
        pairingWindow.show(configuration: controller.configuration, deviceName: deviceName)
    }

    @objc private func toggleAgent() {
        if controller.isRunning {
            controller.stop()
        } else {
            controller.start()
        }
        refresh()
    }

    @objc private func refreshNow() {
        Task { @MainActor in
            _ = await controller.refreshNow()
            refresh()
        }
    }

    @objc private func quit() {
        controller.stop()
        NSApp.terminate(nil)
    }

    // MARK: - Menu item helpers

    private func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func actionItem(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        return item
    }
}
