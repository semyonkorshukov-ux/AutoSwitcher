import SwiftUI
import UniformTypeIdentifiers

/// Окно настроек приложения.
struct SettingsView: View {
    @ObservedObject var service: SwitcherService

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        Form {
            if !service.permissionsOK {
                Section {
                    Label("Включите AutoSwitcher в разделе «Универсальный доступ»", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Button("Открыть настройки") { MenuBarController.openPermissionSettings() }
                }
            }
            if !service.layoutsConfigured {
                Section {
                    Label("Добавьте в систему русскую и английскую раскладки", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Toggle("Автопереключение", isOn: $service.isEnabled)
                Toggle("Звук при исправлении", isOn: $service.isSoundEnabled)
                Toggle("Двойной Shift отменяет исправление", isOn: $service.isUndoEnabled)
                Toggle("Запускать при входе в систему", isOn: Binding(
                    get: { service.launchAtLogin },
                    set: { service.setLaunchAtLogin($0) }
                ))
                if service.launchAtLoginNeedsApproval {
                    HStack(spacing: 8) {
                        Label("macOS ждёт одобрения автозапуска", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Button("Открыть настройки") { LoginItemController.openSystemSettings() }
                            .buttonStyle(.link)
                    }
                }
            }

            Section("Не исправлять в приложениях") {
                ForEach(service.excludedBundleIDs.sorted(), id: \.self) { bundleID in
                    HStack {
                        Text(appName(for: bundleID))
                        Spacer()
                        Button("Убрать") { service.setExcluded(false, bundleID: bundleID) }
                            .buttonStyle(.link)
                    }
                }
                Button("Добавить приложение…") { chooseExcludedApp() }
                Text("В терминалах и полях пароля исправление отключено всегда.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Версия", value: appVersion)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 440)
        .onAppear {
            service.refreshPermissions()
            service.refreshLaunchAtLogin()
        }
    }

    private func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func chooseExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.message = "Выберите приложение, в котором не нужно исправлять раскладку"
        guard panel.runModal() == .OK, let url = panel.url,
              let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
        service.setExcluded(true, bundleID: bundleID)
    }
}
