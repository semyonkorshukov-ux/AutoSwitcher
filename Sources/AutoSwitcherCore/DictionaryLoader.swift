import Foundation

/// Загрузка частотных словарей из ресурсов пакета.
/// Источник данных: hermitdave/FrequencyWords (OpenSubtitles 2018).
public enum DictionaryLoader {
    public static func loadRu(bundle: Bundle? = nil) -> [String] {
        load(bundle: bundle, name: "ru_50k") { $0.isCyrillicWord }
    }

    public static func loadEn(bundle: Bundle? = nil) -> [String] {
        load(bundle: bundle, name: "en_50k") { $0.isAsciiWord }
    }

    private static func load(bundle: Bundle?, name: String, accept: (String) -> Bool) -> [String] {
        // Порядок важен: Bundle.module ищет ресурсы рядом с .app и по абсолютному
        // пути в .build, а если не находит — аварийно завершает процесс. Поэтому
        // обращаться к нему можно только после проверки Contents/Resources.
        let resources = bundle ?? nestedAppResourceBundle ?? .module
        guard let url = resources.url(forResource: name, withExtension: "txt", subdirectory: "Resources"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        var words = Set<String>()
        for line in text.split(separator: "\n") {
            let token = line.split(separator: " ").first.map(String.init) ?? ""
            let lower = token.lowercased()
            if lower.count >= 2, lower.count <= 24, accept(lower) {
                words.insert(lower)
            }
        }
        return Array(words)
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
