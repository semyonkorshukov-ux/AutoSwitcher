import Foundation

public enum FixTarget: Equatable {
    case russian
    case english

    public var opposite: FixTarget { self == .russian ? .english : .russian }
}

/// Описание исправления.
public struct Fix: Equatable {
    /// Сколько набранных символов заменяется, включая последний нажатый:
    /// его событие не доходит до приложения, а входит в `replacement`.
    public let charsToFix: Int
    public let replacement: String
    /// Текст в том виде, как его набрали (нужен для отмены).
    public let original: String
    public let target: FixTarget

    public init(charsToFix: Int, replacement: String, original: String, target: FixTarget) {
        self.charsToFix = charsToFix
        self.replacement = replacement
        self.original = original
        self.target = target
    }
}

/**
 Детектор «не той раскладки».

 Работает по префиксной модели (как Punto/Caramba): на каждом очередном
 символе проверяет текущее слово. Если набранный префикс уже невозможен
 в языке текущей раскладки, но его проекция на другую раскладку является
 началом реального слова — слово исправляется прямо во время набора,
 не дожидаясь пробела.

 Клавиши `, . ; ' [ ] `` в ЙЦУКЕН — это буквы, поэтому в латинском наборе
 они условно считаются частью слова: `j,tl` — это «обед». Запятая после
 настоящего английского слова остаётся знаком препинания.
 */
public final class LayoutDetector {
    /// Минимальная длина слова для исправления на лету (по префиксу).
    public var minLiveLength = 4
    /// Минимальная длина слова для исправления на границе (пробел/знак).
    public var minBoundaryLength = 2

    private var buffer: [Character] = []
    /// Остаток уже исправленного слова набирается в верной раскладке — его не проверяем.
    private var suppressed = false
    private let enTrie: Trie
    private let ruTrie: Trie

    public init(enWords: [String], ruWords: [String]) {
        enTrie = Trie(words: enWords)
        ruTrie = Trie(words: ruWords)
    }

    public func reset() {
        buffer = []
        suppressed = false
    }

    /// Не трогать слово до следующей границы (например, после отмены исправления).
    public func suppressCurrentWord() {
        buffer = []
        suppressed = true
    }

    public var currentWordCount: Int { buffer.count }

    /// Обрабатывает очередной напечатанный символ.
    /// Возвращает Fix, если нужно исправить (буфер при этом очищается).
    @discardableResult
    public func process(_ c: Character) -> Fix? {
        if suppressed {
            if c.isLetter { return nil }
            suppressed = false
        }
        if c.isLetter {
            // Смешение скриптов в одном «слове» — начинаем заново.
            if let first = buffer.first, first.isASCII != c.isASCII {
                buffer = []
            }
            buffer.append(c)
            dropDeadLeadingPunctuation()
            return liveCheck()
        }
        if continuesWord(c) {
            buffer.append(c)
            return liveCheck()
        }

        // Не буква: пробел/знак препинания — граница слова (можно ещё успеть исправить),
        // Enter/Tab/цифры — только сброс (исправлять уже отправленное опасно).
        let word = buffer
        buffer = []
        guard c == " " || c.isPunctuation else { return nil }
        return boundaryCheck(word, trigger: c)
    }

    // MARK: - Границы слова

    /// Знак на «буквенной» клавише продолжает латинское слово. После настоящего
    /// английского слова — только если получается начало русского: `nt,` — это «теб»,
    /// хотя `nt` и есть в словаре, а `hello,` — обычная запятая.
    private func continuesWord(_ c: Character) -> Bool {
        guard KeyMap.isLetterKeyPunctuation(c), buffer.allSatisfy(\.isASCII) else { return false }
        guard enTrie.contains(normalized(buffer)) else { return true }
        let extended = buffer + [c]
        guard let mapped = direction(for: extended).mapped(normalized(extended)) else { return false }
        return ruTrie.hasPrefix(mapped)
    }

    /// Слово внутри знаков уже похоже на английское: `[boy`, `'left`, `he,`.
    /// Запятая в начале (`,tp` — «без») и обратный апостроф в конце (`dc`` — «всё»)
    /// обычными знаками не бывают, поэтому такие слова исправляются.
    private func looksLikeEnglish(_ word: [Character], asPrefix: Bool) -> Bool {
        guard word.first?.isASCII == true else { return false }
        var letters = word
        var hasOpener = false
        var hasCloser = false
        while let first = letters.first, !first.isLetter {
            hasOpener = hasOpener || Self.openers.contains(first)
            letters.removeFirst()
        }
        while let last = letters.last, !last.isLetter {
            hasCloser = hasCloser || Self.closers.contains(last)
            letters.removeLast()
        }
        guard hasOpener || hasCloser, !letters.isEmpty else { return false }
        let raw = normalized(letters)
        if asPrefix { return letters.count >= 3 && enTrie.hasPrefix(raw) }
        return enTrie.contains(raw) && (hasCloser || letters.count >= 3)
    }

    private static let openers: Set<Character> = ["'", "\"", "[", "{"]
    private static let closers: Set<Character> = [",", ".", ";", ":", "'", "\"", "]", "}"]
    /// Знаки, которые в конце слова обычно и есть знаки, а не буквы:
    /// `lf,` — это «да,», зато `yj;` — это «нож», а не «но;».
    private static let sentencePunctuation: Set<Character> = [",", "."]

    /// Открывающая кавычка или скобка перед словом — не буква «э» или «х»,
    /// если с неё не начинается ни одно русское слово.
    private func dropDeadLeadingPunctuation() {
        while buffer.count > 1, let first = buffer.first, !first.isLetter {
            let direction = direction(for: buffer)
            if let mapped = direction.mapped(normalized(buffer)), direction.targetTrie.hasPrefix(mapped) {
                return
            }
            buffer.removeFirst()
        }
    }

    // MARK: - Проверки

    private struct Direction {
        let sourceTrie: Trie
        let targetTrie: Trie
        let table: [Character: Character]
        let target: FixTarget
        let map: (String) -> String

        func mapped(_ raw: String) -> String? {
            var result = ""
            for c in raw {
                guard let m = table[c] else { return nil }
                result.append(m)
            }
            return result
        }
    }

    /// Направление исправления определяется по первому символу непустого слова.
    private func direction(for word: [Character]) -> Direction {
        if word[0].isASCII {
            return Direction(sourceTrie: enTrie, targetTrie: ruTrie, table: KeyMap.enToRuLower,
                             target: .russian, map: KeyMap.mapEnToRu)
        }
        return Direction(sourceTrie: ruTrie, targetTrie: enTrie, table: KeyMap.ruToEnLower,
                         target: .english, map: KeyMap.mapRuToEn)
    }

    private func normalized(_ word: [Character]) -> String {
        String(word.map(KeyMap.unshifted)).lowercased()
    }

    private func liveCheck() -> Fix? {
        guard buffer.count >= minLiveLength else { return nil }
        let direction = direction(for: buffer)
        let raw = normalized(buffer)
        guard let mapped = direction.mapped(raw),
              direction.targetTrie.hasPrefix(mapped),
              !direction.sourceTrie.hasPrefix(raw),
              !looksLikeEnglish(buffer, asPrefix: true) else { return nil }
        // `xnj,` — это и «чтоб», и «что,». Решит следующая клавиша.
        if !buffer[buffer.count - 1].isLetter,
           let core = direction.mapped(normalized(coreOf(buffer))),
           direction.targetTrie.contains(core) {
            return nil
        }
        let fix = Fix(charsToFix: buffer.count,
                      replacement: direction.map(String(buffer)),
                      original: String(buffer),
                      target: direction.target)
        buffer = []
        suppressed = true
        return fix
    }

    private func boundaryCheck(_ word: [Character], trigger: Character) -> Fix? {
        guard !word.isEmpty else { return nil }
        let direction = direction(for: word)
        guard !direction.sourceTrie.contains(normalized(word)),
              !looksLikeEnglish(word, asPrefix: false) else { return nil }

        func wholeFix() -> Fix? {
            guard word.count >= minBoundaryLength,
                  let replacement = replacement(for: word, in: direction) else { return nil }
            return makeFix(word, replacement, trigger, direction)
        }

        func coreFix() -> Fix? {
            let core = coreOf(word)
            guard core.count < word.count, core.count >= minBoundaryLength,
                  let replacement = replacement(for: core, in: direction) else { return nil }
            let tail = String(word[core.count...])
            // Латинский хвост уже набран знаками, кириллический («ю») знаком станет после замены.
            let mappedTail = word[0].isASCII ? tail : direction.map(tail)
            return makeFix(word, replacement + mappedTail, trigger, direction)
        }

        // «что,» встречается намного чаще, чем «чтоб», зато `dct[` — это «всех», а не «все[».
        if let last = word.last, last.isASCII, !Self.sentencePunctuation.contains(last) {
            return wholeFix() ?? coreFix()
        }
        return coreFix() ?? wholeFix()
    }

    private func replacement(for word: [Character], in direction: Direction) -> String? {
        let raw = normalized(word)
        guard let mapped = direction.mapped(raw),
              direction.targetTrie.contains(mapped),
              !direction.sourceTrie.contains(raw) else { return nil }
        return direction.map(String(word))
    }

    private func makeFix(_ word: [Character], _ replacement: String, _ trigger: Character, _ direction: Direction) -> Fix {
        Fix(charsToFix: word.count + 1,
            replacement: replacement + String(trigger),
            original: String(word) + String(trigger),
            target: direction.target)
    }

    /// Слово без хвоста из символов, которые в другой раскладке являются знаками.
    private func coreOf(_ word: [Character]) -> [Character] {
        var core = word
        if word.first?.isASCII == true {
            while let last = core.last, !last.isLetter { core.removeLast() }
        } else {
            while let last = core.last, let en = KeyMap.ruToEnLower[Character(last.lowercased())], !en.isLetter {
                core.removeLast()
            }
        }
        return core
    }
}
