import AppKit
import Carbon.HIToolbox

/// Глобальный event tap: слушает нажатия клавиш (listen-only, без подавления).
final class KeyTapController {
    var onCharacters: ((String) -> Void)?
    var onReset: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retainedSelf: UnsafeMutableRawPointer?

    func start() -> Bool {
        guard tap == nil else { return true }
        // Удерживаем себя, пока tap существует; отпускаем в stop().
        let opaque = Unmanaged.passRetained(self).toOpaque()
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue
                             | 1 << CGEventType.flagsChanged.rawValue
                             | 1 << CGEventType.leftMouseDown.rawValue
                             | 1 << CGEventType.rightMouseDown.rawValue
                             | 1 << CGEventType.otherMouseDown.rawValue)
        guard let newTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon in
                KeyTapController.tapCallback(type: type, event: event, refcon: refcon)
            },
            userInfo: opaque
        ) else {
            Unmanaged<KeyTapController>.fromOpaque(opaque).release()
            return false
        }

        tap = newTap
        retainedSelf = opaque
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: newTap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        if let retainedSelf {
            Unmanaged<KeyTapController>.fromOpaque(retainedSelf).release()
        }
        retainedSelf = nil
    }

    private static func tapCallback(type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<KeyTapController>.fromOpaque(refcon).takeUnretainedValue()

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // Система могла отключить tap — включаем заново.
            if let tap = controller.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            // Игнорируем события, созданные нами самими (маркер).
            if event.getIntegerValueField(.eventSourceUserData) == EventPoster.marker {
                return Unmanaged.passUnretained(event)
            }
            // Игнорируем сочетания с Cmd/Ctrl/Option (копирование, шорткаты).
            let modifiers = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate])
            guard modifiers.isEmpty else { return Unmanaged.passUnretained(event) }
            if let s = Self.unicodeString(of: event), !s.isEmpty {
                controller.onCharacters?(s)
            }
            return Unmanaged.passUnretained(event)

        case .flagsChanged, .leftMouseDown, .rightMouseDown, .otherMouseDown:
            // Смена модификаторов/клик мышью — позиция ввода могла уйти.
            controller.onReset?()
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private static func unicodeString(of event: CGEvent) -> String? {
        var actualLength: Int = 0
        var chars = [UniChar](repeating: 0, count: 16)
        event.keyboardGetUnicodeString(maxStringLength: chars.count,
                                       actualStringLength: &actualLength,
                                       unicodeString: &chars)
        guard actualLength > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: Int(actualLength))
    }
}
