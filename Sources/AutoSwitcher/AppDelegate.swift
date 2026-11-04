import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    let service = SwitcherService()
    private var menuController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        service.loadDictionariesAsync()
        menuController = MenuBarController(service: service)
        service.onStateChange = { [weak self] in
            self?.menuController?.refresh()
        }

        // Смена активного приложения — сброс буфера.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.service.reset()
        }

        // Без deliverImmediately приложение без окон получало бы уведомление с задержкой.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(accessibilityListDidChange),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )

        service.startTap()
        service.startPermissionsWatch()

        // Без доступа приложение не работает: при первом запуске хватает системного запроса,
        // а если его уже отклоняли, повторно он не появится — тогда показываем настройки.
        if !service.permissionsOK, service.requestAccessibility() {
            menuController?.showSettings()
        }
    }

    @objc private func accessibilityListDidChange() {
        service.accessibilityListDidChange()
    }

    /// Повторный запуск приложения без окон иначе не показал бы ничего,
    /// а значок в меню-баре может быть скрыт вырезом экрана.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuController?.showSettings()
        return false
    }
}

/// Якорь жизненного цикла. NSApplication.delegate — weak-ссылка, а локальная
/// переменная в main.swift освобождается компилятором после последнего
/// использования — из-за этого вся цепочка объектов умирала, значок исчезал,
/// а живой event tap продолжал обращаться к освобождённой памяти (SIGSEGV).
/// Глобальная ссылка живёт до конца процесса.
let sharedAppDelegate = AppDelegate()
