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

        service.startTap()
        service.startPermissionsWatch()
    }
}

/// Якорь жизненного цикла. NSApplication.delegate — weak-ссылка, а локальная
/// переменная в main.swift освобождается компилятором после последнего
/// использования — из-за этого вся цепочка объектов умирала, значок исчезал,
/// а живой event tap продолжал обращаться к освобождённой памяти (SIGSEGV).
/// Глобальная ссылка живёт до конца процесса.
let sharedAppDelegate = AppDelegate()
