import Foundation

/// Локальный журнал отладки: ~/Library/Logs/AutoSwitcher/debug.log
/// Пишет только служебные события и никогда — набранный текст.
/// По умолчанию выключен, включается только командой
/// `defaults write local.autoswitcher.app isDebugLogEnabled -bool true`.
/// Файл перезаписывается при каждом запуске.
final class Log {
    static let shared = Log()
    var isEnabled = false

    private let queue = DispatchQueue(label: "local.autoswitcher.log")
    private let url: URL

    private init() {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/AutoSwitcher", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        url = logs.appendingPathComponent("debug.log")
        let header = "=== AutoSwitcher запущен \(Date()) · pid \(ProcessInfo.processInfo.processIdentifier) ===\n"
        try? header.write(to: url, atomically: true, encoding: .utf8)
    }

    func write(_ message: String) {
        guard isEnabled else { return }
        queue.async {
            let line = "\(Date().formatted(date: .omitted, time: .standard)) · \(message)\n"
            guard let data = line.data(using: .utf8) else { return }
            if let handle = FileHandle(forWritingAtPath: self.url.path) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                handle.write(data)
            } else {
                try? line.write(to: self.url, atomically: true, encoding: .utf8)
            }
        }
    }

    var path: String { url.path }
    var fileURL: URL { url }
}
