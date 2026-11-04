import Foundation

public enum FixTarget: Equatable {
    case russian
    case english
}

/// Описание исправления: сколько символов стереть и чем их заменить.
public struct Fix: Equatable {
    public let charsToFix: Int
    public let replacement: String
    public let target: FixTarget
}

/**
 Детектор «не той раскладки».

 Работает по префиксной модели (как Punto/Caramba): на каждом очередном
 символе проверяет текущее слово. Если набранный префикс уже невозможен
 в языке текущей раскладки, но его проекция на другую раскладку является
 началом реального слова — слово исправляется прямо во время набора,
 не дожидаясь пробела.
 */
public final class LayoutDetector {
    /// Минимальная длина слова для исправления на лету (по префиксу).
    public var minLiveLength = 4
    /// Минимальная длина слова для исправления на границе (пробел/знак).
    public var minBoundaryLength = 3

    private var buffer: [Character] = []
    private let enTrie: Trie
    private let ruTrie: Trie

    public init(enWords: [String], ruWords: [String]) {
        enTrie = Trie(words: enWords)
        ruTrie = Trie(words: ruWords)
    }

    public func reset() {
        buffer = []
    }

    public var currentWordCount: Int { buffer.count }

    /// Обрабатывает очередной напечатанный символ.
    /// Возвращает Fix, если нужно исправить (буфер при этом очищается).
    @discardableResult
    public func process(_ c: Character) -> Fix? {
        if c.isLetter {
            let isLatin = c.isASCII
            // Смешение скриптов в одном «слове» — начинаем заново.
            if let first = buffer.first, first.isASCII != isLatin {
                buffer = []
            }
            buffer.append(c)
            if buffer.count >= minLiveLength, let fix = liveCheck() {
                buffer = []
                return fix
            }
            return nil
        }

        // Не буква: пробел/знак препинания — граница слова (можно ещё успеть исправить),
        // Enter/Tab/цифры — только сброс (исправлять уже отправлённое опасно).
        let word = buffer
        buffer = []
        guard c == " " || c.isPunctuation else { return nil }
        guard word.count >= minBoundaryLength else { return nil }
        return boundaryCheck(word)
    }

    // MARK: - Проверки

    private func liveCheck() -> Fix? {
        let raw = String(buffer).lowercased()
        if buffer[0].isASCII {
            guard raw.allSatisfy({ KeyMap.enToRuLower[$0] != nil }) else { return nil }
            let mapped = String(raw.map { KeyMap.enToRuLower[$0]! })
            // Префикс жив в русском и мёртв в английском → чиним.
            guard ruTrie.hasPrefix(mapped), !enTrie.hasPrefix(raw) else { return nil }
            return Fix(charsToFix: buffer.count,
                       replacement: KeyMap.mapEnToRu(String(buffer)),
                       target: .russian)
        } else {
            guard raw.allSatisfy({ KeyMap.ruToEnLower[$0] != nil }) else { return nil }
            let mapped = String(raw.map { KeyMap.ruToEnLower[$0]! })
            guard enTrie.hasPrefix(mapped), !ruTrie.hasPrefix(raw) else { return nil }
            return Fix(charsToFix: buffer.count,
                       replacement: KeyMap.mapRuToEn(String(buffer)),
                       target: .english)
        }
    }

    private func boundaryCheck(_ word: [Character]) -> Fix? {
        let raw = String(word).lowercased()
        if word[0].isASCII {
            guard raw.allSatisfy({ KeyMap.enToRuLower[$0] != nil }) else { return nil }
            let mapped = String(raw.map { KeyMap.enToRuLower[$0]! })
            guard ruTrie.contains(mapped), !enTrie.contains(raw) else { return nil }
            return Fix(charsToFix: word.count,
                       replacement: KeyMap.mapEnToRu(String(word)),
                       target: .russian)
        } else {
            guard raw.allSatisfy({ KeyMap.ruToEnLower[$0] != nil }) else { return nil }
            let mapped = String(raw.map { KeyMap.ruToEnLower[$0]! })
            guard enTrie.contains(mapped), !ruTrie.contains(raw) else { return nil }
            return Fix(charsToFix: word.count,
                       replacement: KeyMap.mapRuToEn(String(word)),
                       target: .english)
        }
    }
}
