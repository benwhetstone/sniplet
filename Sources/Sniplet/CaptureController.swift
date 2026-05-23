import AppKit
import CoreGraphics

@MainActor
final class CaptureController {
    private let settings: AppSettings
    private let markupCoordinator: MarkupCoordinator
    private var overlayWindow: SelectionOverlayWindow?

    init(settings: AppSettings, markupCoordinator: MarkupCoordinator) {
        self.settings = settings
        self.markupCoordinator = markupCoordinator
    }

    func startSelectionCapture(openMarkup: Bool) {
        guard ensureReadyForCapture(openMarkup: openMarkup) else { return }
        guard overlayWindow == nil else { return }

        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            return
        }

        let overlayWindow = SelectionOverlayWindow(screen: screen) { [weak self] rect in
            self?.overlayWindow?.orderOut(nil)
            self?.overlayWindow = nil
            guard let rect else { return }
            self?.capture(rect: rect, on: screen, openMarkup: openMarkup)
        }

        self.overlayWindow = overlayWindow
        overlayWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func captureCurrentScreen(openMarkup: Bool) {
        guard ensureReadyForCapture(openMarkup: openMarkup) else { return }

        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        guard let screen = targetScreen else { return }

        capture(rect: screen.frame, on: screen, openMarkup: openMarkup)
    }

    func requestScreenRecordingAccess() {
        if CGPreflightScreenCaptureAccess() {
            showAlert(
                title: "Screen Recording Already Allowed",
                message: "Sniplet already has the permission it needs."
            )
            return
        }

        let granted = CGRequestScreenCaptureAccess()
        showAlert(
            title: granted ? "Permission Granted" : "Permission Needed",
            message: granted
                ? "You can start capturing with Control-Shift-4 for a region or Control-Shift-3 for the current screen."
                : "Allow Screen Recording for Sniplet in System Settings, then try again."
        )
    }

    private func ensureReadyForCapture(openMarkup: Bool) -> Bool {
        guard ensureScreenRecordingPermission() else { return false }

        if (openMarkup || settings.openMarkupAfterCapture), settings.screenshotFolderURL() == nil {
            showAlert(
                title: "Choose a Folder First",
                message: "Markup mode overwrites the saved capture, so Sniplet needs a default screenshot folder before you edit."
            )
            return false
        }

        return true
    }

    private func ensureScreenRecordingPermission() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        let granted = CGRequestScreenCaptureAccess()
        if !granted {
            showAlert(
                title: "Screen Recording Required",
                message: "Turn on Screen Recording for Sniplet in System Settings to enable captures."
            )
        }
        return granted
    }

    private func capture(rect: CGRect, on screen: NSScreen, openMarkup: Bool) {
        guard let displayID = screen.displayID,
              let displayImage = CGDisplayCreateImage(displayID),
              let cropRect = cropRect(for: rect, within: screen.frame, image: displayImage),
              let croppedImage = displayImage.cropping(to: cropRect)
        else {
            showAlert(
                title: "Capture Failed",
                message: "Sniplet could not read the selected pixels."
            )
            return
        }

        let shouldOpenMarkup = openMarkup || settings.openMarkupAfterCapture
        let shouldSave = settings.saveToDisk || shouldOpenMarkup
        let savedCapture = ClipboardWriter.copy(
            image: croppedImage,
            displaySize: rect.size,
            saveTo: shouldSave ? settings.screenshotFolderURL() : nil
        )

        if shouldSave, savedCapture == nil {
            showAlert(
                title: "Save Failed",
                message: "The screenshot was copied to the clipboard, but Sniplet could not save the image file."
            )
            return
        }

        if shouldOpenMarkup, let savedCapture {
            markupCoordinator.openEditor(for: savedCapture)
        }
    }

    private func cropRect(for selection: CGRect, within screenFrame: CGRect, image: CGImage) -> CGRect? {
        SnipletGeometry.captureCropRect(
            selection: selection,
            within: screenFrame,
            imageSize: CGSize(width: image.width, height: image.height)
        )
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}
