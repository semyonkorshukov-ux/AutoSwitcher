import Foundation

/// Маппинг клавиш между QWERTY (EN) и ЙЦУКЕН (RU) — стандартная раскладка Apple.
public enum KeyMap {
    /// Латиница → кириллица (нижний регистр).
    public static let enToRuLower: [Character: Character] = [
        "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н",
        "u": "г", "i": "ш", "o": "щ", "p": "з", "[": "х", "]": "ъ",
        "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р",
        "j": "о", "k": "л", "l": "д", ";": "ж", "'": "э",
        "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и",
        "n": "т", "m": "ь", ",": "б", ".": "ю", "`": "ё"
    ]

    /// Кириллица → латиница (обратная таблица).
    public static let ruToEnLower: [Character: Character] = {
        var result: [Character: Character] = [:]
        for (en, ru) in enToRuLower {
            result[ru] = en
        }
        return result
    }()

    /// Переводит строку из EN-набора в RU-раскладку, сохраняя регистр.
    public static func mapEnToRu(_ s: String) -> String {
        String(s.map { mapPreservingCase($0, table: enToRuLower) ?? $0 })
    }

    /// Переводит строку из RU-набора в EN-раскладку, сохраняя регистр.
    public static func mapRuToEn(_ s: String) -> String {
        String(s.map { mapPreservingCase($0, table: ruToEnLower) ?? $0 })
    }

    private static func mapPreservingCase(_ c: Character, table: [Character: Character]) -> Character? {
        let isUpper = c.isUppercase
        let lower = Character(c.lowercased())
        guard let mapped = table[lower] else { return nil }
        return isUpper ? Character(mapped.uppercased()) : mapped
    }
}
