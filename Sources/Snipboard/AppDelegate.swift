import AppKit
import Carbon
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private let updater = AppUpdater()
    private lazy var markupCoordinator = MarkupCoordinator(settings: settings)
    private lazy var captureController = CaptureController(
        settings: settings,
        markupCoordinator: markupCoordinator
    )

    private var statusItem: NSStatusItem?
    private var hotKeyManager: HotKeyManager?
    private var settingsWindowController: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHotKeys()
        settings.refreshLaunchAtLoginState()

        if !settings.hasCompletedOnboarding {
            openSettings()
            settings.hasCompletedOnboarding = true
        }
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "camera.viewfinder",
            accessibilityDescription: "Sniplet"
        )
        statusItem.button?.toolTip = "Sniplet"
        statusItem.menu = makeMenu()
        self.statusItem = statusItem
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let titleItem = NSMenuItem(title: "Sniplet", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        titleItem.attributedTitle = NSAttributedString(
            string: "Sniplet",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            menuItem(
                title: "Capture Selection    ctrl-shift-4",
                action: #selector(captureSelection)
            )
        )
        menu.addItem(
            menuItem(
                title: "Capture Selection + Markup    ctrl-opt-4",
                action: #selector(captureSelectionWithMarkup)
            )
        )
        menu.addItem(
            menuItem(
                title: "Capture Current Screen    ctrl-shift-3",
                action: #selector(captureCurrentScreen)
            )
        )
        menu.addItem(
            menuItem(
                title: "Capture Current Screen + Markup    ctrl-opt-3",
                action: #selector(captureCurrentScreenWithMarkup)
            )
        )
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(title: "About \(aboutMenuTitle)", action: #selector(showAbout)))
        menu.addItem(menuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(menuItem(title: "Update Sniplet", action: #selector(updateApp)))
        menu.addItem(menuItem(title: "Request Screen Recording Access", action: #selector(requestPermissions)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(menuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        return menu
    }

    private func menuItem(
        title: String,
        action: Selector,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private func setupHotKeys() {
        hotKeyManager = HotKeyManager(handler: { [weak self] hotKey in
            Task { @MainActor [weak self] in
                switch hotKey {
                case .selection:
                    self?.captureController.startSelectionCapture(openMarkup: false)
                case .currentScreen:
                    self?.captureController.captureCurrentScreen(openMarkup: false)
                case .selectionWithMarkup:
                    self?.captureController.startSelectionCapture(openMarkup: true)
                case .currentScreenWithMarkup:
                    self?.captureController.captureCurrentScreen(openMarkup: true)
                }
            }
        })

        hotKeyManager?.register(
            .selection,
            keyCode: UInt32(kVK_ANSI_4),
            modifiers: UInt32(controlKey) | UInt32(shiftKey)
        )
        hotKeyManager?.register(
            .currentScreen,
            keyCode: UInt32(kVK_ANSI_3),
            modifiers: UInt32(controlKey) | UInt32(shiftKey)
        )
        hotKeyManager?.register(
            .selectionWithMarkup,
            keyCode: UInt32(kVK_ANSI_4),
            modifiers: UInt32(controlKey) | UInt32(optionKey)
        )
        hotKeyManager?.register(
            .currentScreenWithMarkup,
            keyCode: UInt32(kVK_ANSI_3),
            modifiers: UInt32(controlKey) | UInt32(optionKey)
        )
    }

    @objc
    private func captureSelection() {
        captureController.startSelectionCapture(openMarkup: false)
    }

    @objc
    private func captureSelectionWithMarkup() {
        captureController.startSelectionCapture(openMarkup: true)
    }

    @objc
    private func captureCurrentScreen() {
        captureController.captureCurrentScreen(openMarkup: false)
    }

    @objc
    private func captureCurrentScreenWithMarkup() {
        captureController.captureCurrentScreen(openMarkup: true)
    }

    @objc
    private func showPreferences() {
        openSettings()
    }

    @objc
    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Sniplet"
        alert.informativeText = "Version \(appVersionString)\nDesigned by Ben Whetstone, 2026"
        alert.runModal()
    }

    @objc
    private func requestPermissions() {
        captureController.requestScreenRecordingAccess()
    }

    @objc
    private func updateApp() {
        updater.installLatestAvailableBuild()
    }

    @objc
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func openSettings() {
        if let existingWindow = settingsWindowController?.window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = SettingsView(settings: settings)
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Sniplet"
        window.setContentSize(NSSize(width: 620, height: 600))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        settingsWindowController = controller
        NSApp.activate(ignoringOtherApps: true)
    }

    private var aboutMenuTitle: String {
        "Sniplet \(appVersionString)"
    }

    private var appVersionString: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(shortVersion) (\(buildVersion))"
    }
}
