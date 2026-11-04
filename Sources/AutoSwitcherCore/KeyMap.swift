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

    /// Символы с Shift на клавишах, где в ЙЦУКЕН стоят заглавные буквы.
    private static let shiftedToBase: [Character: Character] = [
        "{": "[", "}": "]", ":": ";", "\"": "'", "<": ",", ">": ".", "~": "`"
    ]

    private static let baseToShifted: [Character: Character] = {
        var result: [Character: Character] = [:]
        for (shifted, base) in shiftedToBase {
            result[base] = shifted
        }
        return result
    }()

    /// Знак на клавише, где в ЙЦУКЕН стоит буква: `,` — это «б», `:` — это «Ж».
    public static func isLetterKeyPunctuation(_ c: Character) -> Bool {
        !c.isLetter && (enToRuLower[c] != nil || shiftedToBase[c] != nil)
    }

    /// Убирает Shift со знака: `:` → `;`. Остальные символы не меняются.
    public static func unshifted(_ c: Character) -> Character {
        shiftedToBase[c] ?? c
    }

    /// Переводит строку из EN-набора в RU-раскладку, сохраняя регистр.
    public static func mapEnToRu(_ s: String) -> String {
        String(s.map { c in
            if let base = shiftedToBase[c], let ru = enToRuLower[base] {
                return Character(ru.uppercased())
            }
            return mapPreservingCase(c, table: enToRuLower) ?? c
        })
    }

    /// Переводит строку из RU-набора в EN-раскладку, сохраняя регистр.
    public static func mapRuToEn(_ s: String) -> String {
        String(s.map { c in
            guard let en = mapPreservingCase(c, table: ruToEnLower) else { return c }
            return c.isUppercase ? (baseToShifted[en] ?? en) : en
        })
    }

    private static func mapPreservingCase(_ c: Character, table: [Character: Character]) -> Character? {
        let isUpper = c.isUppercase
        let lower = Character(c.lowercased())
        guard let mapped = table[lower] else { return nil }
        return isUpper ? Character(mapped.uppercased()) : mapped
    }
}
