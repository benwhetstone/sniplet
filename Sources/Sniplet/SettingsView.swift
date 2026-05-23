import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 0.99),
                    Color(red: 0.92, green: 0.95, blue: 0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PreferenceCard(title: "Capture") {
                        VStack(alignment: .leading, spacing: 14) {
                            ShortcutRow(label: "Selection", shortcut: "Control-Shift-4")
                            ShortcutRow(label: "Current screen", shortcut: "Control-Shift-3")
                            ShortcutRow(label: "Selection + markup", shortcut: "Control-Option-4")
                            ShortcutRow(label: "Current screen + markup", shortcut: "Control-Option-3")
                            Divider()
                            Toggle("Save a compressed JPG copy into my default folder", isOn: $settings.saveToDisk)
                            Toggle("Open markup after every capture", isOn: $settings.openMarkupAfterCapture)
                        }
                    }

                    PreferenceCard(title: "Storage") {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Button("Choose Folder") {
                                    settings.chooseFolder()
                                }
                                .buttonStyle(.borderedProminent)

                                Button("Trash Saved Captures") {
                                    settings.trashScreenshotFolderContents()
                                }
                                .buttonStyle(.bordered)
                                .disabled(settings.selectedFolderPath == nil)

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

                            Text("Saved captures are written as compressed JPG files. Markup saves overwrite the existing captured file in this folder.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let storageMessage = settings.storageMessage {
                                Text(storageMessage)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(red: 0.33, green: 0.39, blue: 0.22))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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

                            Text("This works best from the packaged app installed in Applications.")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let launchAtLoginMessage = settings.launchAtLoginMessage {
                                Text(launchAtLoginMessage)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(red: 0.64, green: 0.23, blue: 0.12))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Spacer(minLength: 28)
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 42)
            }
        }
        .frame(minWidth: 620, minHeight: 600)
    }
}

private struct PreferenceCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.7)
                .foregroundStyle(.secondary)

            content
                .font(.system(size: 14, weight: .medium, design: .rounded))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 12)
    }
}

private struct ShortcutRow: View {
    let label: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.7), in: Capsule())
        }
    }
}
