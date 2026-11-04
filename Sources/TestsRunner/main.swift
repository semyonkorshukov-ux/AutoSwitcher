import Foundation
import AutoSwitcherCore

// Простой тестовый раннер: XCTest недоступен при установке только с Command Line Tools.

var passed = 0
var failed = 0

func check(_ condition: Bool, _ name: String, _ detail: String = "") {
    if condition {
        passed += 1
        print("  ✅ \(name)")
    } else {
        failed += 1
        print("  ❌ \(name) \(detail)")
    }
}

func expectNil(_ fix: Fix?, _ name: String) {
    check(fix == nil, name, "(получен \(fix.map { "fix: стереть \($0.charsToFix), вставить '\($0.replacement)'" } ?? "nil"))")
}

func expect(_ fix: Fix?, _ name: String, chars: Int, replacement: String, target: FixTarget) {
    let ok = fix?.charsToFix == chars && fix?.replacement == replacement && fix?.target == target
    check(ok, name, "(получено: стереть \(fix?.charsToFix ?? -1), вставить '\(fix?.replacement ?? "?")', цель \(String(describing: fix?.target)))")
}

let ruWords = ["привет", "привод", "пока", "тест", "код", "рок", "прив", "приветствие"]
let enWords = ["hello", "test", "code", "github", "the", "there", "hell", "rock"]

func makeDetector() -> LayoutDetector {
    LayoutDetector(enWords: enWords, ruWords: ruWords)
}

func type(_ d: LayoutDetector, _ s: String) -> Fix? {
    var fix: Fix?
    for c in s { fix = d.process(c) ?? fix }
    return fix
}

print("— Детектор —")

do {
    let d = makeDetector()
    let fix = type(d, "ghbd")
    expect(fix, "«ghbd» → «прив» исправляется на лету", chars: 4, replacement: "прив", target: .russian)
    expectNil(d.process("е"), "после фикса буфер чист")
    expectNil(d.process("т"), "продолжение не триггерит")
}

do {
    let d = makeDetector()
    expectNil(type(d, "hello"), "настоящее слово hello не трогаем")
    expectNil(type(d, "github"), "github не трогаем")
    expectNil(type(d, "hell"), "hell (префикс real-слов) не трогаем")
}

do {
    let d = makeDetector()
    let fix = type(d, "рудд")
    expect(fix, "«рудд» → «hell» (английский в RU-раскладке)", chars: 4, replacement: "hell", target: .english)
}

do {
    let d = makeDetector()
    expectNil(type(d, "ыудд"), "бессмыслица кириллицей не трогается")
    expectNil(type(d, "zasw"), "бессмыслица латиницей не трогается")
}

do {
    let d = makeDetector()
    let fix = type(d, "hjr ")
    expect(fix, "короткое «hjr» → «рок » на пробеле", chars: 4, replacement: "рок ", target: .russian)
}

do {
    let d = makeDetector()
    expectNil(type(d, "код "), "реальное русское слово на пробеле не трогаем")
    expectNil(type(d, "the "), "the на пробеле не трогаем")
}

do {
    let d = makeDetector()
    expectNil(type(d, "ghbпd"), "смешение скриптов сбрасывает буфер")
}

do {
    let d = makeDetector()
    expectNil(type(d, "ghbt\n"), "после Enter ничего не исправляем")
    expectNil(type(d, "ghbt1"), "цифра — только сброс")
}

do {
    let d = makeDetector()
    let fix = type(d, "GHBD")
    expect(fix, "верхний регистр: «GHBD» → «ПРИВ»", chars: 4, replacement: "ПРИВ", target: .russian)
}

do {
    let d = makeDetector()
    let fix = type(d, "Ghbd")
    expect(fix, "смешанный регистр: «Ghbd» → «Прив»", chars: 4, replacement: "Прив", target: .russian)
}

do {
    let d = makeDetector()
    _ = type(d, "ghb")
    d.reset()
    check(d.currentWordCount == 0, "reset очищает буфер")
}

do {
    let d = makeDetector()
    let fix = type(d, "ghbdtn ")
    // Живой фикс сработает на 4-м символе; остаток слова и пробел уже не проверяются.
    expect(fix, "полное слово ghbdtn фиксируется уже на «ghbd»", chars: 4, replacement: "прив", target: .russian)
}

print("— Буквы на клавишах знаков —")

do {
    let words = ["обед", "хорошо", "чтобы", "чтоб", "что", "как", "это", "бог", "нож", "жизнь", "знаю"]
    let en = ["hello", "test", "the", "file"]

    func detector() -> LayoutDetector { LayoutDetector(enWords: en, ruWords: words) }

    expect(type(detector(), "j,tl"), "«j,tl» → «обед»: запятая внутри слова", chars: 4, replacement: "обед", target: .russian)
    expect(type(detector(), "[jhj"), "«[jhj» → «хоро»: скобка в начале слова", chars: 4, replacement: "хоро", target: .russian)
    expect(type(detector(), "xnj,s"), "«xnj,s» → «чтобы»", chars: 5, replacement: "чтобы", target: .russian)
    expect(type(detector(), "xnj, "), "«xnj, » → «что, »: запятая на границе", chars: 5, replacement: "что, ", target: .russian)
    expect(type(detector(), "rfr. "), "«rfr. » → «как. »", chars: 5, replacement: "как. ", target: .russian)
    expect(type(detector(), ",ju "), "«,ju » → «бог »", chars: 4, replacement: "бог ", target: .russian)
    expect(type(detector(), "yj; "), "«yj; » → «нож »: слово без хвоста слишком короткое", chars: 4, replacement: "нож ", target: .russian)
    expect(type(detector(), "pyf."), "«pyf.» → «знаю» на лету", chars: 4, replacement: "знаю", target: .russian)
    expect(type(detector(), ":bpy"), "«:bpy» → «Жизн»: заглавная Ж с Shift", chars: 4, replacement: "Жизн", target: .russian)
    expect(type(detector(), "\"nj "), "кавычка с Shift как заглавная Э", chars: 4, replacement: "Это ", target: .russian)
    expect(type(detector(), "ерую "), "«ерую » → «the. »: буква «ю» на месте точки", chars: 5, replacement: "the. ", target: .english)
    expectNil(type(LayoutDetector(enWords: ["he"], ruWords: ["руб"]), "he, "), "«he, » не превращается в «руб»")
    expectNil(type(detector(), "hello, "), "запятая после настоящего слова — знак препинания")
    expectNil(type(detector(), "file.txt "), "точка в имени файла ничего не ломает")
    expectNil(type(detector(), "'test' "), "кавычки вокруг английского слова не трогаем")
}

print("— Остаток слова после исправления —")

do {
    let d = LayoutDetector(enWords: ["ulf"], ruWords: ["никогда"])
    expect(type(d, "ybrj"), "«ybrj» → «нико»", chars: 4, replacement: "нико", target: .russian)
    expectNil(type(d, "гда"), "остаток «гда» не проверяется")
    expectNil(d.process(" "), "пробел после остатка ничего не исправляет")
    check(d.process("h") == nil && d.currentWordCount == 1, "следующее слово проверяется заново")
}

do {
    let d = LayoutDetector(enWords: ["hell"], ruWords: ["привет"])
    d.suppressCurrentWord()
    expectNil(type(d, "ghbdtn"), "после отмены слово не исправляется снова")
    expect(type(d, " ghbd"), "после границы проверка возвращается", chars: 4, replacement: "прив", target: .russian)
}

print("— Модификаторы и двойной Shift —")

check(!KeyEventPolicy.modifierChangeResetsWord(flags: [.maskShift], capsLockWasOn: false), "нажатие Shift не сбрасывает слово")
check(!KeyEventPolicy.modifierChangeResetsWord(flags: [], capsLockWasOn: false), "отпускание Shift не сбрасывает слово")
check(KeyEventPolicy.modifierChangeResetsWord(flags: [.maskCommand], capsLockWasOn: false), "Cmd сбрасывает слово")
check(KeyEventPolicy.modifierChangeResetsWord(flags: [.maskSecondaryFn], capsLockWasOn: false), "Fn/Globe сбрасывает слово")
check(KeyEventPolicy.modifierChangeResetsWord(flags: [.maskAlphaShift], capsLockWasOn: false), "включение Caps Lock сбрасывает слово")
check(!KeyEventPolicy.modifierChangeResetsWord(flags: [.maskAlphaShift, .maskShift], capsLockWasOn: true), "Shift при включённом Caps Lock не сбрасывает слово")

do {
    var s = DoubleShiftDetector()
    check(!s.shift(isDown: true, at: 0), "первое нажатие Shift не срабатывает")
    check(!s.shift(isDown: false, at: 0.1), "отпускание не срабатывает")
    check(s.shift(isDown: true, at: 0.2), "второе нажатие срабатывает")

    s = DoubleShiftDetector()
    _ = s.shift(isDown: true, at: 0); _ = s.shift(isDown: false, at: 0.1)
    check(!s.shift(isDown: true, at: 1.0), "долгая пауза — не двойное нажатие")

    s = DoubleShiftDetector()
    _ = s.shift(isDown: true, at: 0); _ = s.shift(isDown: false, at: 0.1)
    s.cancel()
    check(!s.shift(isDown: true, at: 0.2), "буква между нажатиями отменяет двойной Shift")

    s = DoubleShiftDetector()
    _ = s.shift(isDown: true, at: 0); _ = s.shift(isDown: false, at: 2)
    check(!s.shift(isDown: true, at: 2.1), "долго удерживаемый Shift не считается нажатием")
}

print("— Отмена исправления —")

do {
    var u = FixUndoTracker()
    check(u.takeUndo() == nil, "без исправления отменять нечего")

    u.record(Fix(charsToFix: 4, replacement: "прив", original: "ghbd", target: .russian))
    u.noteTyped("е"); u.noteTyped("т")
    let live = u.takeUndo()
    check(live == UndoAction(charsToDelete: 6, text: "ghbdtn", restore: .english, wordFinished: false),
          "отмена в середине слова возвращает и набранный остаток", "\(String(describing: live))")
    check(u.takeUndo() == nil, "вторая отмена ничего не делает")

    u.record(Fix(charsToFix: 4, replacement: "рок ", original: "hjr ", target: .russian))
    let boundary = u.takeUndo()
    check(boundary == UndoAction(charsToDelete: 4, text: "hjr ", restore: .english, wordFinished: true),
          "отмена исправления на пробеле", "\(String(describing: boundary))")

    u.record(Fix(charsToFix: 4, replacement: "рок ", original: "hjr ", target: .russian))
    u.noteTyped("д")
    check(u.takeUndo() == nil, "после начала следующего слова отмена недоступна")

    u.record(Fix(charsToFix: 4, replacement: "прив", original: "ghbd", target: .russian))
    u.noteTyped("е"); u.noteTyped(" ")
    check(u.takeUndo()?.text == "ghbdt ", "пробел в конце слова сохраняется")

    u.record(Fix(charsToFix: 4, replacement: "прив", original: "ghbd", target: .russian))
    u.noteTyped("\u{7f}")
    check(u.takeUndo() == nil, "Backspace отменяет возможность отмены")
}

print("— Исключения приложений —")

check(!AppFilter.allows(bundleID: "com.apple.Terminal"), "терминал исключён по умолчанию")
check(AppFilter.allows(bundleID: "com.apple.Safari"), "остальные приложения разрешены")
check(!AppFilter.allows(bundleID: "com.apple.Safari", userExcluded: ["com.apple.Safari"]), "пользовательское исключение работает")

print("— KeyMap —")

do {
    let en = "qwertyuiop[]asdfghjkl;'zxcvbnm,.`"
    let ru = "йцукенгшщзхъфывапролджэячсмитьбюё"
    var ok = true
    var msg = ""
    for (e, r) in zip(en, ru) {
        if KeyMap.enToRuLower[e] != r { ok = false; msg += " en→ru '\(e)'" }
        if KeyMap.ruToEnLower[r] != e { ok = false; msg += " ru→en '\(r)'" }
    }
    check(ok, "прямой и обратный маппинг всей раскладки", msg)
}

check(KeyMap.mapEnToRu("Ghbdtn") == "Привет", "mapEnToRu с регистром")
check(KeyMap.mapRuToEn("Привет") == "Ghbdtn", "mapRuToEn с регистром")
check(KeyMap.mapEnToRu("GHBDTN") == "ПРИВЕТ", "mapEnToRu ALL CAPS")
check(KeyMap.mapEnToRu(":bpym") == "Жизнь", "mapEnToRu: заглавная буква на знаке")
check(KeyMap.mapRuToEn("Жизнь") == ":bpym", "mapRuToEn: заглавная буква на знаке")

print("— Trie —")

do {
    let t = Trie(words: ["привет", "привод"])
    check(t.hasPrefix("при"), "hasPrefix на корне")
    check(t.hasPrefix("привет"), "hasPrefix на полном слове")
    check(!t.hasPrefix("приветы"), "hasPrefix отсекает лишнее")
    check(t.contains("привет"), "contains на слове")
    check(!t.contains("прив"), "contains не префикс")
}

print("— DictionaryLoader (реальные словари) —")

do {
    let ru = DictionaryLoader.loadRu()
    let en = DictionaryLoader.loadEn()
    check(ru.count > 10_000, "русский словарь загружен (\(ru.count) слов)")
    check(en.count > 10_000, "английский словарь загружен (\(en.count) слов)")
    let ruSet = Set(ru), enSet = Set(en)
    check(ruSet.contains("привет"), "в словаре есть «привет»")
    check(enSet.contains("hello"), "в словаре есть «hello»")
    check(!enSet.contains("привет"), "в EN-словаре нет кириллицы")

    // Проверка детектора на настоящих словарях.
    let d = LayoutDetector(enWords: en, ruWords: ru)
    let fix = type(d, "ghbdtn")
    check(fix?.target == .russian, "реальный словарь: ghbdtn → привет (\(fix?.replacement ?? "?"))")
    let d2 = LayoutDetector(enWords: en, ruWords: ru)
    let fix2 = type(d2, "руддщ")
    check(fix2?.target == .english, "реальный словарь: руддщ → hello (\(fix2?.replacement ?? "?"))")
    let d3 = LayoutDetector(enWords: en, ruWords: ru)
    expectNil(type(d3, "github"), "реальный словарь: github не трогаем")
    let d4 = LayoutDetector(enWords: en, ruWords: ru)
    expectNil(type(d4, "привет "), "реальный словарь: привет не трогаем")

    print("— Качество на реальных словарях —")

    let detector = LayoutDetector(enWords: en, ruWords: ru)

    /// Набирает слово и пробел как настоящий пользователь и возвращает текст в поле ввода:
    /// до исправления раскладка неверная, после него — уже верная.
    func typedResult(_ word: String, wrongLayout map: (String) -> String) -> String {
        detector.reset()
        var field = ""
        var isWrong = true
        for c in word + " " {
            let key = isWrong ? Character(map(String(c))) : c
            if let fix = detector.process(key) {
                field.removeLast(fix.charsToFix - 1)
                field += fix.replacement
                isWrong = false
            } else {
                field.append(key)
            }
        }
        return field
    }

    func rate(_ title: String, _ words: [String], minPercent: Int, map: (String) -> String) {
        var right = 0
        var examples: [String] = []
        for word in words {
            let result = typedResult(word, wrongLayout: map)
            if result == word + " " {
                right += 1
            } else if examples.count < 6 {
                examples.append("\(word)→\(result.trimmingCharacters(in: .whitespaces))")
            }
        }
        let percent = right * 100 / words.count
        check(percent >= minPercent, "\(title): верно \(percent)% (порог \(minPercent)%)", "")
        print("     не вышло: \(examples.joined(separator: ", "))")
    }

    func capitalized(_ word: String) -> String { word.prefix(1).uppercased() + word.dropFirst() }

    let topRu = Array(ru.lazy.filter { $0.count >= 3 }.prefix(3000))
    let topEn = Array(en.lazy.filter { $0.count >= 3 }.prefix(3000))
    let withPunctKeys = topRu.filter { $0.contains(where: "бюжэхъё".contains) }

    rate("RU-слова в EN-раскладке", topRu, minPercent: 98, map: KeyMap.mapRuToEn)
    rate("RU-слова с б/ю/ж/э/х/ъ/ё", withPunctKeys, minPercent: 97, map: KeyMap.mapRuToEn)
    rate("RU-слова с заглавной буквы", topRu.map(capitalized), minPercent: 98, map: KeyMap.mapRuToEn)
    rate("EN-слова в RU-раскладке", topEn, minPercent: 98, map: KeyMap.mapEnToRu)

    for word in ["хорошо", "чтобы", "этого", "никогда", "девушку", "системы", "тебя", "знаю", "всё", "любой", "всех", "без", "нужно"] {
        let result = typedResult(word, wrongLayout: KeyMap.mapRuToEn)
        check(result == word + " ", "реальный словарь: «\(word)»", "(получено «\(result)»)")
    }
    for word in ["Хорошо", "Если", "Просто", "Жизнь", "Это"] {
        let result = typedResult(word, wrongLayout: KeyMap.mapRuToEn)
        check(result == word + " ", "реальный словарь: «\(word)» с заглавной", "(получено «\(result)»)")
    }

    for word in ["да", "не", "на", "по", "но", "ну", "за", "из", "до", "от", "ты", "мы", "вы", "он", "то", "же", "бы", "нож"] {
        let result = typedResult(word, wrongLayout: KeyMap.mapRuToEn)
        check(result == word + " ", "короткое слово: «\(word)»", "(получено «\(result)»)")
    }
    // `in` здесь нет намеренно: в русской раскладке это «шт», и оно не должно исправляться.
    for word in ["to", "is", "of", "it", "on", "me", "my", "we", "be"] {
        let result = typedResult(word, wrongLayout: KeyMap.mapEnToRu)
        check(result == word + " ", "короткое слово: «\(word)»", "(получено «\(result)»)")
    }
    do {
        detector.reset()
        var fix: Fix?
        for c in "lf, " { fix = detector.process(c) ?? fix }
        check(fix?.replacement == "да, ", "«lf, » → «да, »", "(получено «\(fix?.replacement ?? "?")»)")
    }

    print("— Ложные срабатывания на реальных словарях —")

    func falseFixes(_ texts: [String]) -> [String] {
        texts.filter { text in
            detector.reset()
            return text.contains { detector.process($0) != nil }
        }
    }

    let correctEn = topEn.flatMap { [$0 + " ", $0 + ", ", $0 + ". ", "'\($0)' ", "\"\($0)\" ", "[\($0)] "] }
    let correctRu = topRu.flatMap { [$0 + " ", $0 + ", ", $0 + ". "] }
    let enFalse = falseFixes(correctEn)
    let ruFalse = falseFixes(correctRu)
    check(enFalse.isEmpty, "английский текст со знаками не исправляется", "(\(enFalse.count): \(enFalse.prefix(8)))")
    check(ruFalse.isEmpty, "русский текст со знаками не исправляется", "(\(ruFalse.count): \(ruFalse.prefix(8)))")

    let technical = """
    kubernetes docker github gitlab iphone macos ubuntu nginx postgres mysql redis kafka golang \
    typescript webpack graphql oauth localhost async await const println sudo chmod grep ozon \
    telegram whatsapp youtube figma notion slack jira xcode swiftui file.txt main.swift readme.md \
    www.google.com ya.ru vk.com gmail.com node.js e.g. i.e. don't can't it's user.name foo.bar \
    гитхаб кубернетес докер айфон телега ютуб нейросеть промпт кейс дедлайн фича баг лол кек пуш \
    коммит мерж рефакторинг бэкенд фронтенд \
    ok tv pc id ip js os ui cd ls ru en kb mb gb ai dj dr uk cv gh vk шт гр кг км см мм мл ст ул др пр ит вк рф
    """.split(separator: " ").map { String($0) + " " }
    let technicalFalse = falseFixes(technical)
    check(technicalFalse.isEmpty, "технические слова и адреса не исправляются", "(\(technicalFalse))")
}

print("")
print("ИТОГО: \(passed) OK, \(failed) FAIL")
exit(failed == 0 ? 0 : 1)
