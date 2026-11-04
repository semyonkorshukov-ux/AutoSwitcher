import AppKit
import Carbon.HIToolbox

/// Постинг событий клавиатуры: backspace'ы и переввод исправленного текста.
/// Все наши события помечены маркером в eventSourceUserData,
/// чтобы собственный event tap их игнорировал и не зациклился.
final class EventPoster {
    static let marker: Int64 = 0x4153_5757 // "ASWW"

    func deleteBackward(times n: Int) {
        for _ in 0..<n {
            postSimple(keyCode: CGKeyCode(kVK_Delete), keyDown: true)
            postSimple(keyCode: CGKeyCode(kVK_Delete), keyDown: false)
        }
    }

    /// Печатает текст посимвольно через unicode-payload события —
    /// работает независимо от текущей раскладки.
    func type(_ text: String) {
        for ch in text {
            let s = String(ch)
            let utf16 = Array(s.utf16)
            postUnicode(utf16, keyDown: true)
            postUnicode(utf16, keyDown: false)
        }
    }

    private func postSimple(keyCode: CGKeyCode, keyDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: EventPoster.marker)
        event.post(tap: .cghidEventTap)
    }

    private func postUnicode(_ utf16: [UniChar], keyDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: keyDown) else { return }
        event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        event.setIntegerValueField(.eventSourceUserData, value: EventPoster.marker)
        event.post(tap: .cghidEventTap)
    }
}
