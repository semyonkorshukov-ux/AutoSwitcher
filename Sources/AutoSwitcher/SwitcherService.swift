import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Combine
import AutoSwitcherCore

/// Связывает перехват клавиш, детектор и исполнение исправлений.
/// ObservableObject — чтобы окно настроек биндилось напрямую.
final class SwitcherService: ObservableObject {
    private enum Key {
        static let enabled = "isEnabled"
        static let sound = "isSoundEnabled"
        static let undo = "isUndoEnabled"
        static let excluded = "excludedBundleIDs"
        static let didAskForAccess = "didAskForAccessibility"
        /// Настройки в интерфейсе нет: defaults write local.autoswitcher.app isDebugLogEnabled -bool true
        static let debugLog = "isDebugLogEnabled"
    }

    private static let defaults: UserDefaults = {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            Key.enabled: true,
            Key.sound: true,
            Key.undo: true
        ])
        return defaults
    }()

    private let tap = KeyTapController()
    private let poster = EventPoster()
    private let layouts = LayoutController()
    private let sound = NSSound(named: NSSound.Name("Tink"))
    private var undoTracker = FixUndoTracker()
    private var detector: LayoutDetector?

    @Published var isEnabled = SwitcherService.defaults.bool(forKey: Key.enabled) {
        didSet {
            Self.defaults.set(isEnabled, forKey: Key.enabled)
            if !isEnabled { reset() }
        }
    }
    @Published var isSoundEnabled = SwitcherService.defaults.bool(forKey: Key.sound) {
        didSet { Self.defaults.set(isSoundEnabled, forKey: Key.sound) }
    }
    @Published var isUndoEnabled = SwitcherService.defaults.bool(forKey: Key.undo) {
        didSet { Self.defaults.set(isUndoEnabled, forKey: Key.undo) }
    }
    @Published private(set) var excludedBundleIDs = Set(SwitcherService.defaults.stringArray(forKey: Key.excluded) ?? [])
    @Published private(set) var launchAtLogin = LoginItemController.isEnabled
    @Published private(set) var launchAtLoginNeedsApproval = LoginItemController.needsApproval
    @Published private(set) var permissionsOK = MenuBarController.permissionsOK()

    /// Вызывается при любом изменении состояния (для обновления меню).
    var onStateChange: (() -> Void)?

    private var tapRunning = false
    private var permissionsTimer: Timer?
    let startedWithoutAccess = !MenuBarController.permissionsOK()
    private var isRelaunching = false

    init() {
        Log.shared.isEnabled = Self.defaults.bool(forKey: Key.debugLog)
        tap.onCharacters = { [weak self] s in self?.handle(characters: s) ?? false }
        tap.onReset = { [weak self] in self?.reset() }
        tap.onDoubleShift = { [weak self] in self?.undoLastFix() }
    }

    var layoutsConfigured: Bool { layouts.isConfigured }

    func loadDictionariesAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ru = DictionaryLoader.loadRu()
            let en = DictionaryLoader.loadEn()
            // Деревья строятся вне главного потока: через него проходят все нажатия.
            let detector = LayoutDetector(enWords: en, ruWords: ru)
            DispatchQueue.main.async {
                self?.detector = detector
                Log.shared.write("словари загружены: ru=\(ru.count), en=\(en.count)")
            }
        }
    }

    // MARK: - Автозапуск

    func setLaunchAtLogin(_ on: Bool) {
        LoginItemController.setEnabled(on)
        refreshLaunchAtLogin()
    }

    /// Автозапуск можно изменить и в Системных настройках, поэтому состояние перечитывается.
    func refreshLaunchAtLogin() {
        launchAtLogin = LoginItemController.isEnabled
        launchAtLoginNeedsApproval = LoginItemController.needsApproval
    }

    // MARK: - Исключения

    func isExcluded(bundleID: String) -> Bool {
        excludedBundleIDs.contains(bundleID)
    }

    func setExcluded(_ excluded: Bool, bundleID: String) {
        if excluded {
            excludedBundleIDs.insert(bundleID)
        } else {
            excludedBundleIDs.remove(bundleID)
        }
        Self.defaults.set(excludedBundleIDs.sorted(), forKey: Key.excluded)
        reset()
    }

    // MARK: - Разрешения и слежение

    /// Показывает системный запрос доступа. Возвращает true, если приложение уже спрашивало
    /// раньше: для отклонённого запроса macOS окно больше не показывает.
    func requestAccessibility() -> Bool {
        let askedBefore = Self.defaults.bool(forKey: Key.didAskForAccess)
        Self.defaults.set(true, forKey: Key.didAskForAccess)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return askedBefore
    }

    /// Следит за разрешением: как только оно выдано — запускает слежение, а если
    /// отозвано — останавливает его, потому что активный tap без прав может блокировать ввод.
    func startPermissionsWatch() {
        Log.shared.write("старт: \(layouts.configurationSummary) · доступ \(permissionsOK ? "✓" : "✗") · tap=\(tapRunning)")
        permissionsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshPermissions()
        }
    }

    /// Системное уведомление об изменении списка «Универсального доступа».
    /// Работающему процессу изменение может быть не видно: AXIsProcessTrusted оставался
    /// true после отзыва доступа. Поэтому при активном перехвате приложение перезапускается —
    /// новый процесс увидит настоящее состояние и без доступа перехват не создаст.
    func accessibilityListDidChange() {
        Log.shared.write("список «Универсального доступа» изменился")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            if self.tapRunning {
                self.relaunch()
            } else if self.startedWithoutAccess {
                self.relaunch()
            }
        }
    }

    /// Доступ выдан, но перехват не создался: иногда это получается только у нового процесса.
    /// Запущенное уже с доступом не перезапускается — это защита от бесконечного цикла,
    /// если tap не создаётся по другой причине.
    private func relaunchAfterAccessGranted() {
        guard startedWithoutAccess else { return }
        relaunch()
    }

    private func relaunch() {
        guard !isRelaunching else { return }
        isRelaunching = true
        Log.shared.write("перезапуск приложения")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                if let error {
                    Log.shared.write("перезапуск не удался: \(error.localizedDescription)")
                    self?.isRelaunching = false
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    func refreshPermissions() {
        let ok = MenuBarController.permissionsOK()
        let changed = ok != permissionsOK
        if changed { permissionsOK = ok }
        if ok && !tapRunning {
            startTap()
            if !tapRunning { relaunchAfterAccessGranted() }
        } else if !ok && tapRunning {
            Log.shared.write("доступ отозван — слежение остановлено")
            tap.stop()
            tapRunning = false
        }
        if changed { onStateChange?() }
    }

    func startTap() {
        guard tapRunning == false else { return }
        tapRunning = MenuBarController.permissionsOK() && tap.start()
        let verdict = tapRunning ? "ок" : "НЕ УДАЛОСЬ (нет доступа?)"
        Log.shared.write("запуск слежения → \(verdict) · \(layouts.configurationSummary)")
    }

    func reset() {
        detector?.reset()
        undoTracker.cancel()
    }

    // MARK: - Обработка ввода

    /// Возвращает true, если нажатая клавиша вошла в исправление и до приложения дойти не должна.
    private func handle(characters: String) -> Bool {
        guard isEnabled, let detector else { return false }
        // Поля пароля (Secure Event Input) не трогаем.
        if IsSecureEventInputEnabled() {
            Log.shared.write("сброс: включён Secure Input (поле пароля?)")
            reset()
            return false
        }
        // Работаем только когда активна одна из двух поддерживаемых раскладок.
        guard LayoutController.currentIsRuOrEn() else {
            Log.shared.write("сброс: раскладка \(LayoutController.currentLayoutID() ?? "?") — не RU/EN")
            reset()
            return false
        }
        // Исключённые приложения (терминалы и т.п.).
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           !AppFilter.allows(bundleID: bundleID, userExcluded: excludedBundleIDs) {
            Log.shared.write("сброс: приложение \(bundleID) в исключениях")
            reset()
            return false
        }
        // Поглотить можно только событие с одним символом: иначе часть текста потеряется.
        guard characters.count == 1, let c = characters.first else {
            reset()
            return false
        }
        guard let fix = detector.process(c) else {
            undoTracker.noteTyped(c)
            return false
        }
        // В журнале только служебные данные: набранный текст туда не попадает.
        Log.shared.write("исправление: \(fix.charsToFix) симв. → \(fix.target == .russian ? "RU" : "EN")")
        apply(fix)
        return true
    }

    private func apply(_ fix: Fix) {
        // 1. Переключить раскладку — чтобы дальнейший набор был правильным.
        _ = layouts.select(fix.target)
        // 2. Стереть набранное в неверной раскладке. Последняя клавиша ещё не дошла до приложения.
        poster.deleteBackward(times: fix.charsToFix - 1)
        // 3. Вбить исправленный текст.
        poster.type(fix.replacement)
        undoTracker.record(fix)
        // 4. Сигнал, что сработало (как у Punto).
        if isSoundEnabled { sound?.play() }
    }

    private func undoLastFix() {
        guard isEnabled, isUndoEnabled, !IsSecureEventInputEnabled(),
              let undo = undoTracker.takeUndo() else { return }
        Log.shared.write("отмена исправления: \(undo.charsToDelete) симв.")
        _ = layouts.select(undo.restore)
        poster.deleteBackward(times: undo.charsToDelete)
        poster.type(undo.text)
        if undo.wordFinished {
            detector?.reset()
        } else {
            detector?.suppressCurrentWord()
        }
        if isSoundEnabled { sound?.play() }
    }
}
