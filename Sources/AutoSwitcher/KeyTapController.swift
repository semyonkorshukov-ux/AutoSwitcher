import AppKit
import AutoSwitcherCore
import Carbon.HIToolbox

/// Глобальный event tap клавиатуры. Активный, а не только слушающий: клавиша, на которой
/// сработало исправление, не доходит до приложения и входит в заменяющий текст,
/// поэтому она не может попасть в поле раньше или позже наших событий.
final class KeyTapController {
    /// Получает набранные символы. true — событие поглощено и до приложения не дойдёт.
    var onCharacters: ((String) -> Bool)?
    var onReset: (() -> Void)?
    var onDoubleShift: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retainedSelf: UnsafeMutableRawPointer?
    private var doubleShift = DoubleShiftDetector()
    private var shiftIsDown = false
    private var capsLockIsOn = false

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
            options: .defaultTap,
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
        let flags = CGEventSource.flagsState(.combinedSessionState)
        shiftIsDown = flags.contains(.maskShift)
        capsLockIsOn = flags.contains(.maskAlphaShift)
        doubleShift.cancel()
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
        let consumed: Bool

        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // Система могла отключить tap — включаем заново.
            if let tap = controller.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            consumed = false
        case .keyDown:
            consumed = controller.handleKeyDown(event)
        case .flagsChanged:
            controller.handleFlagsChanged(event)
            consumed = false
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            // Клик мышью — позиция ввода могла уйти.
            controller.doubleShift.cancel()
            controller.onReset?()
            consumed = false
        default:
            consumed = false
        }
        return consumed ? nil : Unmanaged.passUnretained(event)
    }

    private func handleKeyDown(_ event: CGEvent) -> Bool {
        // Игнорируем события, созданные нами самими (маркер).
        if event.getIntegerValueField(.eventSourceUserData) == EventPoster.marker {
            return false
        }
        doubleShift.cancel()
        // Игнорируем сочетания с Cmd/Ctrl/Option (копирование, шорткаты).
        let modifiers = event.flags.intersection([.maskCommand, .maskControl, .maskAlternate])
        guard modifiers.isEmpty, let s = Self.unicodeString(of: event), !s.isEmpty else {
            return false
        }
        return onCharacters?(s) ?? false
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        let flags = event.flags
        if KeyEventPolicy.modifierChangeResetsWord(flags: flags, capsLockWasOn: capsLockIsOn) {
            doubleShift.cancel()
            onReset?()
        } else if flags.contains(.maskShift) != shiftIsDown {
            let isDown = flags.contains(.maskShift)
            if doubleShift.shift(isDown: isDown, at: ProcessInfo.processInfo.systemUptime) {
                onDoubleShift?()
            }
        }
        shiftIsDown = flags.contains(.maskShift)
        capsLockIsOn = flags.contains(.maskAlphaShift)
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
