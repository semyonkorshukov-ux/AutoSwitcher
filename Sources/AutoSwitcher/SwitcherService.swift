import AppKit
import Carbon.HIToolbox
import Combine
import AutoSwitcherCore

/// Связывает перехват клавиш, детектор и исполнение исправлений.
/// ObservableObject — чтобы окно настроек биндилось напрямую.
final class SwitcherService: ObservableObject {
    private let tap = KeyTapController()
    private let poster = EventPoster()
    private let layouts = LayoutController()
    private let sound = NSSound(named: NSSound.Name("Tink"))

    private(set) var detector: LayoutDetector?

    @Published var isEnabled = true {
        didSet { if !isEnabled { detector?.reset() } }
    }
    @Published var isSoundEnabled = true
    @Published var isDebugLogEnabled = true {
        didSet { Log.shared.isEnabled = isDebugLogEnabled }
    }
    @Published var minLiveLength = 4.0 {
        didSet { detector?.minLiveLength = Int(minLiveLength) }
    }
    @Published var minBoundaryLength = 3.0 {
        didSet { detector?.minBoundaryLength = Int(minBoundaryLength) }
    }
    @Published private(set) var dictionariesLoaded = false
    @Published private(set) var lastFixAt: Date?
    @Published var launchAtLogin = LoginItemController.isEnabled {
        didSet {
            // Если система не разрешила — откатываем чекбокс к реальности.
            if !LoginItemController.setEnabled(launchAtLogin) {
                launchAtLogin = LoginItemController.isEnabled
            }
        }
    }

    /// Вызывается при любом изменении состояния (для обновления меню).
    var onStateChange: (() -> Void)?

    private var tapRunning = false
    var tapIsRunning: Bool { tapRunning }

    private var permissionsTimer: Timer?
    private var lastPermissionsOK = false

    init() {
        Log.shared.isEnabled = isDebugLogEnabled
        tap.onCharacters = { [weak self] s in self?.handle(characters: s) }
        tap.onReset = { [weak self] in self?.detector?.reset() }
    }

    var statusSummary: String {
        layouts.isConfigured ? layouts.configurationSummary : "не найдены раскладки RU/EN"
    }

    func loadDictionariesAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let ru = DictionaryLoader.loadRu()
            let en = DictionaryLoader.loadEn()
            DispatchQueue.main.async {
                guard let self else { return }
                let detector = LayoutDetector(enWords: en, ruWords: ru)
                detector.minLiveLength = Int(self.minLiveLength)
                detector.minBoundaryLength = Int(self.minBoundaryLength)
                self.detector = detector
                self.dictionariesLoaded = true
                Log.shared.write("словари загружены: ru=\(ru.count), en=\(en.count)")
                self.onStateChange?()
            }
        }
    }

    /// Следит за выдачей разрешений: как только Accessibility/Input Monitoring
    /// выданы — молча перезапускает слежение (иначе tap молчит до ручного рестарта).
    func startPermissionsWatch() {
        lastPermissionsOK = MenuBarController.permissionsOK()
        Log.shared.write("старт: \(layouts.configurationSummary) · разрешения \(lastPermissionsOK ? "✓" : "✗") · tap=\(tapRunning)")
        permissionsTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.watchPermissionsTick()
        }
    }

    private func watchPermissionsTick() {
        let ok = MenuBarController.permissionsOK()
        if ok && !lastPermissionsOK {
            Log.shared.write("разрешения выданы — перезапуск слежения")
            stopTap()
            _ = startTap()
        } else if ok && !tapRunning {
            _ = startTap()
        }
        lastPermissionsOK = ok
    }

    @discardableResult
    func startTap() -> Bool {
        guard tapRunning == false else { return true }
        tapRunning = tap.start()
        let verdict = tapRunning ? "ок" : "НЕ УДАЛОСЬ (нет разрешений?)"
        Log.shared.write("запуск слежения → \(verdict) · \(layouts.configurationSummary)")
        return tapRunning
    }

    func stopTap() {
        tap.stop()
        tapRunning = false
    }

    func reset() {
        detector?.reset()
    }

    private func handle(characters: String) {
        guard isEnabled, let detector else { return }
        // Поля пароля (Secure Event Input) не трогаем.
        if IsSecureEventInputEnabled() {
            Log.shared.write("сброс: включён Secure Input (поле пароля?)")
            detector.reset()
            return
        }
        let layoutID = LayoutController.currentLayoutID() ?? "?"
        // Работаем только когда активна одна из двух поддерживаемых раскладок.
        guard LayoutController.currentIsRuOrEn() else {
            Log.shared.write("сброс: раскладка \(layoutID) — не RU/EN")
            detector.reset()
            return
        }
        // Исключённые приложения (терминалы и т.п.).
        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           !AppFilter.allows(bundleID: bundleID) {
            Log.shared.write("сброс: приложение \(bundleID) в исключениях")
            detector.reset()
            return
        }
        for c in characters {
            if let fix = detector.process(c) {
                Log.shared.write("ИСПРАВЛЕНИЕ: стереть \(fix.charsToFix), вбить «\(fix.replacement)» (\(fix.target == .russian ? "RU" : "EN")); раскладка была \(layoutID)")
                apply(fix)
                break
            } else {
                Log.shared.write("клавиша «\(c)» · буфер \(detector.currentWordCount) симв. · \(layoutID)")
            }
        }
    }

    private func apply(_ fix: Fix) {
        // 1. Переключить раскладку — чтобы дальнейший набор был правильным.
        _ = layouts.select(fix.target)
        // 2. Стереть набранное в неверной раскладке.
        poster.deleteBackward(times: fix.charsToFix)
        // 3. Вбить исправленный текст.
        poster.type(fix.replacement)
        // 4. Сигнал, что сработало (как у Punto).
        if isSoundEnabled { sound?.play() }
        DispatchQueue.main.async { [weak self] in self?.lastFixAt = Date() }
        onStateChange?()
    }
}
