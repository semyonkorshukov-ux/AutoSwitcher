import Foundation

/// Список приложений, в которых автопереключение отключено
/// (терминалы: там латиница почти всегда нужна и исправлять опасно).
public enum AppFilter {
    public static let defaultExcludedBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.mitchellh.ghostty"
    ]

    public static func allows(bundleID: String?) -> Bool {
        guard let bundleID else { return true }
        return !defaultExcludedBundleIDs.contains(bundleID)
    }
}
