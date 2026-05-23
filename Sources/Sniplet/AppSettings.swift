import AppKit
import Foundation
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    @Published var saveToDisk: Bool {
        didSet { defaults.set(saveToDisk, forKey: Keys.saveToDisk) }
    }

    @Published var openMarkupAfterCapture: Bool {
        didSet { defaults.set(openMarkupAfterCapture, forKey: Keys.openMarkupAfterCapture) }
    }

    @Published private(set) var selectedFolderPath: String?
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginMessage: String?
    @Published private(set) var storageMessage: String?

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    private let defaults = UserDefaults.standard

    init() {
        saveToDisk = defaults.object(forKey: Keys.saveToDisk) as? Bool ?? true
        openMarkupAfterCapture = defaults.bool(forKey: Keys.openMarkupAfterCapture)
        selectedFolderPath = nil
        resolveStoredFolderPath()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"

        if panel.runModal() == .OK, let url = panel.url {
            storeFolderBookmark(for: url)
        }
    }

    func clearFolder() {
        defaults.removeObject(forKey: Keys.folderBookmark)
        selectedFolderPath = nil
        storageMessage = nil
    }

    func trashScreenshotFolderContents() {
        guard let folderURL = screenshotFolderURL() else {
            storageMessage = "Choose a screenshot folder first."
            return
        }

        let alert = NSAlert()
        alert.messageText = "Send Saved Captures To Trash?"
        alert.informativeText = "Sniplet will move everything inside your screenshot folder to the Trash. The folder itself will stay in place."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Send To Trash")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard folderURL.startAccessingSecurityScopedResource() else {
            storageMessage = "Sniplet could not access the screenshot folder."
            return
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            guard !contents.isEmpty else {
                storageMessage = "The screenshot folder is already empty."
                return
            }

            var trashedCount = 0
            for itemURL in contents {
                var resultingURL: NSURL?
                try fileManager.trashItem(at: itemURL, resultingItemURL: &resultingURL)
                trashedCount += 1
            }

            storageMessage = trashedCount == 1
                ? "Moved 1 item to the Trash."
                : "Moved \(trashedCount) items to the Trash."
        } catch {
            storageMessage = "Sniplet could not move the folder contents to the Trash."
        }
    }

    func screenshotFolderURL() -> URL? {
        guard let bookmarkData = defaults.data(forKey: Keys.folderBookmark) else {
            return nil
        }

        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale, let url {
            storeFolderBookmark(for: url)
        }

        return url
    }

    func refreshLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        } else {
            launchAtLoginEnabled = false
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            launchAtLoginMessage = "Launch at login needs macOS 13 or newer."
            launchAtLoginEnabled = false
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginMessage = nil
        } catch {
            launchAtLoginMessage = "This toggle works after Sniplet is packaged as a normal app bundle. The source build still runs fine for development."
        }

        refreshLaunchAtLoginState()
    }

    private func resolveStoredFolderPath() {
        selectedFolderPath = screenshotFolderURL()?.path
    }

    private func storeFolderBookmark(for url: URL) {
        let bookmark = try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        defaults.set(bookmark, forKey: Keys.folderBookmark)
        selectedFolderPath = url.path
        storageMessage = nil
    }
}

private enum Keys {
    static let saveToDisk = "saveToDisk"
    static let openMarkupAfterCapture = "openMarkupAfterCapture"
    static let folderBookmark = "folderBookmark"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}
