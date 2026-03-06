import AppKit
import Combine
import CoreImage
import ScreenCaptureKit
import os.log

private let logger = Logger(subsystem: "com.screenseal.app", category: "WindowManager")

private final class WindowSelectionPickerCoordinator: NSObject, SCContentSharingPickerObserver {
    weak var windowManager: WindowManager?

    override init() {
        super.init()
        SCContentSharingPicker.shared.add(self)
    }

    deinit {
        SCContentSharingPicker.shared.remove(self)
    }

    func presentPicker(excludedBundleIDs: [String], excludedWindowIDs: [Int]) {
        let picker = SCContentSharingPicker.shared
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = .singleWindow
        configuration.allowsChangingSelectedContent = false
        configuration.excludedBundleIDs = excludedBundleIDs
        configuration.excludedWindowIDs = excludedWindowIDs
        picker.defaultConfiguration = configuration
        picker.isActive = true
        picker.present(using: .window)
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        picker.isActive = false
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { [weak self] in
            guard let self else { return }
            guard let selection = try await Self.resolveSelection(from: filter) else { return }
            await MainActor.run {
                picker.isActive = false
                self.windowManager?.applySystemWindowSelection(selection)
            }
        }
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        logger.error("Window picker failed to start: \(error.localizedDescription)")
    }

    private static func resolveSelection(from filter: SCContentFilter) async throws -> (windowID: CGWindowID, displayName: String)? {
        if #available(macOS 15.2, *), let window = filter.includedWindows.first {
            return (window.windowID, makeDisplayName(for: window))
        }

        let info = SCShareableContent.info(for: filter)
        guard info.style == .window else { return nil }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { approximatelyMatches($0.frame, info.contentRect) }) else {
            return nil
        }
        return (window.windowID, makeDisplayName(for: window))
    }

    private static func approximatelyMatches(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 2 &&
        abs(lhs.origin.y - rhs.origin.y) < 2 &&
        abs(lhs.size.width - rhs.size.width) < 2 &&
        abs(lhs.size.height - rhs.size.height) < 2
    }

    private static func makeDisplayName(for window: SCWindow) -> String {
        let appName = window.owningApplication?.applicationName ?? "Window"
        let cleanedTitle = (window.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return appName }
        return "\(appName) - \(cleanedTitle)"
    }
}

enum RecordingTarget: Equatable {
    case display
    case window(windowID: CGWindowID)
    case region(RecordingRegionSelection)
}

struct RecordingWindowOption: Identifiable, Equatable {
    let windowID: CGWindowID
    let appName: String
    let title: String
    let frame: CGRect
    let displayID: CGDirectDisplayID

    var id: CGWindowID { windowID }

    var menuTitle: String {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return appName }
        return "\(appName) - \(cleanedTitle)"
    }
}

struct RecordingRegionSelection: Equatable {
    let displayID: CGDirectDisplayID
    let rect: CGRect
}

enum ResolvedRecordingTarget: Equatable {
    case display(displayID: CGDirectDisplayID, frame: CGRect)
    case window(windowID: CGWindowID, windowFrame: CGRect, displayID: CGDirectDisplayID, displayFrame: CGRect)
    case region(RecordingRegionSelection)

    var countdownCenterPoint: CGPoint {
        switch self {
        case .display(_, let frame):
            return CGPoint(x: frame.midX, y: frame.midY)
        case .window(_, let windowFrame, _, _):
            return CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        case .region(let selection):
            return CGPoint(x: selection.rect.midX, y: selection.rect.midY)
        }
    }
}

private enum RecordingTargetResolutionError: LocalizedError {
    case windowNotFound
    case regionDisplayNotFound

    var errorDescription: String? {
        switch self {
        case .windowNotFound:
            return "選択したウィンドウが見つかりません。もう一度選んでください。"
        case .regionDisplayNotFound:
            return "選択した範囲を使えません。もう一度選び直してください。"
        }
    }
}

private final class CountdownOverlayView: NSView {
    private let label = NSTextField(labelWithString: "")

    init(seconds: Int) {
        super.init(frame: NSRect(x: 0, y: 0, width: 220, height: 220))
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.72).cgColor
        layer?.cornerRadius = 28

        label.font = .systemFont(ofSize: 120, weight: .bold)
        label.textColor = .white
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        update(seconds: seconds)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(seconds: Int) {
        label.stringValue = "\(seconds)"
    }
}

private final class CountdownOverlayWindow: NSWindow {
    private let countdownView: CountdownOverlayView

    init(center: CGPoint, seconds: Int) {
        self.countdownView = CountdownOverlayView(seconds: seconds)

        let size = countdownView.frame.size
        let frame = Self.frame(center: center, size: size)

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = countdownView
        setFrame(frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func update(seconds: Int, center: CGPoint) {
        countdownView.update(seconds: seconds)
        setFrame(Self.frame(center: center, size: countdownView.frame.size), display: false)
    }

    private static func frame(center: CGPoint, size: CGSize) -> NSRect {
        NSRect(
            x: center.x - (size.width / 2),
            y: center.y - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }
}

private final class RegionSelectionOverlayView: NSView {
    private let screenFrames: [CGDirectDisplayID: CGRect]
    var onComplete: ((RecordingRegionSelection) -> Void)?
    var onCancel: (() -> Void)?

    private var activeDisplayID: CGDirectDisplayID?
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    init(frame: NSRect, screenFrames: [CGDirectDisplayID: CGRect]) {
        self.screenFrames = screenFrames
        super.init(frame: frame)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        let dimAlpha: CGFloat = 0.22
        guard let selectionRect = selectionRectInView else {
            NSColor.black.withAlphaComponent(dimAlpha).setFill()
            dirtyRect.fill()
            return
        }

        let dimPath = NSBezierPath(rect: bounds)
        dimPath.appendRect(selectionRect)
        dimPath.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(dimAlpha).setFill()
        dimPath.fill()

        let strokePath = NSBezierPath(roundedRect: selectionRect, xRadius: 10, yRadius: 10)
        strokePath.lineWidth = 3
        strokePath.setLineDash([8, 6], count: 2, phase: 0)
        NSColor.systemBlue.withAlphaComponent(0.96).setStroke()
        strokePath.stroke()

        let innerPath = NSBezierPath(roundedRect: selectionRect.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        innerPath.lineWidth = 1
        innerPath.setLineDash([6, 6], count: 2, phase: 3)
        NSColor.white.withAlphaComponent(0.8).setStroke()
        innerPath.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = globalPoint(for: event)
        guard let (displayID, screenFrame) = screenFrame(containing: point) else { return }

        activeDisplayID = displayID
        let clampedPoint = clamp(point, to: screenFrame)
        startPoint = clampedPoint
        currentPoint = clampedPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let displayID = activeDisplayID,
              let screenFrame = screenFrames[displayID],
              startPoint != nil else { return }

        currentPoint = clamp(globalPoint(for: event), to: screenFrame)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let selection = currentSelection else {
            notifyCancel()
            return
        }

        if selection.rect.width < 8 || selection.rect.height < 8 {
            notifyCancel()
            return
        }

        notifyComplete(selection)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            notifyCancel()
            return
        }
        super.keyDown(with: event)
    }

    private func globalPoint(for event: NSEvent) -> CGPoint {
        guard let window else { return .zero }
        return CGPoint(
            x: window.frame.minX + event.locationInWindow.x,
            y: window.frame.minY + event.locationInWindow.y
        )
    }

    private func screenFrame(containing point: CGPoint) -> (CGDirectDisplayID, CGRect)? {
        screenFrames.first { $0.value.contains(point) }
    }

    private func clamp(_ point: CGPoint, to screenFrame: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, screenFrame.minX), screenFrame.maxX),
            y: min(max(point.y, screenFrame.minY), screenFrame.maxY)
        )
    }

    private var currentSelection: RecordingRegionSelection? {
        guard let displayID = activeDisplayID,
              let screenFrame = screenFrames[displayID],
              let startPoint,
              let currentPoint else {
            return nil
        }

        let rect = CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
        .intersection(screenFrame)
        .integral

        guard !rect.isEmpty else { return nil }
        return RecordingRegionSelection(displayID: displayID, rect: rect)
    }

    private var selectionRectInView: CGRect? {
        guard let selection = currentSelection,
              let window else { return nil }
        return selection.rect.offsetBy(dx: -window.frame.minX, dy: -window.frame.minY)
    }

    private func notifyComplete(_ selection: RecordingRegionSelection) {
        DispatchQueue.main.async { [onComplete] in
            onComplete?(selection)
        }
    }

    private func notifyCancel() {
        DispatchQueue.main.async { [onCancel] in
            onCancel?()
        }
    }
}

private final class RegionSelectionOverlayWindow: NSWindow {
    init(frame: NSRect, contentView: NSView) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class RegionRecordingOverlayView: NSView {
    private enum DragHandle: CaseIterable {
        case topLeft
        case top
        case topRight
        case right
        case bottomRight
        case bottom
        case bottomLeft
        case left
    }

    private static let handleSize: CGFloat = 12
    private static let minimumSelectionSize: CGFloat = 80

    private var selectionRect: CGRect
    private var isEditable = false
    private var activeHandle: DragHandle?
    private var dragStartPoint: CGPoint?
    private var dragStartRect: CGRect = .zero

    var onSelectionChanged: ((CGRect) -> Void)?

    init(frame frameRect: NSRect, selectionRect: CGRect) {
        self.selectionRect = selectionRect
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let dimPath = NSBezierPath(rect: bounds)
        dimPath.appendRect(selectionRect)
        dimPath.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.18).setFill()
        dimPath.fill()

        let strokePath = NSBezierPath(roundedRect: selectionRect, xRadius: 10, yRadius: 10)
        strokePath.lineWidth = 3
        strokePath.setLineDash([8, 6], count: 2, phase: 0)
        NSColor.systemBlue.withAlphaComponent(0.96).setStroke()
        strokePath.stroke()

        let innerPath = NSBezierPath(roundedRect: selectionRect.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        innerPath.lineWidth = 1
        innerPath.setLineDash([6, 6], count: 2, phase: 3)
        NSColor.white.withAlphaComponent(0.8).setStroke()
        innerPath.stroke()

        guard isEditable else { return }
        for handleRect in handleRects.values {
            let path = NSBezierPath(ovalIn: handleRect)
            NSColor.systemBlue.setFill()
            path.fill()
            NSColor.white.setStroke()
            path.lineWidth = 1.5
            path.stroke()
        }
    }

    func update(selectionRect: CGRect) {
        self.selectionRect = selectionRect
        needsDisplay = true
    }

    func setEditable(_ isEditable: Bool) {
        self.isEditable = isEditable
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard isEditable else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard let handle = hitHandle(at: point) else { return }

        activeHandle = handle
        dragStartPoint = point
        dragStartRect = selectionRect
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEditable,
              let activeHandle,
              let dragStartPoint else { return }

        let currentPoint = convert(event.locationInWindow, from: nil)
        var updatedRect = dragStartRect
        let deltaX = currentPoint.x - dragStartPoint.x
        let deltaY = currentPoint.y - dragStartPoint.y

        switch activeHandle {
        case .topLeft:
            updatedRect.origin.x += deltaX
            updatedRect.size.width -= deltaX
            updatedRect.size.height += deltaY
        case .top:
            updatedRect.size.height += deltaY
        case .topRight:
            updatedRect.size.width += deltaX
            updatedRect.size.height += deltaY
        case .right:
            updatedRect.size.width += deltaX
        case .bottomRight:
            updatedRect.size.width += deltaX
            updatedRect.origin.y += deltaY
            updatedRect.size.height -= deltaY
        case .bottom:
            updatedRect.origin.y += deltaY
            updatedRect.size.height -= deltaY
        case .bottomLeft:
            updatedRect.origin.x += deltaX
            updatedRect.size.width -= deltaX
            updatedRect.origin.y += deltaY
            updatedRect.size.height -= deltaY
        case .left:
            updatedRect.origin.x += deltaX
            updatedRect.size.width -= deltaX
        }

        let normalizedRect = normalized(rect: updatedRect)
        selectionRect = normalizedRect
        onSelectionChanged?(normalizedRect)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        activeHandle = nil
        dragStartPoint = nil
    }

    private var handleRects: [DragHandle: CGRect] {
        let half = Self.handleSize / 2
        return [
            .topLeft: CGRect(x: selectionRect.minX - half, y: selectionRect.maxY - half, width: Self.handleSize, height: Self.handleSize),
            .top: CGRect(x: selectionRect.midX - half, y: selectionRect.maxY - half, width: Self.handleSize, height: Self.handleSize),
            .topRight: CGRect(x: selectionRect.maxX - half, y: selectionRect.maxY - half, width: Self.handleSize, height: Self.handleSize),
            .right: CGRect(x: selectionRect.maxX - half, y: selectionRect.midY - half, width: Self.handleSize, height: Self.handleSize),
            .bottomRight: CGRect(x: selectionRect.maxX - half, y: selectionRect.minY - half, width: Self.handleSize, height: Self.handleSize),
            .bottom: CGRect(x: selectionRect.midX - half, y: selectionRect.minY - half, width: Self.handleSize, height: Self.handleSize),
            .bottomLeft: CGRect(x: selectionRect.minX - half, y: selectionRect.minY - half, width: Self.handleSize, height: Self.handleSize),
            .left: CGRect(x: selectionRect.minX - half, y: selectionRect.midY - half, width: Self.handleSize, height: Self.handleSize)
        ]
    }

    private func hitHandle(at point: CGPoint) -> DragHandle? {
        handleRects.first(where: { $0.value.contains(point) })?.key
    }

    private func normalized(rect: CGRect) -> CGRect {
        var rect = rect.standardized
        rect.size.width = max(rect.width, Self.minimumSelectionSize)
        rect.size.height = max(rect.height, Self.minimumSelectionSize)
        if rect.maxX > bounds.maxX {
            rect.origin.x = bounds.maxX - rect.width
        }
        if rect.maxY > bounds.maxY {
            rect.origin.y = bounds.maxY - rect.height
        }
        rect.origin.x = max(bounds.minX, rect.origin.x)
        rect.origin.y = max(bounds.minY, rect.origin.y)
        return rect.integral
    }
}

private final class RegionRecordingOverlayWindow: NSWindow {
    private let highlightView: RegionRecordingOverlayView

    init(frame: CGRect, selectionRect: CGRect, isEditable: Bool) {
        self.highlightView = RegionRecordingOverlayView(
            frame: CGRect(origin: .zero, size: frame.size),
            selectionRect: selectionRect
        )
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = !isEditable
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = highlightView
        highlightView.setEditable(isEditable)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func update(frame: CGRect, selectionRect: CGRect, isEditable: Bool) {
        setFrame(frame, display: true)
        highlightView.frame = CGRect(origin: .zero, size: frame.size)
        highlightView.update(selectionRect: selectionRect)
        highlightView.setEditable(isEditable)
        ignoresMouseEvents = !isEditable
    }

    func onSelectionChanged(_ handler: @escaping (CGRect) -> Void) {
        highlightView.onSelectionChanged = handler
    }
}

private final class RegionSelectionCoordinator {
    private var overlayWindow: RegionSelectionOverlayWindow?

    func present(
        onComplete: @escaping (RecordingRegionSelection) -> Void,
        onCancel: @escaping () -> Void
    ) {
        dismiss()

        let screens = NSScreen.screens
        let unionFrame = screens.map(\.frame).reduce(CGRect.null) { partial, frame in
            partial.union(frame)
        }
        let screenFrames = Dictionary(uniqueKeysWithValues: screens.map { ($0.displayID, $0.frame) })
        let overlayView = RegionSelectionOverlayView(
            frame: CGRect(origin: .zero, size: unionFrame.size),
            screenFrames: screenFrames
        )

        overlayView.onComplete = { [weak self] selection in
            self?.dismiss()
            onComplete(selection)
        }
        overlayView.onCancel = { [weak self] in
            self?.dismiss()
            onCancel()
        }

        let window = RegionSelectionOverlayWindow(frame: unionFrame, contentView: overlayView)
        overlayWindow = window
        NSCursor.crosshair.push()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        guard let overlayWindow else { return }
        NSCursor.pop()
        overlayWindow.orderOut(nil)
        overlayWindow.close()
        self.overlayWindow = nil
    }
}

private final class ColorPanelCoordinator: NSObject {
    private var onChange: ((CGColor) -> Void)?

    func present(title: String, color: CGColor, onChange: @escaping (CGColor) -> Void) {
        self.onChange = onChange

        let panel = NSColorPanel.shared
        panel.title = title
        panel.showsAlpha = true
        panel.isContinuous = true
        panel.setTarget(self)
        panel.setAction(#selector(handleColorChange(_:)))
        panel.color = NSColor(cgColor: color)?.usingColorSpace(.deviceRGB) ?? .white
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func handleColorChange(_ sender: NSColorPanel) {
        guard let cgColor = sender.color.usingColorSpace(.deviceRGB)?.cgColor else { return }
        onChange?(cgColor)
    }
}

final class WindowManager: ObservableObject {
    private static let recordingCountdownSeconds = 3
    private static let cursorHighlightColorKey = "ScreenSeal.cursorHighlightColor"
    private static let clickRingColorKey = "ScreenSeal.clickRingColor"
    private static let defaultCursorHighlightColor = CGColor(
        red: 0.10,
        green: 0.65,
        blue: 1.0,
        alpha: 0.52
    )
    private static let defaultClickRingColor = CGColor(
        red: 0.10,
        green: 0.72,
        blue: 1.0,
        alpha: 0.95
    )

    @Published private(set) var windows: [OverlayWindow] = []
    @Published var captureError: String?
    @Published var recordingState: RecordingState = .idle
    @Published var recordingTarget: RecordingTarget = .display
    @Published private(set) var selectedWindowDisplayName: String?
    @Published var followCursorRecording = false {
        didSet {
            guard followCursorRecording else { return }
            if recordingTarget != .display {
                selectDisplayRecordingTarget()
            }
        }
    }
    @Published var cursorHighlightEnabled = true
    @Published var clickRingEnabled = true
    @Published private(set) var isSelectingRecordingRegion = false
    @Published var cursorHighlightColor: CGColor {
        didSet { Self.saveColor(cursorHighlightColor, forKey: Self.cursorHighlightColorKey) }
    }
    @Published var clickRingColor: CGColor {
        didSet { Self.saveColor(clickRingColor, forKey: Self.clickRingColorKey) }
    }

    let presetManager = PresetManager()

    private var screenCaptureService: ScreenCaptureService?
    private var isStopping = false
    private var nextIndex = 1
    private var wakeObserver: Any?
    private let colorPanelCoordinator = ColorPanelCoordinator()
    private let regionSelectionCoordinator = RegionSelectionCoordinator()
    private let windowSelectionPickerCoordinator = WindowSelectionPickerCoordinator()
    private var countdownTask: Task<Void, Never>?
    private var countdownOverlayWindow: CountdownOverlayWindow?
    private var regionRecordingOverlayWindow: RegionRecordingOverlayWindow?

    private var recordingServiceRef: AnyObject?

    var canStopRecording: Bool {
        guard #available(macOS 15.0, *) else { return false }
        switch recordingState {
        case .starting, .recording, .stopping:
            return true
        case .idle, .countdown, .failed:
            return false
        }
    }

    var isCountdownActive: Bool {
        if case .countdown = recordingState { return true }
        return false
    }

    var isRecordingPreparationActive: Bool {
        switch recordingState {
        case .countdown, .starting, .recording, .stopping:
            return true
        case .idle, .failed:
            return isSelectingRecordingRegion
        }
    }

    init() {
        self.cursorHighlightColor = Self.loadColor(
            forKey: Self.cursorHighlightColorKey,
            fallback: Self.defaultCursorHighlightColor
        )
        self.clickRingColor = Self.loadColor(
            forKey: Self.clickRingColorKey,
            fallback: Self.defaultClickRingColor
        )
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWake()
        }
        windowSelectionPickerCoordinator.windowManager = self

    }

    deinit {
        countdownTask?.cancel()
        dismissCountdownOverlay()
        dismissRegionRecordingOverlay()
        regionSelectionCoordinator.dismiss()
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func createWindow() {
        let defaultSize = NSRect(x: 200, y: 200, width: 300, height: 200)
        let window = OverlayWindow(contentRect: defaultSize, index: nextIndex)
        window.windowManager = self
        nextIndex += 1
        windows.append(window)
        window.makeKeyAndOrderFront(nil)

        startCaptureIfNeeded()
        registerWindow(window)
    }

    func removeWindow(_ window: OverlayWindow) {
        window.orderOut(nil)
        windows.removeAll { $0 === window }
        if windows.isEmpty {
            stopCapture()
        }
    }

    func toggleWindow(_ window: OverlayWindow) {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
        }
        objectWillChange.send()
    }

    func removeAllWindows() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        stopCapture()
    }

    // MARK: - Recording

    func startRecording() {
        if isRecordingPreparationActive { return }

        guard #available(macOS 15.0, *) else {
            recordingState = .failed(message: "録画機能は macOS 15.0 以降で利用できます")
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let target = try await self.resolveRecordingTarget()
                await MainActor.run {
                    self.beginRecordingCountdown(target: target)
                }
            } catch {
                await MainActor.run {
                    self.recordingState = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    func stopRecording() {
        if isCountdownActive {
            cancelRecordingCountdown()
            return
        }

        guard #available(macOS 15.0, *), let service = recordingServiceRef as? RecordingService else { return }

        Task {
            do {
                _ = try await service.stop()
                await MainActor.run {
                    SCContentSharingPicker.shared.isActive = false
                    self.recordingServiceRef = nil
                    self.recordingState = .idle
                    self.recordingTarget = .display
                    self.dismissRegionRecordingOverlay()
                    self.removeAllWindows()
                }
            } catch {
                do {
                    _ = try await service.stop()
                    await MainActor.run {
                        SCContentSharingPicker.shared.isActive = false
                        self.recordingServiceRef = nil
                        self.recordingState = .idle
                        self.recordingTarget = .display
                        self.dismissRegionRecordingOverlay()
                        self.removeAllWindows()
                    }
                } catch {
                    await MainActor.run {
                        SCContentSharingPicker.shared.isActive = false
                        self.recordingServiceRef = nil
                        self.recordingState = .failed(message: "録画停止に失敗しました")
                        self.recordingTarget = .display
                        self.dismissRegionRecordingOverlay()
                    }
                }
            }
        }
    }

    func cancelRecordingCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        dismissCountdownOverlay()
        if isCountdownActive {
            recordingState = .idle
            if case .region(let selection) = recordingTarget {
                showRegionRecordingOverlay(for: selection, editable: true)
            }
        }
    }

    func selectDisplayRecordingTarget() {
        recordingTarget = .display
        selectedWindowDisplayName = nil
        dismissRegionRecordingOverlay()
    }

    func beginSystemWindowSelection() {
        guard !isRecordingPreparationActive, !followCursorRecording else { return }
        let excludedWindowIDs = windows.map { Int($0.windowNumber) }
        windowSelectionPickerCoordinator.presentPicker(
            excludedBundleIDs: [Bundle.main.bundleIdentifier ?? ""],
            excludedWindowIDs: excludedWindowIDs
        )
    }

    func applySystemWindowSelection(_ selection: (windowID: CGWindowID, displayName: String)) {
        recordingTarget = .window(windowID: selection.windowID)
        selectedWindowDisplayName = selection.displayName
        dismissRegionRecordingOverlay()
    }

    func beginRecordingRegionSelection() {
        guard !isRecordingPreparationActive, !followCursorRecording else { return }

        isSelectingRecordingRegion = true
        dismissRegionRecordingOverlay()
        regionSelectionCoordinator.present { [weak self] selection in
            self?.isSelectingRecordingRegion = false
            self?.recordingTarget = .region(selection)
            self?.selectedWindowDisplayName = nil
            self?.showRegionRecordingOverlay(for: selection, editable: true)
        } onCancel: { [weak self] in
            self?.isSelectingRecordingRegion = false
            if case .region(let selection) = self?.recordingTarget {
                self?.showRegionRecordingOverlay(for: selection, editable: true)
            }
        }
    }

    func isWindowRecordingTarget(_ windowID: CGWindowID) -> Bool {
        if case .window(let selectedWindowID) = recordingTarget {
            return selectedWindowID == windowID
        }
        return false
    }

    var isRegionRecordingTarget: Bool {
        if case .region = recordingTarget { return true }
        return false
    }

    func openCursorHighlightColorPanel() {
        colorPanelCoordinator.present(
            title: "Cursor Highlight Color",
            color: cursorHighlightColor
        ) { [weak self] color in
            self?.cursorHighlightColor = color
        }
    }

    func openClickRingColorPanel() {
        colorPanelCoordinator.present(
            title: "Click Ring Color",
            color: clickRingColor
        ) { [weak self] color in
            self?.clickRingColor = color
        }
    }

    func resetRecordingCursorColors() {
        cursorHighlightColor = Self.defaultCursorHighlightColor
        clickRingColor = Self.defaultClickRingColor
    }

    @available(macOS 15.0, *)
    private func beginRecordingCountdown(target: ResolvedRecordingTarget) {
        countdownTask?.cancel()
        if case .region(let selection) = target {
            showRegionRecordingOverlay(for: selection, editable: false)
        }
        showCountdownOverlay(seconds: Self.recordingCountdownSeconds, target: target)
        recordingState = .countdown(secondsRemaining: Self.recordingCountdownSeconds)

        countdownTask = Task { [weak self] in
            guard let self else { return }

            for secondsRemaining in stride(from: Self.recordingCountdownSeconds, through: 1, by: -1) {
                if Task.isCancelled { return }

                await MainActor.run {
                    self.recordingState = .countdown(secondsRemaining: secondsRemaining)
                    self.showCountdownOverlay(seconds: secondsRemaining, target: target)
                }

                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
            }

            if Task.isCancelled { return }

            await MainActor.run {
                self.countdownTask = nil
                self.dismissCountdownOverlay()
                self.recordingState = .starting
                self.startRecordingNow(target: target)
            }
        }
    }

    @available(macOS 15.0, *)
    private func startRecordingNow(target: ResolvedRecordingTarget) {
        let service = (recordingServiceRef as? RecordingService)
            ?? RecordingService(
                followCursorCameraEnabled: followCursorRecording,
                cursorHighlightEnabled: cursorHighlightEnabled,
                clickRingEnabled: clickRingEnabled,
                cursorHighlightColor: cursorHighlightColor,
                clickRingColor: clickRingColor
            )
        service.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.recordingState = state

                if case .idle = state {
                    self?.recordingServiceRef = nil
                } else if case .failed = state {
                    self?.recordingServiceRef = nil
                }
            }
        }
        recordingServiceRef = service

        Task {
            do {
                let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                let recordingFilterContext = await MainActor.run {
                    (
                        excludedApplications: self.excludedRecordingApplications(from: shareableContent),
                        exceptingWindows: self.exceptedRecordingWindows(from: shareableContent),
                        overlayWindowIDs: self.windows.map { CGWindowID($0.windowNumber) }
                    )
                }
                _ = try await service.start(
                    target: target,
                    excludedApplications: recordingFilterContext.excludedApplications,
                    exceptingWindows: recordingFilterContext.exceptingWindows,
                    overlayWindowIDs: recordingFilterContext.overlayWindowIDs
                )
            } catch {
                await MainActor.run {
                    self.recordingServiceRef = nil
                    self.recordingState = .failed(message: "録画開始に必要な権限が不足、または開始に失敗しました")
                    self.recordingTarget = .display
                    self.dismissRegionRecordingOverlay()
                }
            }
        }
    }

    @MainActor
    private func preferredRecordingDisplayID() -> CGDirectDisplayID {
        if let firstVisibleWindow = windows.first(where: { $0.isVisible }),
           let displayID = firstVisibleWindow.screen?.displayID {
            return displayID
        }
        return CGMainDisplayID()
    }

    private func showCountdownOverlay(seconds: Int, target: ResolvedRecordingTarget) {
        let center = target.countdownCenterPoint

        if let window = countdownOverlayWindow {
            window.update(seconds: seconds, center: center)
            window.orderFrontRegardless()
            return
        }

        dismissCountdownOverlay()
        let window = CountdownOverlayWindow(center: center, seconds: seconds)
        countdownOverlayWindow = window
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismissCountdownOverlay() {
        countdownOverlayWindow?.orderOut(nil)
        countdownOverlayWindow?.close()
        countdownOverlayWindow = nil
    }

    private func showRegionRecordingOverlay(for selection: RecordingRegionSelection, editable: Bool) {
        guard let displayFrame = NSScreen.screens.first(where: { $0.displayID == selection.displayID })?.frame else {
            return
        }
        let localRect = selection.rect.offsetBy(dx: -displayFrame.minX, dy: -displayFrame.minY)

        if let window = regionRecordingOverlayWindow {
            window.update(frame: displayFrame, selectionRect: localRect, isEditable: editable)
            window.orderFrontRegardless()
            return
        }

        let window = RegionRecordingOverlayWindow(frame: displayFrame, selectionRect: localRect, isEditable: editable)
        window.onSelectionChanged { [weak self] localRect in
            guard let self else { return }
            let globalRect = localRect.offsetBy(dx: displayFrame.minX, dy: displayFrame.minY)
            let selection = RecordingRegionSelection(displayID: selection.displayID, rect: globalRect.integral)
            self.recordingTarget = .region(selection)
        }
        regionRecordingOverlayWindow = window
        window.orderFrontRegardless()
    }

    private func dismissRegionRecordingOverlay() {
        regionRecordingOverlayWindow?.orderOut(nil)
        regionRecordingOverlayWindow?.close()
        regionRecordingOverlayWindow = nil
    }

    @available(macOS 15.0, *)
    private func excludedRecordingApplications(from content: SCShareableContent) -> [SCRunningApplication] {
        let selfBundleID = Bundle.main.bundleIdentifier ?? ""
        return content.applications.filter { $0.bundleIdentifier == selfBundleID }
    }

    @available(macOS 15.0, *)
    private func exceptedRecordingWindows(from content: SCShareableContent) -> [SCWindow] {
        let overlayWindowIDs = Set(windows.map { CGWindowID($0.windowNumber) })
        return content.windows.filter { overlayWindowIDs.contains($0.windowID) }
    }

    private static func saveColor(_ color: CGColor, forKey key: String) {
        guard let normalizedColor = NSColor(cgColor: color)?.usingColorSpace(.deviceRGB),
              let data = try? NSKeyedArchiver.archivedData(
                withRootObject: normalizedColor,
                requiringSecureCoding: true
              ) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadColor(forKey key: String, fallback: CGColor) -> CGColor {
        guard let data = UserDefaults.standard.data(forKey: key),
              let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data),
              let normalizedColor = color.usingColorSpace(.deviceRGB) else {
            return fallback
        }
        return normalizedColor.cgColor
    }

    @available(macOS 15.0, *)
    private func resolveRecordingTarget() async throws -> ResolvedRecordingTarget {
        switch recordingTarget {
        case .display:
            let displayID = await MainActor.run {
                preferredRecordingDisplayID()
            }
            let frame = await MainActor.run {
                NSScreen.screens.first(where: { $0.displayID == displayID })?.frame
                    ?? NSScreen.main?.frame
                    ?? .zero
            }
            return .display(displayID: displayID, frame: frame)

        case .window(let windowID):
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
            guard let window = content.windows.first(where: { $0.windowID == windowID && $0.isOnScreen }) else {
                throw RecordingTargetResolutionError.windowNotFound
            }
            let fallbackDisplayID = await MainActor.run(body: { Self.displayID(for: window.frame) })
            guard let displayID = fallbackDisplayID,
                  let displayFrame = await MainActor.run(body: {
                      NSScreen.screens.first(where: { $0.displayID == displayID })?.frame
                  }) else {
                throw RecordingTargetResolutionError.windowNotFound
            }
            let windowFrame = CGRect(
                x: displayFrame.minX + window.frame.minX,
                y: displayFrame.maxY - window.frame.maxY,
                width: window.frame.width,
                height: window.frame.height
            )
            return .window(
                windowID: windowID,
                windowFrame: windowFrame,
                displayID: displayID,
                displayFrame: displayFrame
            )

        case .region(let selection):
            let frame = await MainActor.run {
                NSScreen.screens.first(where: { $0.displayID == selection.displayID })?.frame
            }
            guard let frame else {
                throw RecordingTargetResolutionError.regionDisplayNotFound
            }
            let clampedRect = selection.rect.intersection(frame)
            guard !clampedRect.isEmpty else {
                throw RecordingTargetResolutionError.regionDisplayNotFound
            }
            return .region(RecordingRegionSelection(displayID: selection.displayID, rect: clampedRect))
        }
    }

    private static func displayID(for frame: CGRect) -> CGDirectDisplayID? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return screen.displayID
        }
        return NSScreen.screens.first(where: { $0.frame.intersects(frame) })?.displayID
    }

    // MARK: - Presets

    func saveCurrentLayout(name: String) {
        let snapshots = windows.map { window -> WindowSnapshot in
            let frame = window.frame
            return WindowSnapshot(
                x: frame.origin.x,
                y: frame.origin.y,
                width: frame.width,
                height: frame.height,
                mosaicType: window.configuration.mosaicType.rawValue,
                intensity: window.configuration.intensity
            )
        }
        let preset = LayoutPreset(name: name, windows: snapshots)
        presetManager.add(preset)
        objectWillChange.send()
    }

    func loadPreset(_ preset: LayoutPreset) {
        removeAllWindows()

        for snapshot in preset.windows {
            let rect = NSRect(x: snapshot.x, y: snapshot.y, width: snapshot.width, height: snapshot.height)
            let window = OverlayWindow(contentRect: rect, index: nextIndex)
            window.windowManager = self
            nextIndex += 1

            if let type = MosaicType(rawValue: snapshot.mosaicType) {
                window.configuration.mosaicType = type
                window.configuration.intensity = snapshot.intensity
            }

            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }

        if !windows.isEmpty {
            startCaptureIfNeeded()
            Task {
                await screenCaptureService?.updateExclusion()
            }
        }
    }

    // MARK: - Sleep/Wake

    private func handleWake() {
        guard !windows.isEmpty else { return }
        logger.info("System woke from sleep, restarting capture")
        restartCapture()
    }

    private func restartCapture() {
        guard let service = screenCaptureService else { return }
        isStopping = true
        screenCaptureService = nil
        Task {
            await service.stopCapture()
            await MainActor.run {
                isStopping = false
                startCaptureIfNeeded()
            }
        }
    }

    // MARK: - Capture

    private func startCaptureIfNeeded() {
        guard screenCaptureService == nil, !isStopping else { return }
        let service = ScreenCaptureService()
        screenCaptureService = service
        service.onFrame = { [weak self] frame, displayID in
            Task { @MainActor [weak self] in
                self?.distributeFrame(frame, displayID: displayID)
            }
        }
        service.onError = { [weak self] message in
            DispatchQueue.main.async {
                self?.captureError = Self.userFriendlyCaptureError(from: message)
            }
        }
        captureError = nil
        Task {
            await service.startCapture()
        }
    }

    private func stopCapture() {
        guard let service = screenCaptureService else { return }
        isStopping = true
        screenCaptureService = nil
        Task {
            await service.stopCapture()
            await MainActor.run { isStopping = false }
        }
    }

    private func registerWindow(_ window: OverlayWindow) {
        Task {
            await screenCaptureService?.updateExclusion()
        }
    }

    private func distributeFrame(_ frame: CIImage, displayID: CGDirectDisplayID) {
        let frameExtent = frame.extent

        for window in windows {
            guard let screen = window.screen, screen.displayID == displayID else { continue }

            let windowRect = window.frame
            let screenFrame = screen.frame

            let scaleX = frameExtent.width / screenFrame.width
            let scaleY = frameExtent.height / screenFrame.height

            let localX = windowRect.origin.x - screenFrame.origin.x
            let localY = screenFrame.maxY - windowRect.maxY

            let captureX = localX * scaleX
            let captureY = localY * scaleY
            let captureW = windowRect.width * scaleX
            let captureH = windowRect.height * scaleY

            let baseRect = CGRect(x: captureX, y: captureY, width: captureW, height: captureH)
                .intersection(frameExtent)
            guard !baseRect.isEmpty else { continue }
            let cropRect = baseRect
            guard !cropRect.isEmpty else { continue }

            let cropped = frame.cropped(to: cropRect)
                .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))

            DispatchQueue.main.async {
                window.overlayContentView.updateFrame(cropped)
            }
        }
    }

    private static func userFriendlyCaptureError(from rawMessage: String) -> String {
        let lower = rawMessage.lowercased()
        if lower.contains("tcc") || lower.contains("denied") || rawMessage.contains("拒否") {
            return "画面収録の権限が未許可です。システム設定で許可してください。"
        }
        return rawMessage
    }
}
