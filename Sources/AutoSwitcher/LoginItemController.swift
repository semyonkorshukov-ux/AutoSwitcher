import ServiceManagement

/// Автозапуск при входе в систему через SMAppService (macOS 13+).
/// Полноценно работает, когда приложение лежит в «Программах».
enum LoginItemController {
    /// Автозапуск запрошен. Пока пользователь не одобрил его в настройках,
    /// он тоже считается запрошенным: иначе его нельзя будет выключить обратно.
    static var isEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Log.shared.write("автозапуск: \(on ? "включён" : "выключен")")
        } catch {
            Log.shared.write("автозапуск: ошибка — \(error.localizedDescription)")
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
