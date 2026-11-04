import Foundation

/// Загрузка частотных словарей из ресурсов пакета.
/// Источник данных: hermitdave/FrequencyWords (OpenSubtitles 2018).
public enum DictionaryLoader {
    public static func loadRu(bundle: Bundle? = nil) -> [String] {
        load(bundle: bundle, name: "ru_50k", shortWords: ruShortWords) { $0.isCyrillicWord }
    }

    public static func loadEn(bundle: Bundle? = nil) -> [String] {
        load(bundle: bundle, name: "en_50k", shortWords: enShortWords) { $0.isAsciiWord }
    }

    // Среди двухбуквенных «слов» корпуса субтитров много мусора (`lf`, `nt`, `ye`),
    // поэтому короткие слова берутся только из проверенных списков.
    // Сокращения в них нужны, чтобы `см`, `кг`, `ru` или `vk` не исправлялись.
    private static let ruShortWords: Set<String> = [
        "да", "не", "на", "по", "но", "ну", "за", "из", "до", "от", "ты", "мы", "вы", "он",
        "то", "же", "бы", "ли", "со", "об", "ни", "уж", "их", "им", "ей", "ею", "ох", "ах",
        "эх", "ой", "ай", "эй", "ха", "шт", "гр", "кг", "км", "см", "мм", "мл", "ст", "ул",
        "др", "пр", "ит", "ин", "ру", "вк", "рф", "гл"
    ]

    private static let enShortWords: Set<String> = [
        "am", "an", "as", "at", "be", "by", "do", "go", "he", "if", "in", "is", "it", "me",
        "my", "no", "of", "on", "or", "so", "to", "up", "us", "we", "ok", "hi", "oh", "ha",
        "ah", "uh", "um", "ad", "ex", "tv", "pc", "id", "ip", "js", "os", "ui", "cd", "ls",
        "ru", "en", "kb", "mb", "gb", "ai", "qa", "dj", "mr", "ms", "dr", "uk", "eu", "pr",
        "hr", "db", "vm", "ml", "ux", "cv", "gh", "vk"
    ]

    private static func load(bundle: Bundle?, name: String, shortWords: Set<String>, accept: (String) -> Bool) -> [String] {
        // Порядок важен: Bundle.module ищет ресурсы рядом с .app и по абсолютному
        // пути в .build, а если не находит — аварийно завершает процесс. Поэтому
        // обращаться к нему можно только после проверки Contents/Resources.
        let resources = bundle ?? nestedAppResourceBundle ?? .module
        guard let url = resources.url(forResource: name, withExtension: "txt", subdirectory: "Resources"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        // Порядок файла сохраняется: сначала самые частотные слова.
        var seen = Set<String>()
        var words: [String] = []
        for line in text.split(separator: "\n") {
            let token = line.split(separator: " ").first.map(String.init) ?? ""
            let lower = token.lowercased()
            if lower.count > 2, lower.count <= 24, accept(lower), seen.insert(lower).inserted {
                words.append(lower)
            }
        }
        // Короткие слова добавляются всегда: многих сокращений нет в корпусе субтитров.
        return words + shortWords.sorted()
    }

    /// При запуске из собранного .app ресурсный бандл лежит в Contents/Resources/.
    private static var nestedAppResourceBundle: Bundle? {
        guard let path = Bundle.main.resourceURL?
            .appendingPathComponent("AutoSwitcher_AutoSwitcherCore.bundle").path else { return nil }
        return Bundle(path: path)
    }
}

extension String {
    var isCyrillicWord: Bool {
        !isEmpty && allSatisfy { $0.isCyrillicLetter }
    }

    var isAsciiWord: Bool {
        !isEmpty && allSatisfy { $0.isASCII && $0.isLetter }
    }
}

extension Character {
    var isCyrillicLetter: Bool {
        unicodeScalars.allSatisfy { scalar in
            (scalar >= "а" && scalar <= "я") || scalar == "ё"
        }
    }
}
