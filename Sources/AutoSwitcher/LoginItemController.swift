import ServiceManagement

/// Автозапуск при входе в систему через SMAppService (macOS 13+).
/// Полноценно работает, когда приложение лежит в «Программах».
enum LoginItemController {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Возвращает true при успехе.
    static func setEnabled(_ on: Bool) -> Bool {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Log.shared.write("автозапуск: \(on ? "включён" : "выключен")")
            return true
        } catch {
            Log.shared.write("автозапуск: ошибка — \(error.localizedDescription)")
            return false
        }
    }
}
