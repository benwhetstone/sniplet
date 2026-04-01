import AppKit
import ImageIO
import UniformTypeIdentifiers

struct SavedCapture {
    let image: NSImage
    let fileURL: URL
}

enum ClipboardWriter {
    private static let maxExportDimension: CGFloat = 2800
    private static let jpegQuality: CGFloat = 0.72

    @discardableResult
    static func copy(image: CGImage, saveTo folderURL: URL?) -> SavedCapture? {
        let normalized = normalizedImage(from: image)

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([normalized])
        NSSound(named: "Glass")?.play()

        guard let folderURL else { return nil }
        return persistImage(image: normalized, to: folderURL)
    }

    static func overwrite(image: NSImage, at fileURL: URL) -> Bool {
        let normalized = normalizedImage(from: image)
        guard let data = imageData(for: normalized, fileExtension: fileURL.pathExtension) else { return false }

        do {
            try data.write(to: fileURL, options: .atomic)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([normalized])
            return true
        } catch {
            return false
        }
    }

    private static func persistImage(image: NSImage, to folderURL: URL) -> SavedCapture? {
        guard folderURL.startAccessingSecurityScopedResource() else { return nil }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        guard let data = jpegData(for: image) else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let fileURL = folderURL.appendingPathComponent("Sniplet_\(formatter.string(from: Date())).jpg")

        do {
            try data.write(to: fileURL, options: .atomic)
            return SavedCapture(image: image, fileURL: fileURL)
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

    private static func constrainedSize(for size: NSSize) -> NSSize {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxExportDimension, longestSide > 0 else { return size }
        let scale = maxExportDimension / longestSide
        return NSSize(width: floor(size.width * scale), height: floor(size.height * scale))
    }

    private static func nsImage(from image: CGImage) -> NSImage {
        let rep = NSBitmapImageRep(cgImage: image)
        let nsImage = NSImage(size: NSSize(width: image.width, height: image.height))
        nsImage.addRepresentation(rep)
        return nsImage
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
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let options: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: jpegQuality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, options)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
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
}
