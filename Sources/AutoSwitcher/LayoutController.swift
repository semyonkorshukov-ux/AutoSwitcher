import Carbon.HIToolbox
import AutoSwitcherCore

/// Управление раскладками через Text Input Services.
final class LayoutController {
    private var russianSource: TISInputSource?
    private var englishSource: TISInputSource?
    private var russianID: String?
    private var englishID: String?

    init() {
        let list = (TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource]) ?? []
        for source in list {
            guard let id = Self.sourceID(source) else { continue }
            if id.hasPrefix("com.apple.keylayout.Russian") {
                if russianSource == nil { russianSource = source; russianID = id }
            } else if id == "com.apple.keylayout.ABC" || id == "com.apple.keylayout.US" {
                if englishSource == nil { englishSource = source; englishID = id }
            }
        }
    }

    var isConfigured: Bool { russianSource != nil && englishSource != nil }

    var configurationSummary: String {
        "RU: \(russianID ?? "не найдена") · EN: \(englishID ?? "не найдена")"
    }

    static func currentLayoutID() -> String? {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return sourceID(current)
    }

    static func currentIsRuOrEn() -> Bool {
        guard let id = currentLayoutID() else { return false }
        return id.hasPrefix("com.apple.keylayout.Russian")
            || id == "com.apple.keylayout.ABC"
            || id == "com.apple.keylayout.US"
    }

    @discardableResult
    func select(_ target: FixTarget) -> Bool {
        let source: TISInputSource?
        switch target {
        case .russian: source = russianSource
        case .english: source = englishSource
        }
        guard let source else { return false }
        return TISSelectInputSource(source) == noErr
    }

    private static func sourceID(_ source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}
