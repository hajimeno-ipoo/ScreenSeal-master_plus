import AppKit
import Combine
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.screenseal.app", category: "WindowManager")

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

    init(screen: NSScreen, seconds: Int) {
        self.countdownView = CountdownOverlayView(seconds: seconds)

        let size = countdownView.frame.size
        let frame = NSRect(
            x: screen.frame.midX - (size.width / 2),
            y: screen.frame.midY - (size.height / 2),
            width: size.width,
            height: size.height
        )

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

    func update(seconds: Int) {
        countdownView.update(seconds: seconds)
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
    @Published var followCursorRecording = true
    @Published var cursorHighlightEnabled = true
    @Published var clickRingEnabled = true
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
    private var countdownTask: Task<Void, Never>?
    private var countdownOverlayWindow: CountdownOverlayWindow?

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
            return false
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

    }

    deinit {
        countdownTask?.cancel()
        dismissCountdownOverlay()
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

        beginRecordingCountdown(displayID: preferredRecordingDisplayID())
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
                    self.recordingServiceRef = nil
                    self.recordingState = .idle
                }
            } catch {
                do {
                    _ = try await service.stop()
                    await MainActor.run {
                        self.recordingServiceRef = nil
                        self.recordingState = .idle
                    }
                } catch {
                    await MainActor.run {
                        self.recordingServiceRef = nil
                        self.recordingState = .failed(message: "録画停止に失敗しました")
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
        }
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
    private func beginRecordingCountdown(displayID: CGDirectDisplayID) {
        countdownTask?.cancel()
        showCountdownOverlay(seconds: Self.recordingCountdownSeconds, displayID: displayID)
        recordingState = .countdown(secondsRemaining: Self.recordingCountdownSeconds)

        countdownTask = Task { [weak self] in
            guard let self else { return }

            for secondsRemaining in stride(from: Self.recordingCountdownSeconds, through: 1, by: -1) {
                if Task.isCancelled { return }

                await MainActor.run {
                    self.recordingState = .countdown(secondsRemaining: secondsRemaining)
                    self.showCountdownOverlay(seconds: secondsRemaining, displayID: displayID)
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
                self.startRecordingNow(displayID: displayID)
            }
        }
    }

    @available(macOS 15.0, *)
    private func startRecordingNow(displayID: CGDirectDisplayID) {
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
                _ = try await service.start(displayID: displayID)
            } catch {
                await MainActor.run {
                    self.recordingServiceRef = nil
                    self.recordingState = .failed(message: "録画開始に必要な権限が不足、または開始に失敗しました")
                }
            }
        }
    }

    private func preferredRecordingDisplayID() -> CGDirectDisplayID {
        if let firstVisibleWindow = windows.first(where: { $0.isVisible }),
           let displayID = firstVisibleWindow.screen?.displayID {
            return displayID
        }
        return CGMainDisplayID()
    }

    private func showCountdownOverlay(seconds: Int, displayID: CGDirectDisplayID) {
        guard let screen = NSScreen.screens.first(where: { $0.displayID == displayID })
            ?? NSScreen.screens.first else {
            return
        }

        if let window = countdownOverlayWindow, window.screen?.displayID == screen.displayID {
            window.update(seconds: seconds)
            window.orderFrontRegardless()
            return
        }

        dismissCountdownOverlay()
        let window = CountdownOverlayWindow(screen: screen, seconds: seconds)
        countdownOverlayWindow = window
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismissCountdownOverlay() {
        countdownOverlayWindow?.orderOut(nil)
        countdownOverlayWindow?.close()
        countdownOverlayWindow = nil
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
            let localY = windowRect.origin.y - screenFrame.origin.y

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
