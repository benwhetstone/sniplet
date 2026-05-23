import AppKit
import ImageIO
import UniformTypeIdentifiers

struct SavedCapture {
    let image: NSImage
    let fileURL: URL
    let displaySize: CGSize
}

enum ClipboardWriter {
    static let maxExportDimension: CGFloat = 1800
    private static let jpegQualityCandidates: [CGFloat] = [0.74, 0.66, 0.58, 0.50, 0.42, 0.36]
    private static let minJPEGByteCount = 220_000
    private static let maxJPEGByteCount = 850_000

    @discardableResult
    static func copy(image: CGImage, displaySize: CGSize, saveTo folderURL: URL?) -> SavedCapture? {
        let clipboardImage = nsImage(from: image, displaySize: displaySize)
        let normalized = normalizedImage(from: image)

        writeToPasteboard(image: clipboardImage)
        NSSound(named: "Glass")?.play()

        guard let folderURL else { return nil }
        return persistImage(image: normalized, displaySize: displaySize, to: folderURL)
    }

    static func overwrite(image: NSImage, at fileURL: URL, displaySize: CGSize) -> Bool {
        let normalized = normalizedImage(from: image)
        guard let data = imageData(for: normalized, fileExtension: fileURL.pathExtension) else { return false }

        do {
            let tempURL = fileURL.deletingLastPathComponent()
                .appendingPathComponent(".\(UUID().uuidString).tmp")
            try data.write(to: tempURL, options: .atomic)
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
            writeToPasteboard(image: imageForPasteboard(from: image, displaySize: displaySize))
            return true
        } catch {
            return false
        }
    }

    private static func persistImage(image: NSImage, displaySize: CGSize, to folderURL: URL) -> SavedCapture? {
        guard folderURL.startAccessingSecurityScopedResource() else { return nil }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        guard let data = jpegData(for: image) else { return nil }
        let fileURL = captureFileURL(in: folderURL, date: Date(), fileManager: .default)

        do {
            try data.write(to: fileURL, options: .atomic)
            return SavedCapture(image: image, fileURL: fileURL, displaySize: displaySize)
        } catch {
            return nil
        }
    }

    private static func normalizedImage(from image: CGImage) -> NSImage {
        normalizedImage(from: nsImage(from: image))
    }

    private static func normalizedImage(from image: NSImage) -> NSImage {
        let targetSize = constrainedSize(for: image.size)
        let normalized = NSImage(size: targetSize)
        normalized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: CGRect(origin: .zero, size: targetSize), from: .zero, operation: .copy, fraction: 1)
        normalized.unlockFocus()
        return normalized
    }

    static func constrainedSize(for size: NSSize) -> NSSize {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxExportDimension, longestSide > 0 else { return size }
        let scale = maxExportDimension / longestSide
        return NSSize(width: floor(size.width * scale), height: floor(size.height * scale))
    }

    private static func nsImage(from image: CGImage, displaySize: CGSize? = nil) -> NSImage {
        let rep = NSBitmapImageRep(cgImage: image)
        let resolvedSize = displaySize.map { NSSize(width: $0.width, height: $0.height) }
            ?? NSSize(width: image.width, height: image.height)
        let nsImage = NSImage(size: resolvedSize)
        nsImage.addRepresentation(rep)
        return nsImage
    }

    private static func imageForPasteboard(from image: NSImage, displaySize: CGSize) -> NSImage {
        let copy = NSImage(size: NSSize(width: displaySize.width, height: displaySize.height))
        for representation in image.representations {
            copy.addRepresentation(representation)
        }
        return copy
    }

    private static func writeToPasteboard(image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        var declaredTypes: [NSPasteboard.PasteboardType] = []
        if pngData(for: image) != nil {
            declaredTypes.append(.png)
        }
        if let tiffData = image.tiffRepresentation, !tiffData.isEmpty {
            declaredTypes.append(.tiff)
        }

        pasteboard.declareTypes(declaredTypes, owner: nil)

        if let pngData = pngData(for: image) {
            pasteboard.setData(pngData, forType: .png)
        }
        if let tiffData = image.tiffRepresentation, !tiffData.isEmpty {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }

    private static func imageData(for image: NSImage, fileExtension: String) -> Data? {
        switch fileExtension.lowercased() {
        case "png":
            return pngData(for: image)
        default:
            return jpegData(for: image)
        }
    }

    private static func jpegData(for image: NSImage) -> Data? {
        guard let cgImage = cgImage(from: image) else { return nil }

        let targetByteCount = targetJPEGByteCount(for: image.size)
        var bestAttempt: Data?

        for quality in jpegQualityCandidates {
            guard let data = encodedJPEGData(from: cgImage, quality: quality) else { continue }
            bestAttempt = data
            if data.count <= targetByteCount {
                return data
            }
        }

        return bestAttempt
    }

    private static func pngData(for image: NSImage) -> Data? {
        guard let cgImage = cgImage(from: image) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func cgImage(from image: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }

    static func targetJPEGByteCount(for size: NSSize) -> Int {
        let megapixels = max(0.2, (size.width * size.height) / 1_000_000)
        let scaledBudget = Int(megapixels * 240_000)
        return min(maxJPEGByteCount, max(minJPEGByteCount, scaledBudget))
    }

    static func captureFileURL(in folderURL: URL, date: Date, fileManager: FileManager) -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        let stem = "Sniplet_\(formatter.string(from: date))"
        let ext = "jpg"
        var candidate = folderURL.appendingPathComponent(stem).appendingPathExtension(ext)
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = folderURL
                .appendingPathComponent("\(stem)-\(suffix)")
                .appendingPathExtension(ext)
            suffix += 1
        }

        return candidate
    }

    private static func encodedJPEGData(from image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }

        let options: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
