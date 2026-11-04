import AppKit
import SwiftUI
import AutoSwitcherCore

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let service: SwitcherService
    private var settingsWindow: NSWindow?

    init(service: SwitcherService) {
        self.service = service
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        if let button = statusItem.button {
            if let icon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "AutoSwitcher") {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.title = "RU·EN"
            }
            button.toolTip = "AutoSwitcher — автоматическое переключение раскладки"
        }
        updateIconState()
    }

    func refresh() {
        updateIconState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuild()
    }

    private func updateIconState() {
        statusItem.button?.appearsDisabled = !service.isEnabled || !Self.permissionsOK()
    }

    private func rebuild() {
        guard let menu = statusItem.menu else { return }
        menu.removeAllItems()

        if !Self.permissionsOK() {
            let access = NSMenuItem(title: "⚠️ Нужен доступ — открыть настройки…",
                                    action: #selector(openPermissions(_:)), keyEquivalent: "")
            access.target = self
            menu.addItem(access)
            menu.addItem(.separator())
        }

        addToggle(menu, title: "Автопереключение", isOn: service.isEnabled, action: #selector(toggleEnabled(_:)))
        if let front = NSWorkspace.shared.frontmostApplication,
           let bundleID = front.bundleIdentifier,
           AppFilter.allows(bundleID: bundleID),
           bundleID != Bundle.main.bundleIdentifier {
            let name = front.localizedName ?? bundleID
            addToggle(menu, title: "Не исправлять в «\(name)»",
                      isOn: service.isExcluded(bundleID: bundleID),
                      action: #selector(toggleFrontmostExcluded(_:)),
                      representedObject: bundleID)
        }
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Настройки…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(NSMenuItem(title: "Выйти из AutoSwitcher",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    private func addToggle(_ menu: NSMenu, title: String, isOn: Bool, action: Selector, representedObject: Any? = nil) {
        let item = NSMenuItem(title: "\(isOn ? "✓ " : "   ")\(title)", action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = representedObject
        menu.addItem(item)
    }

    // MARK: - Действия

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        service.isEnabled.toggle()
        updateIconState()
    }

    @objc private func toggleFrontmostExcluded(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        service.setExcluded(!service.isExcluded(bundleID: bundleID), bundleID: bundleID)
    }

    @objc private func openPermissions(_ sender: NSMenuItem) {
        Self.openPermissionSettings()
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        showSettings()
    }

    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 440),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "AutoSwitcher"
            window.contentView = NSHostingView(rootView: SettingsView(service: service))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    /// Активному event tap достаточно «Универсального доступа».
    static func permissionsOK() -> Bool {
        AXIsProcessTrusted()
    }

    static func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
