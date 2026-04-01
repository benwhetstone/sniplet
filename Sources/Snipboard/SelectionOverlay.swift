import AppKit

final class SelectionOverlayWindow: NSWindow {
    init(screen: NSScreen, completion: @escaping (CGRect?) -> Void) {
        super.init(
            contentRect: CGRect(origin: .zero, size: screen.frame.size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        let overlayView = SelectionOverlayView(screenFrame: screen.frame, completion: completion)
        contentView = overlayView
        setFrame(screen.frame, display: true)
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { true }
}

final class SelectionOverlayView: NSView {
    private let screenFrame: CGRect
    private let completion: (CGRect?) -> Void
    private var dragStartPoint: CGPoint?
    private var currentPoint: CGPoint?

    init(screenFrame: CGRect, completion: @escaping (CGRect?) -> Void) {
        self.screenFrame = screenFrame
        self.completion = completion
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.22).setFill()
        dirtyRect.fill()

        guard let selectionRect else { return }

        NSColor.clear.setFill()
        selectionRect.fill(using: .copy)

        let path = NSBezierPath(rect: selectionRect)
        NSColor.white.setStroke()
        path.lineWidth = 2
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        dragStartPoint = convert(event.locationInWindow, from: nil)
        currentPoint = dragStartPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        defer {
            dragStartPoint = nil
            currentPoint = nil
            needsDisplay = true
        }

        guard let selectionRect, selectionRect.width >= 4, selectionRect.height >= 4 else {
            completion(nil)
            return
        }

        let screenRect = CGRect(
            x: screenFrame.minX + selectionRect.minX,
            y: screenFrame.minY + selectionRect.minY,
            width: selectionRect.width,
            height: selectionRect.height
        )
        completion(screenRect.integral)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            completion(nil)
        } else {
            super.keyDown(with: event)
        }
    }

    private var selectionRect: CGRect? {
        guard let dragStartPoint, let currentPoint else { return nil }
        return CGRect(
            x: min(dragStartPoint.x, currentPoint.x),
            y: min(dragStartPoint.y, currentPoint.y),
            width: abs(currentPoint.x - dragStartPoint.x),
            height: abs(currentPoint.y - dragStartPoint.y)
        )
    }
}
