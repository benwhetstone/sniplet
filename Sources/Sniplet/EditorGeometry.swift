import CoreGraphics

enum SnipletGeometry {
    static let textHorizontalPadding: CGFloat = 8
    static let textVerticalPadding: CGFloat = 4
    static let textSelectionInset: CGFloat = 4

    static func captureCropRect(selection: CGRect, within screenFrame: CGRect, imageSize: CGSize) -> CGRect? {
        let intersection = selection.intersection(screenFrame).integral
        guard !intersection.isNull, !intersection.isEmpty, screenFrame.width > 0, screenFrame.height > 0 else {
            return nil
        }

        let scaleX = imageSize.width / screenFrame.width
        let scaleY = imageSize.height / screenFrame.height
        let localMinX = intersection.minX - screenFrame.minX
        let localMaxY = intersection.maxY - screenFrame.minY

        return CGRect(
            x: localMinX * scaleX,
            y: imageSize.height - (localMaxY * scaleY),
            width: intersection.width * scaleX,
            height: intersection.height * scaleY
        ).integral
    }

    static func constrainedCropRect(from start: CGPoint, to end: CGPoint, aspectRatio: CGFloat?) -> CGRect {
        let rawRect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )

        guard let aspectRatio, rawRect.width > 0, rawRect.height > 0 else {
            return rawRect
        }

        let directionX: CGFloat = end.x >= start.x ? 1 : -1
        let directionY: CGFloat = end.y >= start.y ? 1 : -1

        let widthFromHeight = rawRect.height * aspectRatio
        let heightFromWidth = rawRect.width / aspectRatio

        let resolvedWidth: CGFloat
        let resolvedHeight: CGFloat

        if widthFromHeight <= rawRect.width {
            resolvedWidth = widthFromHeight
            resolvedHeight = rawRect.height
        } else {
            resolvedWidth = rawRect.width
            resolvedHeight = heightFromWidth
        }

        let x = directionX >= 0 ? start.x : start.x - resolvedWidth
        let y = directionY >= 0 ? start.y : start.y - resolvedHeight
        return CGRect(x: x, y: y, width: resolvedWidth, height: resolvedHeight).standardized
    }

    static func boundedTranslation(for bounds: CGRect?, proposed delta: CGPoint) -> CGPoint {
        guard let bounds else {
            return CGPoint(
                x: min(max(delta.x, -1), 1),
                y: min(max(delta.y, -1), 1)
            )
        }

        return CGPoint(
            x: min(max(delta.x, -bounds.minX), 1 - bounds.maxX),
            y: min(max(delta.y, -bounds.minY), 1 - bounds.maxY)
        )
    }

    static func textBackgroundRect(anchor: CGPoint, textSize: CGSize) -> CGRect {
        CGRect(
            x: anchor.x,
            y: anchor.y - (textSize.height / 2) - textVerticalPadding,
            width: textSize.width + (textHorizontalPadding * 2),
            height: textSize.height + (textVerticalPadding * 2)
        )
    }

    static func textSelectionRect(anchor: CGPoint, textSize: CGSize) -> CGRect {
        textBackgroundRect(anchor: anchor, textSize: textSize)
            .insetBy(dx: -textSelectionInset, dy: -textSelectionInset)
    }

    static func textDrawPoint(anchor: CGPoint, textSize: CGSize) -> CGPoint {
        CGPoint(
            x: anchor.x + textHorizontalPadding,
            y: anchor.y - (textSize.height / 2)
        )
    }

    static func normalizedRect(_ rect: CGRect, in imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        return CGRect(
            x: rect.minX / imageSize.width,
            y: rect.minY / imageSize.height,
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height
        )
    }

    static func renderedImagePoint(from normalizedPoint: CGPoint, imageSize: CGSize) -> CGPoint {
        CGPoint(
            x: normalizedPoint.x * imageSize.width,
            y: normalizedPoint.y * imageSize.height
        )
    }
}
