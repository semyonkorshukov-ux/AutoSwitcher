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
    expect(fix, "короткое «hjr» → «рок» на пробеле", chars: 3, replacement: "рок", target: .russian)
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
    // Живой фикс сработает на 4-м символе; далее новый буфер, пробел — ничего.
    expect(fix, "полное слово ghbdtn фиксируется уже на «ghbd»", chars: 4, replacement: "прив", target: .russian)
}

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
}

print("")
print("ИТОГО: \(passed) OK, \(failed) FAIL")
exit(failed == 0 ? 0 : 1)
