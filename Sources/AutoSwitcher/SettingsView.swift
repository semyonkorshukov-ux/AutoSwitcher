import SwiftUI

/// Окно настроек приложения.
struct SettingsView: View {
    @ObservedObject var service: SwitcherService
    @State private var permissionsOK = MenuBarController.permissionsOK()

    var body: some View {
        Form {
            Section("Автопереключение") {
                Toggle("Включено", isOn: $service.isEnabled)
                Toggle("Звук при исправлении", isOn: $service.isSoundEnabled)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Исправлять на лету от \(Int(service.minLiveLength)) букв")
                    Slider(value: $service.minLiveLength, in: 3...8, step: 1)
                    Text("Срабатывает, когда набранный префикс ещё не существует в текущем языке, но в другом языке это начало реального слова.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Короткие слова от \(Int(service.minBoundaryLength)) букв — исправлять на пробеле")
                    Slider(value: $service.minBoundaryLength, in: 2...6, step: 1)
                }
            }

            Section("Статус") {
                LabeledContent("Словари", value: service.dictionariesLoaded ? "загружены" : "загрузка…")
                LabeledContent("Раскладки", value: service.statusSummary)
                LabeledContent("Последнее исправление",
                               value: service.lastFixAt.map { $0.formatted(date: .omitted, time: .standard) } ?? "—")
                HStack(spacing: 8) {
                    if permissionsOK {
                        Label("Разрешения выданы", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Нужны Accessibility и Input Monitoring", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Button("Открыть настройки") { openPermissions() }
                            .buttonStyle(.link)
                    }
                    Spacer()
                }
                Button("Перезапустить слежение") {
                    service.stopTap()
                    _ = service.startTap()
                    permissionsOK = MenuBarController.permissionsOK()
                }
            }

            Section("Система") {
                Toggle("Запускать при входе в систему", isOn: $service.launchAtLogin)
                Text("Полноценно работает, когда приложение лежит в папке «Программы».")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Исключения") {
                Text("Автопереключение отключено в терминалах (Terminal, iTerm2, Warp, kitty, Alacritty, Ghostty) и в полях пароля — там исправлять ввод опасно.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Отладка") {
                Toggle("Журнал отладки (пишет нажатые клавиши, только локально)", isOn: $service.isDebugLogEnabled)
                HStack {
                    Button("Открыть журнал") {
                        NSWorkspace.shared.activateFileViewerSelecting([Log.shared.fileURL])
                    }
                    Spacer()
                }
                Text(Log.shared.path)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("О приложении") {
                LabeledContent("Версия", value: "0.2.0")
                LabeledContent("Словари", value: "FrequencyWords · OpenSubtitles 2018")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 640)
        .onAppear { permissionsOK = MenuBarController.permissionsOK() }
    }

    private func openPermissions() {
        for path in [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ] {
            if let url = URL(string: path) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
