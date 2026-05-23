import AppKit
import CoreImage
import SwiftUI

@MainActor
final class MarkupCoordinator {
    private let settings: AppSettings
    private var windows: [URL: NSWindowController] = [:]

    init(settings: AppSettings) {
        self.settings = settings
    }

    func openEditor(for capture: SavedCapture) {
        if let existing = windows[capture.fileURL] {
            existing.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = MarkupEditorView(
            initialImage: capture.image,
            fileURL: capture.fileURL
        ) { [weak self] image, url in
            let success = ClipboardWriter.overwrite(image: image, at: url, displaySize: capture.displaySize)
            if !success {
                let alert = NSAlert()
                alert.messageText = "Save Failed"
                alert.informativeText = "Sniplet could not overwrite the edited screenshot."
                alert.runModal()
            }
            self?.windows[url]?.close()
            self?.windows[url] = nil
        }

        let hostingController = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Sniplet Markup"
        window.setContentSize(NSSize(width: 1560, height: 1040))
        window.minSize = NSSize(width: 1360, height: 920)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.center()

        let controller = NSWindowController(window: window)
        windows[capture.fileURL] = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private enum MarkupTool: String, CaseIterable, Identifiable {
    case move = "Move"
    case pen = "Pen"
    case highlighter = "Highlight"
    case arrow = "Arrow"
    case rectangle = "Box"
    case ellipse = "Circle"
    case blur = "Blur"
    case redact = "Redact"
    case text = "Text"
    case symbol = "Symbol"

    var id: String { rawValue }

    var drawsByDrag: Bool {
        switch self {
        case .pen, .highlighter, .arrow, .rectangle, .ellipse, .blur, .redact:
            return true
        case .move, .text, .symbol:
            return false
        }
    }
}

private enum MarkupFontChoice: String, CaseIterable, Identifiable {
    case rounded = "Rounded"
    case avenir = "Avenir"
    case helvetica = "Helvetica"
    case georgia = "Georgia"
    case noteworthy = "Noteworthy"
    case mono = "Menlo"

    var id: String { rawValue }
}

private enum TextBackgroundChoice: String, CaseIterable, Identifiable {
    case clear = "None"
    case white = "White"
    case black = "Black"
    case yellow = "Yellow"
    case blue = "Blue"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .clear: return .clear
        case .white: return .white.opacity(0.92)
        case .black: return Color.black.opacity(0.82)
        case .yellow: return Color(red: 0.98, green: 0.93, blue: 0.45, opacity: 0.95)
        case .blue: return Color(red: 0.83, green: 0.91, blue: 0.98, opacity: 0.96)
        }
    }
}

private enum CropPreset: String, CaseIterable, Identifiable {
    case freeform = "Freeform"
    case square = "Instagram Square"
    case portrait = "Portrait 4:5"
    case story = "Story 9:16"
    case landscape = "Landscape 16:9"

    var id: String { rawValue }

    var ratio: CGFloat? {
        switch self {
        case .freeform: return nil
        case .square: return 1
        case .portrait: return 4.0 / 5.0
        case .story: return 9.0 / 16.0
        case .landscape: return 16.0 / 9.0
        }
    }
}

private enum MarkupShapeKind {
    case arrow
    case rectangle
    case ellipse
    case blur
    case redact
}

private enum MarkupItem: Identifiable {
    case stroke(MarkupStroke)
    case shape(MarkupShape)
    case text(MarkupText)
    case symbol(MarkupSymbol)

    var id: UUID {
        switch self {
        case .stroke(let stroke):
            stroke.id
        case .shape(let shape):
            shape.id
        case .text(let text):
            text.id
        case .symbol(let symbol):
            symbol.id
        }
    }
}

private struct MarkupStroke {
    let id = UUID()
    let points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
    let opacity: Double
}

private struct MarkupShape {
    let id = UUID()
    let kind: MarkupShapeKind
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let lineWidth: CGFloat
}

private struct MarkupText {
    let id = UUID()
    let text: String
    let anchor: CGPoint
    let color: Color
    let fontSize: CGFloat
    let fontChoice: MarkupFontChoice
    let backgroundChoice: TextBackgroundChoice
}

private struct MarkupSymbol {
    let id = UUID()
    let symbol: String
    let anchor: CGPoint
    let color: Color
    let fontSize: CGFloat
}

private struct EditingTextState: Identifiable {
    let id = UUID()
    let itemID: UUID?
    let anchor: CGPoint
    var text: String
}

private enum ResizeHandle: CaseIterable {
    case topLeft
    case top
    case topRight
    case right
    case bottomRight
    case bottom
    case bottomLeft
    case left
}

private enum MoveInteraction {
    case none
    case moveItem(UUID)
    case resizeShape(UUID, ResizeHandle)
}

private struct MarkupEditorView: View {
    let originalImage: NSImage
    @State private var canvasImage: NSImage
    let fileURL: URL
    let onSave: (NSImage, URL) -> Void
    @FocusState private var editorIsFocused: Bool

    @State private var tool: MarkupTool = .pen
    @State private var items: [MarkupItem] = []
    @State private var activePoints: [CGPoint] = []
    @State private var selectedColor: ColorChoice = .red
    @State private var lineWidth: CGFloat = 4
    @State private var symbolInput = "→"
    @State private var fontSize: CGFloat = 34
    @State private var fontChoice: MarkupFontChoice = .rounded
    @State private var textBackgroundChoice: TextBackgroundChoice = .clear
    @State private var editingText: EditingTextState?
    @State private var selectedItemID: UUID?
    @State private var draggingLastPoint: CGPoint?
    @State private var moveInteraction: MoveInteraction = .none
    @State private var cropPreset: CropPreset = .freeform
    @State private var isCropMode = false
    @State private var cropDragStart: CGPoint?
    @State private var cropSelection: CGRect?

    private let suggestedSymbols = ["→", "↗", "★", "✓", "✕", "!", "?", "❤"]
    private static let blurRadius: Double = 18
    private static let ciContext = CIContext(options: nil)

    init(initialImage: NSImage, fileURL: URL, onSave: @escaping (NSImage, URL) -> Void) {
        self.originalImage = initialImage
        _canvasImage = State(initialValue: initialImage)
        self.fileURL = fileURL
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            GeometryReader { proxy in
                let imageFrame = aspectFitFrame(imageSize: canvasImage.size, in: proxy.size)

                ZStack {
                    Color(red: 0.94, green: 0.95, blue: 0.97)
                        .ignoresSafeArea()

                    Image(nsImage: canvasImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .position(x: imageFrame.midX, y: imageFrame.midY)

                    Canvas { context, _ in
                        for item in items {
                            draw(item: item, in: imageFrame, with: &context)
                        }

                        if let previewItem {
                            draw(item: previewItem, in: imageFrame, with: &context)
                        }

                        if tool == .move, let selectedItem {
                            drawSelection(for: selectedItem, in: imageFrame, with: &context)
                        }

                        if isCropMode, let cropSelection {
                            drawCropSelection(cropSelection, in: imageFrame, with: &context)
                        }
                    }

                    MarkupInteractionOverlay(
                        onMouseDown: { location in
                            handleMouseDown(at: translatedCanvasLocation(from: location, imageFrame: imageFrame), imageFrame: imageFrame)
                        },
                        onMouseDragged: { startLocation, currentLocation in
                            handleMouseDragged(
                                from: translatedCanvasLocation(from: startLocation, imageFrame: imageFrame),
                                to: translatedCanvasLocation(from: currentLocation, imageFrame: imageFrame),
                                imageFrame: imageFrame
                            )
                        },
                        onMouseUp: { startLocation, endLocation in
                            handleMouseUp(
                                from: translatedCanvasLocation(from: startLocation, imageFrame: imageFrame),
                                to: translatedCanvasLocation(from: endLocation, imageFrame: imageFrame),
                                imageFrame: imageFrame
                            )
                        }
                    )
                    .frame(width: imageFrame.width, height: imageFrame.height)
                    .position(x: imageFrame.midX, y: imageFrame.midY)

                    if let editingText {
                        inlineEditor(for: editingText, imageFrame: imageFrame)
                    }
                }
            }

            bottomBar
        }
        .focusable()
        .focused($editorIsFocused)
        .onChange(of: tool) { _ in
            commitInlineTextIfNeeded()
        }
        .onDeleteCommand {
            deleteSelectedItem()
        }
        .onAppear {
            editorIsFocused = true
        }
    }

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Label("Markup", systemImage: "scribble.variable")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.72), in: Capsule())

                Picker("Tool", selection: $tool) {
                    ForEach(MarkupTool.allCases) { tool in
                        Text(tool.rawValue).tag(tool)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 760)

                Spacer(minLength: 0)

                Button("Undo") {
                    undoLastAction()
                }
                .buttonStyle(.bordered)
                .disabled(items.isEmpty && editingText == nil && activePoints.isEmpty && cropSelection == nil && !isCropMode)

                Button("Clear") {
                    clearAnnotations()
                }
                .buttonStyle(.bordered)
                .disabled(items.isEmpty && editingText == nil && activePoints.isEmpty && cropSelection == nil)

                Button("Delete Selected") {
                    deleteSelectedItem()
                }
                .buttonStyle(.bordered)
                .disabled(!canDeleteSelection)
            }

            HStack(spacing: 14) {
                ColorSwatchPicker(selection: $selectedColor)

                if tool == .text {
                    Picker("Font", selection: $fontChoice) {
                        ForEach(MarkupFontChoice.allCases) { choice in
                            Text(choice.rawValue).tag(choice)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)

                    Picker("Background", selection: $textBackgroundChoice) {
                        ForEach(TextBackgroundChoice.allCases) { choice in
                            Text(choice.rawValue).tag(choice)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }

                if tool == .symbol {
                    HStack(spacing: 8) {
                        ForEach(suggestedSymbols, id: \.self) { symbol in
                            Button(symbol) {
                                symbolInput = symbol
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if tool == .text || tool == .symbol {
                    labeledSlider("Size", value: $fontSize, range: 18...72)
                } else if tool != .move && tool != .blur && tool != .redact {
                    labeledSlider(tool == .highlighter ? "Thickness" : "Stroke", value: $lineWidth, range: tool == .highlighter ? 10...36 : 2...14)
                }

                if tool == .blur || tool == .redact || tool == .move {
                    Text(toolHint)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.65), in: Capsule())
                }

                Spacer(minLength: 0)

                Picker("Crop", selection: $cropPreset) {
                    ForEach(CropPreset.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 170)

                Button(isCropMode ? "Apply Crop" : "Start Crop") {
                    if isCropMode {
                        applyCropSelection()
                    } else {
                        beginCropMode()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCropMode && cropSelection == nil)

                if isCropMode {
                    Button("Cancel Crop") {
                        cancelCropMode()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Revert Original") {
                    revertToOriginal()
                }
                .buttonStyle(.bordered)
                .disabled(!hasEditedBaseImage)
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
    }

    private var bottomBar: some View {
        HStack {
            Text(bottomHint)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Save and Close") {
                commitInlineTextIfNeeded()
                onSave(renderImage(), fileURL)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }

    private var toolHint: String {
        switch tool {
        case .move:
            return "Click to select, drag to move, use handles to resize."
        case .blur:
            return "Drag over sensitive content to blur it."
        case .redact:
            return "Drag to place a solid privacy box."
        default:
            return ""
        }
    }

    private var bottomHint: String {
        switch tool {
        case .move:
            return "Selections stay editable. Click an annotation any time to move or resize it."
        case _ where isCropMode:
            return cropPreset == .freeform
                ? "Drag the area you want to keep, then apply the crop."
                : "Drag the area you want to keep. The crop box stays locked to the selected ratio."
        case .blur:
            return "Blur creates a privacy region you can come back and resize later."
        case .redact:
            return "Redaction boxes stay editable. Switch to Move to adjust them later."
        case .text:
            return "Click to place text. Empty text boxes disappear on your next action."
        default:
            return "Click Save when you're done."
        }
    }

    private func labeledSlider(_ title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Slider(value: value, in: range)
                .frame(width: 140)
        }
    }

    private func translatedCanvasLocation(from localLocation: CGPoint, imageFrame: CGRect) -> CGPoint {
        CGPoint(x: imageFrame.minX + localLocation.x, y: imageFrame.minY + localLocation.y)
    }

    private func handleMouseDown(at location: CGPoint, imageFrame: CGRect) {
        commitInlineTextIfNeeded()

        if isCropMode {
            cropDragStart = normalizedPoint(from: location, imageFrame: imageFrame)
            return
        }

        if tool == .move {
            guard let point = normalizedPoint(from: location, imageFrame: imageFrame) else { return }
            beginMoveInteraction(
                at: location,
                imageFrame: imageFrame,
                startPoint: point,
                currentPoint: point
            )
            return
        }

        guard tool.drawsByDrag,
              let point = normalizedPoint(from: location, imageFrame: imageFrame)
        else {
            return
        }

        activePoints = [point]
    }

    private func handleMouseDragged(from startLocation: CGPoint, to currentLocation: CGPoint, imageFrame: CGRect) {
        commitInlineTextIfNeeded()

        if isCropMode {
            guard let point = normalizedPoint(from: currentLocation, imageFrame: imageFrame) else { return }
            if cropDragStart == nil {
                cropDragStart = normalizedPoint(from: startLocation, imageFrame: imageFrame)
            }
            if let cropDragStart {
                cropSelection = constrainedCropRect(from: cropDragStart, to: point)
            }
            return
        }

        if tool == .move {
            guard let point = normalizedPoint(from: currentLocation, imageFrame: imageFrame) else { return }
            let startPoint = normalizedPoint(from: startLocation, imageFrame: imageFrame)

            switch moveInteraction {
            case .none:
                beginMoveInteraction(
                    at: startLocation,
                    imageFrame: imageFrame,
                    startPoint: startPoint,
                    currentPoint: point
                )
            case .moveItem(let itemID):
                if let lastPoint = draggingLastPoint {
                    let delta = CGPoint(x: point.x - lastPoint.x, y: point.y - lastPoint.y)
                    moveItem(withID: itemID, by: delta)
                    draggingLastPoint = point
                }
            case .resizeShape(let itemID, let handle):
                resizeShape(withID: itemID, handle: handle, to: point)
                draggingLastPoint = point
            }
            return
        }

        guard tool.drawsByDrag,
              let point = normalizedPoint(from: currentLocation, imageFrame: imageFrame)
        else {
            return
        }

        if activePoints.isEmpty {
            activePoints = [point]
        } else if tool == .pen || tool == .highlighter {
            activePoints.append(point)
        } else {
            activePoints = [activePoints.first ?? point, point]
        }
    }

    private func handleMouseUp(from startLocation: CGPoint, to endLocation: CGPoint, imageFrame: CGRect) {
        let moved = abs(endLocation.x - startLocation.x) + abs(endLocation.y - startLocation.y)

        if isCropMode {
            guard let point = normalizedPoint(from: endLocation, imageFrame: imageFrame) else {
                cropDragStart = nil
                return
            }
            if let cropDragStart {
                cropSelection = constrainedCropRect(from: cropDragStart, to: point)
            }
            cropDragStart = nil
            return
        }

        if tool == .move {
            if let point = normalizedPoint(from: endLocation, imageFrame: imageFrame) {
                switch moveInteraction {
                case .moveItem(let itemID):
                    if let lastPoint = draggingLastPoint {
                        let delta = CGPoint(x: point.x - lastPoint.x, y: point.y - lastPoint.y)
                        moveItem(withID: itemID, by: delta)
                    }
                case .resizeShape(let itemID, let handle):
                    resizeShape(withID: itemID, handle: handle, to: point)
                case .none:
                    break
                }
            }

            if moved < 4 {
                selectItem(at: endLocation, imageFrame: imageFrame)
            }
            moveInteraction = .none
            draggingLastPoint = nil
            return
        }

        if tool.drawsByDrag {
            guard let point = normalizedPoint(from: endLocation, imageFrame: imageFrame) else {
                activePoints.removeAll()
                return
            }

            if tool == .pen || tool == .highlighter {
                activePoints.append(point)
            } else if activePoints.count == 1 {
                activePoints.append(point)
            }

            defer { activePoints.removeAll() }
            guard let item = finalizedItem(from: activePoints) else { return }
            items.append(item)
            selectedItemID = item.id
            return
        }

        guard moved < 8,
              let point = normalizedPoint(from: endLocation, imageFrame: imageFrame)
        else {
            return
        }

        handleTapDrivenTool(at: point)
    }

    private func handleTapDrivenTool(at point: CGPoint) {
        commitInlineTextIfNeeded()

        switch tool {
        case .text:
            if let existingText = textItem(at: point) {
                selectedItemID = existingText.id
                fontSize = existingText.fontSize
                fontChoice = existingText.fontChoice
                selectedColor = ColorChoice.closest(to: existingText.color)
                textBackgroundChoice = existingText.backgroundChoice
                editingText = EditingTextState(
                    itemID: existingText.id,
                    anchor: existingText.anchor,
                    text: existingText.text
                )
            } else {
                selectedItemID = nil
                editingText = EditingTextState(itemID: nil, anchor: point, text: "")
            }
        case .symbol:
            let item = MarkupItem.symbol(
                MarkupSymbol(
                    symbol: symbolInput,
                    anchor: point,
                    color: selectedColor.color,
                    fontSize: fontSize
                )
            )
            items.append(item)
            selectedItemID = item.id
        default:
            break
        }
    }

    private func inlineEditor(for state: EditingTextState, imageFrame: CGRect) -> some View {
        let point = map(point: state.anchor, into: imageFrame)
        let width = max(44, textWidth(for: editingText?.text ?? "", size: fontSize, choice: fontChoice) + 26)

        return InlineTextField(text: Binding(
            get: { editingText?.text ?? "" },
            set: { editingText?.text = $0 }
        ), font: nsFont(size: fontSize, choice: fontChoice), textColor: selectedColor.nsColor)
        .frame(width: width, height: max(30, fontSize + 14))
        .background(textBackgroundChoice.color)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(selectedColor.color, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .position(x: point.x + (width / 2), y: point.y)
        .onDisappear {
            commitInlineTextIfNeeded()
        }
    }

    private func commitInlineTextIfNeeded() {
        guard let editingText else { return }
        defer { self.editingText = nil }

        let trimmed = editingText.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if let itemID = editingText.itemID {
                items.removeAll { $0.id == itemID }
            }
            return
        }

        let item = MarkupItem.text(
            MarkupText(
                text: trimmed,
                anchor: editingText.anchor,
                color: selectedColor.color,
                fontSize: fontSize,
                fontChoice: fontChoice
                ,
                backgroundChoice: textBackgroundChoice
            )
        )

        if let itemID = editingText.itemID,
           let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index] = item
            selectedItemID = item.id
        } else {
            items.append(item)
            selectedItemID = item.id
        }
    }

    private func beginCropMode() {
        commitInlineTextIfNeeded()
        isCropMode = true
        cropDragStart = nil
        cropSelection = nil
        selectedItemID = nil
    }

    private func cancelCropMode() {
        isCropMode = false
        cropDragStart = nil
        cropSelection = nil
    }

    private func applyCropSelection() {
        commitInlineTextIfNeeded()
        guard let selection = cropSelection else { return }

        let rendered = renderImage()
        let cropRect = CGRect(
            x: selection.minX * rendered.size.width,
            y: (1 - selection.maxY) * rendered.size.height,
            width: selection.width * rendered.size.width,
            height: selection.height * rendered.size.height
        ).integral

        guard let cropped = crop(image: rendered, to: cropRect) else { return }
        canvasImage = cropped
        items.removeAll()
        editingText = nil
        activePoints.removeAll()
        selectedItemID = nil
        draggingLastPoint = nil
        isCropMode = false
        cropDragStart = nil
        cropSelection = nil
        cropPreset = .freeform
    }

    private var hasEditedBaseImage: Bool {
        !nsImageSizeEquals(canvasImage.size, originalImage.size)
    }

    private func revertToOriginal() {
        commitInlineTextIfNeeded()
        canvasImage = originalImage
        items.removeAll()
        selectedItemID = nil
        editingText = nil
        activePoints.removeAll()
        draggingLastPoint = nil
        cropPreset = .freeform
        isCropMode = false
        cropDragStart = nil
        cropSelection = nil
    }

    private func deleteSelectedItem() {
        if let editingText {
            if let itemID = editingText.itemID {
                items.removeAll { $0.id == itemID }
            }
            self.editingText = nil
            selectedItemID = nil
            moveInteraction = .none
            draggingLastPoint = nil
            return
        }

        guard let selectedItemID else { return }
        items.removeAll { $0.id == selectedItemID }
        self.selectedItemID = nil
        moveInteraction = .none
        draggingLastPoint = nil
    }

    private func undoLastAction() {
        if isCropMode {
            if cropSelection == nil && cropDragStart == nil {
                isCropMode = false
                return
            }
            cropSelection = nil
            cropDragStart = nil
            return
        }

        if let editingText {
            selectedItemID = editingText.itemID
            self.editingText = nil
            moveInteraction = .none
            draggingLastPoint = nil
            return
        }

        if !activePoints.isEmpty {
            activePoints.removeAll()
            return
        }

        guard let removedItem = items.popLast() else { return }
        if selectedItemID == removedItem.id {
            selectedItemID = nil
        }
        moveInteraction = .none
        draggingLastPoint = nil
    }

    private func clearAnnotations() {
        items.removeAll()
        editingText = nil
        activePoints.removeAll()
        selectedItemID = nil
        moveInteraction = .none
        draggingLastPoint = nil
        isCropMode = false
        cropSelection = nil
        cropDragStart = nil
    }

    private var canDeleteSelection: Bool {
        selectedItemID != nil || editingText?.itemID != nil
    }

    private var previewItem: MarkupItem? {
        finalizedItem(from: activePoints)
    }

    private var selectedItem: MarkupItem? {
        guard let selectedItemID else { return nil }
        return items.first(where: { $0.id == selectedItemID })
    }

    private func finalizedItem(from points: [CGPoint]) -> MarkupItem? {
        switch tool {
        case .move:
            return nil
        case .pen:
            guard points.count >= 2 else { return nil }
            return .stroke(MarkupStroke(points: points, color: selectedColor.color, lineWidth: lineWidth, opacity: 1))
        case .highlighter:
            guard points.count >= 2 else { return nil }
            let bounds = bounds(for: points)
            let autoThickness = min(34, max(18, bounds.height * 1.35))
            return .stroke(MarkupStroke(points: points, color: selectedColor.color, lineWidth: autoThickness, opacity: 0.32))
        case .arrow:
            guard points.count >= 2 else { return nil }
            return .shape(MarkupShape(kind: .arrow, start: points[0], end: points[1], color: selectedColor.color, lineWidth: lineWidth))
        case .rectangle:
            guard points.count >= 2 else { return nil }
            return .shape(MarkupShape(kind: .rectangle, start: points[0], end: points[1], color: selectedColor.color, lineWidth: lineWidth))
        case .ellipse:
            guard points.count >= 2 else { return nil }
            return .shape(MarkupShape(kind: .ellipse, start: points[0], end: points[1], color: selectedColor.color, lineWidth: lineWidth))
        case .blur:
            guard points.count >= 2 else { return nil }
            return .shape(MarkupShape(kind: .blur, start: points[0], end: points[1], color: .clear, lineWidth: 0))
        case .redact:
            guard points.count >= 2 else { return nil }
            return .shape(MarkupShape(kind: .redact, start: points[0], end: points[1], color: .black, lineWidth: 0))
        case .text, .symbol:
            return nil
        }
    }

    private func normalizedPoint(from location: CGPoint, imageFrame: CGRect) -> CGPoint? {
        guard imageFrame.contains(location), imageFrame.width > 0, imageFrame.height > 0 else { return nil }
        let x = (location.x - imageFrame.minX) / imageFrame.width
        let y = 1 - ((location.y - imageFrame.minY) / imageFrame.height)
        return CGPoint(x: x, y: y)
    }

    private func aspectFitFrame(imageSize: CGSize, in canvasSize: CGSize) -> CGRect {
        let imageRatio = imageSize.width / imageSize.height
        let canvasRatio = canvasSize.width / canvasSize.height

        if imageRatio > canvasRatio {
            let width = canvasSize.width
            let height = width / imageRatio
            return CGRect(x: 0, y: (canvasSize.height - height) / 2, width: width, height: height)
        } else {
            let height = canvasSize.height
            let width = height * imageRatio
            return CGRect(x: (canvasSize.width - width) / 2, y: 0, width: width, height: height)
        }
    }

    private func draw(item: MarkupItem, in frame: CGRect, with context: inout GraphicsContext) {
        switch item {
        case .stroke(let stroke):
            draw(stroke: stroke, in: frame, with: &context)
        case .shape(let shape):
            draw(shape: shape, in: frame, with: &context)
        case .text(let text):
            let point = map(point: text.anchor, into: frame)
            let size = textSize(for: text.text, size: text.fontSize, choice: text.fontChoice)
            let textView = Text(text.text)
                .font(swiftUIFont(size: text.fontSize, choice: text.fontChoice))
                .foregroundColor(text.color)
            if text.backgroundChoice != .clear {
                context.fill(
                    Path(
                        roundedRect: SnipletGeometry.textBackgroundRect(anchor: point, textSize: size),
                        cornerRadius: 8
                    ),
                    with: .color(text.backgroundChoice.color)
                )
            }
            context.draw(
                textView,
                at: SnipletGeometry.textDrawPoint(anchor: point, textSize: size),
                anchor: .leading
            )
        case .symbol(let symbol):
            let point = map(point: symbol.anchor, into: frame)
            let symbolView = Text(symbol.symbol)
                .font(.system(size: symbol.fontSize, weight: .bold, design: .rounded))
                .foregroundColor(symbol.color)
            context.draw(symbolView, at: point, anchor: .center)
        }
    }

    private func drawSelection(for item: MarkupItem, in frame: CGRect, with context: inout GraphicsContext) {
        guard let rect = selectionRect(for: item, in: frame) else { return }

        context.stroke(
            Path(roundedRect: rect, cornerRadius: 12),
            with: .color(Color.accentColor),
            style: StrokeStyle(lineWidth: 2, dash: [7, 5])
        )

        if case .shape(let shape) = item, isResizable(shape.kind) {
            for handleRect in resizeHandleRects(for: rect) {
                context.fill(Path(ellipseIn: handleRect), with: .color(.white))
                context.stroke(Path(ellipseIn: handleRect), with: .color(Color.accentColor), style: StrokeStyle(lineWidth: 2))
            }
        }
    }

    private func selectionRect(for item: MarkupItem, in frame: CGRect) -> CGRect? {
        switch item {
        case .shape(let shape):
            let start = map(point: shape.start, into: frame)
            let end = map(point: shape.end, into: frame)
            return CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            ).insetBy(dx: -8, dy: -8)
        case .text(let text):
            let point = map(point: text.anchor, into: frame)
            let size = textSize(for: text.text, size: text.fontSize, choice: text.fontChoice)
            return SnipletGeometry.textSelectionRect(anchor: point, textSize: size)
        case .symbol(let symbol):
            let point = map(point: symbol.anchor, into: frame)
            let attributed = NSAttributedString(
                string: symbol.symbol,
                attributes: [.font: NSFont.systemFont(ofSize: symbol.fontSize, weight: .bold)]
            )
            let size = attributed.size()
            return CGRect(x: point.x - (size.width / 2) - 8, y: point.y - (size.height / 2) - 8, width: size.width + 16, height: size.height + 16)
        case .stroke(let stroke):
            let points = stroke.points.map { map(point: $0, into: frame) }
            guard let first = points.first else { return nil }
            let bounds = points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
                partial.union(CGRect(origin: point, size: .zero))
            }
            return bounds.insetBy(dx: -max(12, stroke.lineWidth), dy: -max(12, stroke.lineWidth))
        }
    }

    private func constrainedCropRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        SnipletGeometry.constrainedCropRect(from: start, to: end, aspectRatio: cropPreset.ratio)
    }

    private func drawCropSelection(_ selection: CGRect, in frame: CGRect, with context: inout GraphicsContext) {
        let rect = CGRect(
            x: frame.minX + selection.minX * frame.width,
            y: frame.minY + (1 - selection.maxY) * frame.height,
            width: selection.width * frame.width,
            height: selection.height * frame.height
        )

        let topShade = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: max(0, rect.minY - frame.minY))
        let bottomShade = CGRect(x: frame.minX, y: rect.maxY, width: frame.width, height: max(0, frame.maxY - rect.maxY))
        let leftShade = CGRect(x: frame.minX, y: rect.minY, width: max(0, rect.minX - frame.minX), height: rect.height)
        let rightShade = CGRect(x: rect.maxX, y: rect.minY, width: max(0, frame.maxX - rect.maxX), height: rect.height)

        for shadedRect in [topShade, bottomShade, leftShade, rightShade] where shadedRect.width > 0 && shadedRect.height > 0 {
            context.fill(Path(shadedRect), with: .color(.black.opacity(0.30)))
        }

        context.stroke(
            Path(roundedRect: rect, cornerRadius: 12),
            with: .color(.white),
            style: StrokeStyle(lineWidth: 2, dash: [10, 6])
        )
    }

    private func bounds(for points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
            partial.union(CGRect(origin: point, size: .zero))
        }
    }

    private func resizeHandleRects(for rect: CGRect) -> [CGRect] {
        resizeHandleCenters(for: rect).values.map {
            CGRect(x: $0.x - 7, y: $0.y - 7, width: 14, height: 14)
        }
    }

    private func resizeHandleCenters(for rect: CGRect) -> [ResizeHandle: CGPoint] {
        [
            .topLeft: CGPoint(x: rect.minX, y: rect.maxY),
            .top: CGPoint(x: rect.midX, y: rect.maxY),
            .topRight: CGPoint(x: rect.maxX, y: rect.maxY),
            .right: CGPoint(x: rect.maxX, y: rect.midY),
            .bottomRight: CGPoint(x: rect.maxX, y: rect.minY),
            .bottom: CGPoint(x: rect.midX, y: rect.minY),
            .bottomLeft: CGPoint(x: rect.minX, y: rect.minY),
            .left: CGPoint(x: rect.minX, y: rect.midY)
        ]
    }

    private func hitTestResizeHandle(at location: CGPoint, imageFrame: CGRect, itemID: UUID) -> ResizeHandle? {
        guard let item = items.first(where: { $0.id == itemID }),
              let rect = selectionRect(for: item, in: imageFrame)
        else {
            return nil
        }

        for (handle, center) in resizeHandleCenters(for: rect) {
            let hitRect = CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36)
            if hitRect.contains(location) {
                return handle
            }
        }
        return nil
    }

    private func hitTestAnyResizeHandle(at location: CGPoint, imageFrame: CGRect) -> (UUID, ResizeHandle)? {
        for item in items.reversed() {
            guard case .shape(let shape) = item, isResizable(shape.kind) else { continue }
            guard let rect = selectionRect(for: item, in: imageFrame) else { continue }

            for (handle, center) in resizeHandleCenters(for: rect) {
                let hitRect = CGRect(x: center.x - 18, y: center.y - 18, width: 36, height: 36)
                if hitRect.contains(location) {
                    return (item.id, handle)
                }
            }
        }

        return nil
    }

    private func hitTestItem(at location: CGPoint, imageFrame: CGRect) -> MarkupItem? {
        for item in items.reversed() {
            guard let rect = selectionRect(for: item, in: imageFrame) else { continue }
            if rect.insetBy(dx: -10, dy: -10).contains(location) {
                return item
            }
        }
        return nil
    }

    private func selectItem(at location: CGPoint, imageFrame: CGRect) {
        if let hitItem = hitTestItem(at: location, imageFrame: imageFrame) {
            selectedItemID = hitItem.id
        } else {
            selectedItemID = nil
        }
    }

    private func beginMoveInteraction(
        at location: CGPoint,
        imageFrame: CGRect,
        startPoint: CGPoint?,
        currentPoint: CGPoint
    ) {
        if let (itemID, handle) = hitTestAnyResizeHandle(at: location, imageFrame: imageFrame) {
            selectedItemID = itemID
            moveInteraction = .resizeShape(itemID, handle)
            if let startPoint, startPoint != currentPoint {
                resizeShape(withID: itemID, handle: handle, to: currentPoint)
            }
            draggingLastPoint = currentPoint
            return
        }

        if let selectedItemID,
           let handle = hitTestResizeHandle(at: location, imageFrame: imageFrame, itemID: selectedItemID) {
            moveInteraction = .resizeShape(selectedItemID, handle)
            if let startPoint, startPoint != currentPoint {
                resizeShape(withID: selectedItemID, handle: handle, to: currentPoint)
            }
            draggingLastPoint = currentPoint
            return
        }

        guard let hitItem = hitTestItem(at: location, imageFrame: imageFrame) else {
            selectedItemID = nil
            moveInteraction = .none
            draggingLastPoint = nil
            return
        }

        selectedItemID = hitItem.id
        moveInteraction = .moveItem(hitItem.id)
        if let startPoint, startPoint != currentPoint {
            let delta = CGPoint(x: currentPoint.x - startPoint.x, y: currentPoint.y - startPoint.y)
            moveItem(withID: hitItem.id, by: delta)
        }
        draggingLastPoint = currentPoint
    }

    private func isResizable(_ kind: MarkupShapeKind) -> Bool {
        switch kind {
        case .rectangle, .ellipse, .blur, .redact:
            return true
        case .arrow:
            return false
        }
    }

    private func hitTestItem(at point: CGPoint) -> MarkupItem? {
        let imagePoint = denormalize(point: point, size: canvasImage.size)

        for item in items.reversed() {
            switch item {
            case .text(let text):
                let attributed = NSAttributedString(
                    string: text.text,
                    attributes: [.font: nsFont(size: text.fontSize, choice: text.fontChoice)]
                )
                let size = attributed.size()
                let anchor = denormalize(point: text.anchor, size: canvasImage.size)
                let rect = CGRect(x: anchor.x, y: anchor.y - size.height / 2, width: size.width + 16, height: size.height + 8)
                if rect.insetBy(dx: -10, dy: -8).contains(imagePoint) { return item }
            case .symbol(let symbol):
                let attributed = NSAttributedString(
                    string: symbol.symbol,
                    attributes: [.font: NSFont.systemFont(ofSize: symbol.fontSize, weight: .bold)]
                )
                let size = attributed.size()
                let anchor = denormalize(point: symbol.anchor, size: canvasImage.size)
                let rect = CGRect(x: anchor.x - size.width / 2, y: anchor.y - size.height / 2, width: size.width, height: size.height)
                if rect.insetBy(dx: -8, dy: -8).contains(imagePoint) { return item }
            case .shape(let shape):
                let start = denormalize(point: shape.start, size: canvasImage.size)
                let end = denormalize(point: shape.end, size: canvasImage.size)
                let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y))
                if rect.insetBy(dx: -12, dy: -12).contains(imagePoint) { return item }
            case .stroke(let stroke):
                let points = stroke.points.map { denormalize(point: $0, size: canvasImage.size) }
                guard let first = points.first else { continue }
                let bounds = points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
                    partial.union(CGRect(origin: point, size: .zero))
                }
                if bounds.insetBy(dx: -max(12, stroke.lineWidth), dy: -max(12, stroke.lineWidth)).contains(imagePoint) {
                    return item
                }
            }
        }
        return nil
    }

    private func moveItem(withID id: UUID, by delta: CGPoint) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let adjustedDelta = boundedTranslation(for: items[index], proposed: delta)
        items[index] = translated(item: items[index], by: adjustedDelta)
    }

    private func resizeShape(withID id: UUID, handle: ResizeHandle, to point: CGPoint) {
        guard let index = items.firstIndex(where: { $0.id == id }),
              case .shape(let shape) = items[index],
              isResizable(shape.kind)
        else {
            return
        }

        var minX = min(shape.start.x, shape.end.x)
        var maxX = max(shape.start.x, shape.end.x)
        var minY = min(shape.start.y, shape.end.y)
        var maxY = max(shape.start.y, shape.end.y)

        let clampedX = min(max(point.x, 0), 1)
        let clampedY = min(max(point.y, 0), 1)

        switch handle {
        case .topLeft:
            minX = clampedX
            maxY = clampedY
        case .top:
            maxY = clampedY
        case .topRight:
            maxX = clampedX
            maxY = clampedY
        case .right:
            maxX = clampedX
        case .bottomRight:
            maxX = clampedX
            minY = clampedY
        case .bottom:
            minY = clampedY
        case .bottomLeft:
            minX = clampedX
            minY = clampedY
        case .left:
            minX = clampedX
        }

        let minSpan: CGFloat = 0.015
        var resolvedMinX = min(minX, maxX)
        var resolvedMaxX = max(minX, maxX)
        var resolvedMinY = min(minY, maxY)
        var resolvedMaxY = max(minY, maxY)

        if (resolvedMaxX - resolvedMinX) < minSpan {
            if handle == .left || handle == .topLeft || handle == .bottomLeft {
                resolvedMinX = max(0, resolvedMaxX - minSpan)
            } else {
                resolvedMaxX = min(1, resolvedMinX + minSpan)
            }
        }

        if (resolvedMaxY - resolvedMinY) < minSpan {
            if handle == .bottom || handle == .bottomLeft || handle == .bottomRight {
                resolvedMinY = max(0, resolvedMaxY - minSpan)
            } else {
                resolvedMaxY = min(1, resolvedMinY + minSpan)
            }
        }

        let resizedShape = MarkupShape(
            kind: shape.kind,
            start: CGPoint(x: resolvedMinX, y: resolvedMaxY),
            end: CGPoint(x: resolvedMaxX, y: resolvedMinY),
            color: shape.color,
            lineWidth: shape.lineWidth
        )
        items[index] = .shape(resizedShape)
    }

    private func translated(item: MarkupItem, by delta: CGPoint) -> MarkupItem {
        switch item {
        case .stroke(let stroke):
            return .stroke(MarkupStroke(points: stroke.points.map { CGPoint(x: $0.x + delta.x, y: $0.y + delta.y) }, color: stroke.color, lineWidth: stroke.lineWidth, opacity: stroke.opacity))
        case .shape(let shape):
            return .shape(MarkupShape(kind: shape.kind, start: CGPoint(x: shape.start.x + delta.x, y: shape.start.y + delta.y), end: CGPoint(x: shape.end.x + delta.x, y: shape.end.y + delta.y), color: shape.color, lineWidth: shape.lineWidth))
        case .text(let text):
            return .text(MarkupText(text: text.text, anchor: CGPoint(x: text.anchor.x + delta.x, y: text.anchor.y + delta.y), color: text.color, fontSize: text.fontSize, fontChoice: text.fontChoice, backgroundChoice: text.backgroundChoice))
        case .symbol(let symbol):
            return .symbol(MarkupSymbol(symbol: symbol.symbol, anchor: CGPoint(x: symbol.anchor.x + delta.x, y: symbol.anchor.y + delta.y), color: symbol.color, fontSize: symbol.fontSize))
        }
    }

    private func clamp(point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), 1),
            y: min(max(point.y, 0), 1)
        )
    }

    private func boundedTranslation(for item: MarkupItem, proposed delta: CGPoint) -> CGPoint {
        SnipletGeometry.boundedTranslation(for: normalizedBounds(for: item), proposed: delta)
    }

    private func normalizedBounds(for item: MarkupItem) -> CGRect? {
        switch item {
        case .stroke(let stroke):
            guard let first = stroke.points.first else { return nil }
            return stroke.points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { partial, point in
                partial.union(CGRect(origin: point, size: .zero))
            }
        case .shape(let shape):
            return CGRect(
                x: min(shape.start.x, shape.end.x),
                y: min(shape.start.y, shape.end.y),
                width: abs(shape.end.x - shape.start.x),
                height: abs(shape.end.y - shape.start.y)
            )
        case .text(let text):
            let size = textSize(for: text.text, size: text.fontSize, choice: text.fontChoice)
            let anchor = denormalize(point: text.anchor, size: canvasImage.size)
            let rect = SnipletGeometry.textBackgroundRect(anchor: anchor, textSize: size)
            return SnipletGeometry.normalizedRect(rect, in: canvasImage.size)
        case .symbol(let symbol):
            let attributed = NSAttributedString(
                string: symbol.symbol,
                attributes: [.font: NSFont.systemFont(ofSize: symbol.fontSize, weight: .bold)]
            )
            let size = attributed.size()
            return CGRect(
                x: symbol.anchor.x - (size.width / canvasImage.size.width / 2),
                y: symbol.anchor.y - (size.height / canvasImage.size.height / 2),
                width: size.width / canvasImage.size.width,
                height: size.height / canvasImage.size.height
            )
        }
    }

    private func draw(stroke: MarkupStroke, in frame: CGRect, with context: inout GraphicsContext) {
        guard stroke.points.count >= 2 else { return }

        var path = Path()
        path.move(to: map(point: stroke.points[0], into: frame))
        for point in stroke.points.dropFirst() {
            path.addLine(to: map(point: point, into: frame))
        }

        context.stroke(
            path,
            with: .color(stroke.color.opacity(stroke.opacity)),
            style: StrokeStyle(
                lineWidth: stroke.lineWidth,
                lineCap: stroke.opacity < 1 ? .square : .round,
                lineJoin: .round
            )
        )
    }

    private func draw(shape: MarkupShape, in frame: CGRect, with context: inout GraphicsContext) {
        let start = map(point: shape.start, into: frame)
        let end = map(point: shape.end, into: frame)
        let strokeStyle = StrokeStyle(lineWidth: shape.lineWidth, lineCap: .round, lineJoin: .round)

        switch shape.kind {
        case .rectangle:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.stroke(
                Path(roundedRect: rect, cornerRadius: max(8, shape.lineWidth)),
                with: .color(shape.color),
                style: strokeStyle
            )
        case .ellipse:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.stroke(Path(ellipseIn: rect), with: .color(shape.color), style: strokeStyle)
        case .arrow:
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)

            let angle = atan2(end.y - start.y, end.x - start.x)
            let arrowLength = max(14, shape.lineWidth * 2.8)
            let arrowA = CGPoint(
                x: end.x - arrowLength * cos(angle - .pi / 7),
                y: end.y - arrowLength * sin(angle - .pi / 7)
            )
            let arrowB = CGPoint(
                x: end.x - arrowLength * cos(angle + .pi / 7),
                y: end.y - arrowLength * sin(angle + .pi / 7)
            )

            path.move(to: end)
            path.addLine(to: arrowA)
            path.move(to: end)
            path.addLine(to: arrowB)
            context.stroke(path, with: .color(shape.color), style: strokeStyle)
        case .blur:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.fill(
                Path(roundedRect: rect, cornerRadius: 12),
                with: .color(Color.white.opacity(0.28))
            )
            context.stroke(
                Path(roundedRect: rect, cornerRadius: 12),
                with: .color(Color.white.opacity(0.92)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            context.draw(
                Text("Blur")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white),
                at: CGPoint(x: rect.midX, y: rect.midY),
                anchor: .center
            )
        case .redact:
            let rect = CGRect(
                x: min(start.x, end.x),
                y: min(start.y, end.y),
                width: abs(end.x - start.x),
                height: abs(end.y - start.y)
            )
            context.fill(Path(roundedRect: rect, cornerRadius: 10), with: .color(.black))
        }
    }

    private func renderImage() -> NSImage {
        commitInlineTextIfNeeded()

        let image = NSImage(size: canvasImage.size)
        image.lockFocusFlipped(true)
        canvasImage.draw(in: CGRect(origin: .zero, size: canvasImage.size))

        for item in items {
            drawRendered(item: item, on: image)
        }

        image.unlockFocus()
        return image
    }

    private func drawRendered(item: MarkupItem, on image: NSImage) {
        switch item {
        case .stroke(let stroke):
            let color = NSColor(stroke.color).withAlphaComponent(stroke.opacity)
            color.setStroke()
            let path = NSBezierPath()
            path.lineWidth = stroke.lineWidth
            path.lineJoinStyle = .round
            path.lineCapStyle = stroke.opacity < 1 ? .square : .round
            guard let first = stroke.points.first else { return }
            path.move(to: renderedPoint(from: first, size: image.size))
            for point in stroke.points.dropFirst() {
                path.line(to: renderedPoint(from: point, size: image.size))
            }
            path.stroke()
        case .shape(let shape):
            let color = NSColor(shape.color)
            color.setStroke()
            let path = NSBezierPath()
            path.lineWidth = shape.lineWidth
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            let start = renderedPoint(from: shape.start, size: image.size)
            let end = renderedPoint(from: shape.end, size: image.size)

            switch shape.kind {
            case .rectangle:
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                path.appendRoundedRect(rect, xRadius: max(8, shape.lineWidth), yRadius: max(8, shape.lineWidth))
            case .ellipse:
                let rect = CGRect(
                    x: min(start.x, end.x),
                    y: min(start.y, end.y),
                    width: abs(end.x - start.x),
                    height: abs(end.y - start.y)
                )
                path.appendOval(in: rect)
            case .arrow:
                path.move(to: start)
                path.line(to: end)
                let angle = atan2(end.y - start.y, end.x - start.x)
                let arrowLength = max(14, shape.lineWidth * 2.8)
                path.move(to: end)
                path.line(to: CGPoint(
                    x: end.x - arrowLength * cos(angle - .pi / 7),
                    y: end.y - arrowLength * sin(angle - .pi / 7)
                ))
                path.move(to: end)
                path.line(to: CGPoint(
                    x: end.x - arrowLength * cos(angle + .pi / 7),
                    y: end.y - arrowLength * sin(angle + .pi / 7)
                ))
            case .blur:
                applyBlur(on: image, in: normalizedRect(from: start, to: end))
                return
            case .redact:
                let rect = normalizedRect(from: start, to: end)
                let fillPath = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
                NSColor.black.setFill()
                fillPath.fill()
                return
            }

            path.stroke()
        case .text(let text):
            let point = renderedPoint(from: text.anchor, size: image.size)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: nsFont(size: text.fontSize, choice: text.fontChoice),
                .foregroundColor: NSColor(text.color)
            ]
            let attributed = NSAttributedString(string: text.text, attributes: attributes)
            let size = attributed.size()
            let drawPoint = SnipletGeometry.textDrawPoint(anchor: point, textSize: size)
            if text.backgroundChoice != .clear {
                let path = NSBezierPath(
                    roundedRect: SnipletGeometry.textBackgroundRect(anchor: point, textSize: size),
                    xRadius: 8,
                    yRadius: 8
                )
                NSColor(text.backgroundChoice.color).setFill()
                path.fill()
            }
            attributed.draw(at: drawPoint)
        case .symbol(let symbol):
            let point = renderedPoint(from: symbol.anchor, size: image.size)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: symbol.fontSize, weight: .bold),
                .foregroundColor: NSColor(symbol.color)
            ]
            let attributed = NSAttributedString(string: symbol.symbol, attributes: attributes)
            let size = attributed.size()
            attributed.draw(at: CGPoint(x: point.x - (size.width / 2), y: point.y - (size.height / 2)))
        }
    }

    private func textItem(at point: CGPoint) -> MarkupText? {
        for item in items.reversed() {
            guard case .text(let text) = item else { continue }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: nsFont(size: text.fontSize, choice: text.fontChoice)
            ]
            let attributed = NSAttributedString(string: text.text, attributes: attributes)
            let size = attributed.size()
            let imagePoint = denormalize(point: point, size: canvasImage.size)
            let anchor = denormalize(point: text.anchor, size: canvasImage.size)
            let rect = SnipletGeometry.textSelectionRect(anchor: anchor, textSize: size)
            if rect.contains(imagePoint) {
                return text
            }
        }
        return nil
    }

    private func crop(image: NSImage, to rect: CGRect) -> NSImage? {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil),
              let croppedCG = cgImage.cropping(to: rect)
        else {
            return nil
        }

        let nsImage = NSImage(size: NSSize(width: croppedCG.width, height: croppedCG.height))
        nsImage.addRepresentation(NSBitmapImageRep(cgImage: croppedCG))
        return nsImage
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        ).integral
    }

    private func applyBlur(on image: NSImage, in rect: CGRect) {
        let imageRect = CGRect(origin: .zero, size: image.size)
        let targetRect = rect.intersection(imageRect).integral
        guard !targetRect.isNull, !targetRect.isEmpty else { return }

        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil),
              let cropped = cgImage.cropping(to: targetRect)
        else {
            return
        }

        let input = CIImage(cgImage: cropped)
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return }
        filter.setValue(input.clampedToExtent(), forKey: kCIInputImageKey)
        filter.setValue(Self.blurRadius, forKey: kCIInputRadiusKey)

        guard let blurred = filter.outputImage?.cropped(to: input.extent),
              let output = Self.ciContext.createCGImage(blurred, from: input.extent),
              let context = NSGraphicsContext.current?.cgContext
        else {
            return
        }

        context.draw(output, in: targetRect)
    }

    private func map(point: CGPoint, into frame: CGRect) -> CGPoint {
        CGPoint(
            x: frame.minX + (point.x * frame.width),
            y: frame.minY + ((1 - point.y) * frame.height)
        )
    }

    private func denormalize(point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: point.x * size.width,
            y: (1 - point.y) * size.height
        )
    }

    private func renderedPoint(from normalizedPoint: CGPoint, size: CGSize) -> CGPoint {
        SnipletGeometry.renderedImagePoint(from: normalizedPoint, imageSize: size)
    }

    private func swiftUIFont(size: CGFloat, choice: MarkupFontChoice) -> Font {
        switch choice {
        case .rounded:
            return .system(size: size, weight: .bold, design: .rounded)
        case .avenir:
            return .custom("Avenir Next Bold", size: size)
        case .helvetica:
            return .custom("Helvetica Neue Bold", size: size)
        case .georgia:
            return .custom("Georgia Bold", size: size)
        case .noteworthy:
            return .custom("Noteworthy-Bold", size: size)
        case .mono:
            return .custom("Menlo-Bold", size: size)
        }
    }

    private func nsFont(size: CGFloat, choice: MarkupFontChoice) -> NSFont {
        switch choice {
        case .rounded:
            return NSFont.systemFont(ofSize: size, weight: .bold)
        case .avenir:
            return NSFont(name: "AvenirNext-Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .bold)
        case .helvetica:
            return NSFont(name: "HelveticaNeue-Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .bold)
        case .georgia:
            return NSFont(name: "Georgia-Bold", size: size) ?? NSFont.boldSystemFont(ofSize: size)
        case .noteworthy:
            return NSFont(name: "Noteworthy-Bold", size: size) ?? NSFont.systemFont(ofSize: size, weight: .bold)
        case .mono:
            return NSFont(name: "Menlo-Bold", size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)
        }
    }

    private func textWidth(for text: String, size: CGFloat, choice: MarkupFontChoice) -> CGFloat {
        let value = text.isEmpty ? " " : text
        let attributed = NSAttributedString(string: value, attributes: [.font: nsFont(size: size, choice: choice)])
        return attributed.size().width
    }

    private func textSize(for text: String, size: CGFloat, choice: MarkupFontChoice) -> CGSize {
        let value = text.isEmpty ? " " : text
        let attributed = NSAttributedString(string: value, attributes: [.font: nsFont(size: size, choice: choice)])
        return attributed.size()
    }

    private func nsImageSizeEquals(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        abs(lhs.width - rhs.width) < 0.5 && abs(lhs.height - rhs.height) < 0.5
    }
}

private enum ColorChoice: String, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple
    case black
    case white

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: return Color(red: 0.90, green: 0.20, blue: 0.20)
        case .orange: return Color(red: 0.96, green: 0.55, blue: 0.17)
        case .yellow: return Color(red: 0.95, green: 0.82, blue: 0.18)
        case .green: return Color(red: 0.20, green: 0.68, blue: 0.35)
        case .blue: return Color(red: 0.20, green: 0.48, blue: 0.92)
        case .purple: return Color(red: 0.52, green: 0.33, blue: 0.84)
        case .black: return .black
        case .white: return .white
        }
    }

    var nsColor: NSColor { NSColor(color) }

    static func closest(to color: Color) -> ColorChoice {
        let target = NSColor(color)
        let options = ColorChoice.allCases
        return options.min(by: { lhs, rhs in
            lhs.distance(to: target) < rhs.distance(to: target)
        }) ?? .red
    }

    private func distance(to color: NSColor) -> CGFloat {
        let source = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        let target = color.usingColorSpace(.deviceRGB) ?? color
        let dr = source.redComponent - target.redComponent
        let dg = source.greenComponent - target.greenComponent
        let db = source.blueComponent - target.blueComponent
        return (dr * dr) + (dg * dg) + (db * db)
    }
}

private struct ColorSwatchPicker: View {
    @Binding var selection: ColorChoice

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ColorChoice.allCases) { choice in
                Button {
                    selection = choice
                } label: {
                    Circle()
                        .fill(choice.color)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle()
                                .stroke(selection == choice ? Color.primary : Color.clear, lineWidth: 2)
                        )
                        .overlay(
                            Circle()
                                .stroke(choice == .white ? Color.gray.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MarkupInteractionOverlay: NSViewRepresentable {
    let onMouseDown: (CGPoint) -> Void
    let onMouseDragged: (CGPoint, CGPoint) -> Void
    let onMouseUp: (CGPoint, CGPoint) -> Void

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        view.onMouseDown = onMouseDown
        view.onMouseDragged = onMouseDragged
        view.onMouseUp = onMouseUp
        return view
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.onMouseDown = onMouseDown
        nsView.onMouseDragged = onMouseDragged
        nsView.onMouseUp = onMouseUp
    }

    final class InteractionView: NSView {
        var onMouseDown: ((CGPoint) -> Void)?
        var onMouseDragged: ((CGPoint, CGPoint) -> Void)?
        var onMouseUp: ((CGPoint, CGPoint) -> Void)?

        private var dragStartLocation: CGPoint?

        // Match SwiftUI's top-left coordinate system so markup placement
        // math stays consistent between the overlay, preview, and saved render.
        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(point) ? self : nil
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            let location = convert(event.locationInWindow, from: nil)
            dragStartLocation = location
            onMouseDown?(location)
        }

        override func mouseDragged(with event: NSEvent) {
            let currentLocation = convert(event.locationInWindow, from: nil)
            let startLocation = dragStartLocation ?? currentLocation
            onMouseDragged?(startLocation, currentLocation)
        }

        override func mouseUp(with event: NSEvent) {
            let currentLocation = convert(event.locationInWindow, from: nil)
            let startLocation = dragStartLocation ?? currentLocation
            onMouseUp?(startLocation, currentLocation)
            dragStartLocation = nil
        }
    }
}

private struct InlineTextField: NSViewRepresentable {
    @Binding var text: String
    let font: NSFont
    let textColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isBezeled = false
        field.lineBreakMode = .byClipping
        field.maximumNumberOfLines = 1
        field.delegate = context.coordinator
        field.font = font
        field.textColor = textColor
        field.stringValue = text
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
            field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.count, length: 0)
        }
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.font = font
        nsView.textColor = textColor
        DispatchQueue.main.async {
            if nsView.window?.firstResponder !== nsView.currentEditor() {
                nsView.window?.makeFirstResponder(nsView)
                nsView.currentEditor()?.selectedRange = NSRange(location: nsView.stringValue.count, length: 0)
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}
