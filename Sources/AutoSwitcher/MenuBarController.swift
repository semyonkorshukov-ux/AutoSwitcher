import AppKit
import SwiftUI

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

        // Настройки
        let settings = NSMenuItem(title: "Настройки…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        // Быстрые переключатели
        addToggle(menu, title: "Автопереключение", isOn: service.isEnabled, action: #selector(toggleEnabled(_:)))
        addToggle(menu, title: "Звук при исправлении", isOn: service.isSoundEnabled, action: #selector(toggleSound(_:)))
        addToggle(menu, title: "Запускать при входе в систему", isOn: service.launchAtLogin, action: #selector(toggleLaunchAtLogin(_:)))
        menu.addItem(.separator())

        // Статус
        let permsOK = Self.permissionsOK()
        let statusTitle: String
        if !permsOK {
            statusTitle = "⚠️ Нужны разрешения — открыть настройки…"
        } else if !service.dictionariesLoaded {
            statusTitle = "Словари загружаются…"
        } else if !service.tapIsRunning {
            statusTitle = "Слежение не запущено"
        } else {
            statusTitle = "✓ Готов к работе"
        }
        let statusRow = NSMenuItem(title: statusTitle,
                                   action: permsOK ? nil : #selector(openPermissions(_:)),
                                   keyEquivalent: "")
        statusRow.target = self
        statusRow.isEnabled = !permsOK
        menu.addItem(statusRow)

        let reconnect = NSMenuItem(title: "Перезапустить слежение", action: #selector(restartTap(_:)), keyEquivalent: "r")
        reconnect.target = self
        menu.addItem(reconnect)

        // Диагностика
        let diagItem = NSMenuItem(title: "Диагностика", action: nil, keyEquivalent: "")
        let diag = NSMenu()
        let ax = AXIsProcessTrusted()
        let listen = CGPreflightListenEventAccess()
        diag.addItem(disabledItem("Accessibility: \(ax ? "✓" : "✗ нет")"))
        diag.addItem(disabledItem("Input Monitoring: \(listen ? "✓" : "✗ нет")"))
        diag.addItem(disabledItem("Слежение: \(service.tapIsRunning ? "работает" : "остановлено")"))
        diag.addItem(disabledItem("Словари: \(service.dictionariesLoaded ? "готовы" : "загрузка…")"))
        diag.addItem(disabledItem("Раскладка сейчас: \(LayoutController.currentLayoutID() ?? "?")"))
        if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            diag.addItem(disabledItem("Приложение: \(front)"))
        }
        diag.addItem(.separator())
        let openLogItem = NSMenuItem(title: "Открыть журнал…", action: #selector(openLog(_:)), keyEquivalent: "")
        openLogItem.target = self
        diag.addItem(openLogItem)
        diagItem.submenu = diag
        menu.addItem(diagItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Выйти из AutoSwitcher",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func addToggle(_ menu: NSMenu, title: String, isOn: Bool, action: Selector) {
        let item = NSMenuItem(title: "\(isOn ? "✓ " : "   ")\(title)", action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    // MARK: - Действия

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        service.isEnabled.toggle()
        updateIconState()
        rebuild()
    }

    @objc private func toggleSound(_ sender: NSMenuItem) {
        service.isSoundEnabled.toggle()
        rebuild()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        service.launchAtLogin.toggle()
        rebuild()
    }

    @objc private func restartTap(_ sender: NSMenuItem) {
        service.stopTap()
        _ = service.startTap()
        updateIconState()
        rebuild()
    }

    @objc private func openPermissions(_ sender: NSMenuItem) {
        for path in [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ] {
            if let url = URL(string: path) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc private func openLog(_ sender: NSMenuItem) {
        NSWorkspace.shared.activateFileViewerSelecting([Log.shared.fileURL])
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 640),
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

    static func permissionsOK() -> Bool {
        AXIsProcessTrusted() && CGPreflightListenEventAccess()
    }
}
