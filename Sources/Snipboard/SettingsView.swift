import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.97, blue: 0.99),
                    Color(red: 0.90, green: 0.94, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sniplet")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                    Text("A tiny screenshot app for macOS with quick snips, quick paste, and easy markup.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                PreferenceCard(title: "Capture Flow") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Selection: Control-Shift-4")
                        Text("Current screen: Control-Shift-3")
                        Toggle("Save a PNG copy into my default folder", isOn: $settings.saveToDisk)
                        Toggle("Open markup mode after every capture", isOn: $settings.openMarkupAfterCapture)
                    }
                }

                PreferenceCard(title: "Storage") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Button("Choose Folder") {
                                settings.chooseFolder()
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Clear Folder") {
                                settings.clearFolder()
                            }
                            .buttonStyle(.bordered)
                            .disabled(settings.selectedFolderPath == nil)
                        }

                        Text(settings.selectedFolderPath ?? "No folder selected yet.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)

                        Text("Edited screenshots overwrite their original saved PNG in this folder.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                PreferenceCard(title: "Startup") {
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(
                            "Launch Sniplet when I sign in",
                            isOn: Binding(
                                get: { settings.launchAtLoginEnabled },
                                set: { settings.setLaunchAtLogin($0) }
                            )
                        )

                        Text("If this is off while you are testing from source, that is expected.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)

                        if let launchAtLoginMessage = settings.launchAtLoginMessage {
                            Text(launchAtLoginMessage)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(red: 0.64, green: 0.23, blue: 0.12))
                        }
                    }
                }

                Spacer()
            }
            .padding(28)
        }
        .frame(minWidth: 540, minHeight: 520)
    }
}

private struct PreferenceCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)

            content
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.86))
                .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
    }
}
