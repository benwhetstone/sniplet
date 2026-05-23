import CoreGraphics
import AppKit
import Foundation
import Testing
@testable import Sniplet

@Test
func cropIntersectionReturnsExpectedRect() {
    let cropRect = SnipletGeometry.captureCropRect(
        selection: CGRect(x: 10, y: 20, width: 30, height: 40),
        within: CGRect(x: 0, y: 0, width: 100, height: 100),
        imageSize: CGSize(width: 200, height: 200)
    )

    #expect(cropRect == CGRect(x: 20, y: 80, width: 60, height: 80))
}

@Test
func constrainedCropRectHonorsAspectRatio() {
    let result = SnipletGeometry.constrainedCropRect(
        from: CGPoint(x: 0.10, y: 0.10),
        to: CGPoint(x: 0.70, y: 0.60),
        aspectRatio: 1
    )

    #expect(abs(result.width - result.height) < 0.0001)
    #expect(result.minX == 0.10)
    #expect(result.minY == 0.10)
}

@Test
func boundedTranslationKeepsBoundsInsideCanvas() {
    let bounded = SnipletGeometry.boundedTranslation(
        for: CGRect(x: 0.80, y: 0.15, width: 0.18, height: 0.20),
        proposed: CGPoint(x: 0.10, y: -0.30)
    )

    #expect(abs(bounded.x - 0.02) < 0.0001)
    #expect(abs(bounded.y + 0.15) < 0.0001)
}

@Test
func constrainedSizeLeavesSmallerImagesUntouched() {
    let original = NSSize(width: 1400, height: 900)
    let result = ClipboardWriter.constrainedSize(for: original)
    #expect(result == original)
}

@Test
func constrainedSizeCapsLongestSide() {
    let result = ClipboardWriter.constrainedSize(for: NSSize(width: 4400, height: 2200))
    #expect(result.width == ClipboardWriter.maxExportDimension)
    #expect(result.height == 900)
}

@Test
func jpegBudgetScalesWithImageArea() {
    let small = ClipboardWriter.targetJPEGByteCount(for: NSSize(width: 900, height: 700))
    let large = ClipboardWriter.targetJPEGByteCount(for: NSSize(width: 2200, height: 1600))

    #expect(small >= 220_000)
    #expect(large > small)
    #expect(large <= 850_000)
}

@Test
func captureFileURLAvoidsTimestampCollisions() throws {
    let fileManager = FileManager.default
    let folderURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: folderURL) }

    let fixedDate = Date(timeIntervalSince1970: 1_775_334_428)
    let firstURL = ClipboardWriter.captureFileURL(in: folderURL, date: fixedDate, fileManager: fileManager)
    try Data().write(to: firstURL)

    let secondURL = ClipboardWriter.captureFileURL(in: folderURL, date: fixedDate, fileManager: fileManager)

    #expect(firstURL.pathExtension == "jpg")
    #expect(secondURL.pathExtension == "jpg")
    #expect(secondURL.lastPathComponent.hasSuffix("-2.jpg"))
    #expect(secondURL.deletingPathExtension().lastPathComponent == "\(firstURL.deletingPathExtension().lastPathComponent)-2")
}

@Test
func textSelectionRectUsesLeadingAnchor() {
    let rect = SnipletGeometry.textSelectionRect(
        anchor: CGPoint(x: 120, y: 80),
        textSize: CGSize(width: 100, height: 24)
    )

    #expect(rect.minX == 116)
    #expect(rect.maxX == 240)
    #expect(rect.minY == 60)
    #expect(rect.maxY == 100)
}

@Test
func renderedImagePointMatchesFlippedImageContext() {
    let point = SnipletGeometry.renderedImagePoint(
        from: CGPoint(x: 0.25, y: 0.75),
        imageSize: CGSize(width: 400, height: 200)
    )

    #expect(point.x == 100)
    #expect(point.y == 50)
}

@Test
func constrainedSizeStillReducesLargeSavedExports() {
    let original = NSSize(width: 4200, height: 2800)
    let result = ClipboardWriter.constrainedSize(for: original)

    #expect(result.width < original.width)
    #expect(result.height < original.height)
    #expect(max(result.width, result.height) == ClipboardWriter.maxExportDimension)
}

@Test
@MainActor
func updaterRecognizesNewerSemanticVersion() {
    let updater = AppUpdater()

    #expect(updater.releaseVersion(from: "v0.6.1") == "0.6.1")
    #expect(updater.isNewerRelease("0.6.1", than: "0.6.0"))
    #expect(!updater.isNewerRelease("0.6.0", than: "0.6.0"))
}

@Test
@MainActor
func updaterPrefersDmgAssetFromRelease() {
    let updater = AppUpdater()
    let release = GitHubRelease(
        tagName: "v0.6.1",
        htmlURL: URL(string: "https://github.com/benwhetstone/sniplet/releases/tag/v0.6.1")!,
        assets: [
            GitHubReleaseAsset(
                name: "Sniplet.zip",
                browserDownloadURL: URL(string: "https://example.com/Sniplet.zip")!
            ),
            GitHubReleaseAsset(
                name: "Sniplet-Installer.dmg",
                browserDownloadURL: URL(string: "https://example.com/Sniplet-Installer.dmg")!
            )
        ]
    )

    #expect(updater.releaseDownloadURL(from: release)?.absoluteString == "https://example.com/Sniplet-Installer.dmg")
}
