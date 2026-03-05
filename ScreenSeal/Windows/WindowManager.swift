import AppKit
import Combine
import CoreImage
import os.log

private let logger = Logger(subsystem: "com.screenseal.app", category: "WindowManager")

final class WindowManager: ObservableObject {
    @Published private(set) var windows: [OverlayWindow] = []
    @Published var captureError: String?
    @Published var recordingState: RecordingState = .idle
    @Published var followCursorRecording = true
    @Published var cursorHighlightEnabled = true
    @Published var clickRingEnabled = true

    let presetManager = PresetManager()

    private var screenCaptureService: ScreenCaptureService?
    private var isStopping = false
    private var nextIndex = 1
    private var wakeObserver: Any?

    private var recordingServiceRef: AnyObject?

    var canStopRecording: Bool {
        guard #available(macOS 15.0, *) else { return false }
        switch recordingState {
        case .starting, .recording, .stopping:
            return true
        case .idle, .failed:
            return false
        }
    }

    init() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleWake()
        }

    }

    deinit {
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
        if case .starting = recordingState { return }
        if case .stopping = recordingState { return }
        if recordingState.isRecording { return }

        guard #available(macOS 15.0, *) else {
            recordingState = .failed(message: "録画機能は macOS 15.0 以降で利用できます")
            return
        }

        let targetDisplayID = preferredRecordingDisplayID()
        let service = (recordingServiceRef as? RecordingService)
            ?? RecordingService(
                followCursorCameraEnabled: followCursorRecording,
                cursorHighlightEnabled: cursorHighlightEnabled,
                clickRingEnabled: clickRingEnabled
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
                _ = try await service.start(displayID: targetDisplayID)
            } catch {
                await MainActor.run {
                    self.recordingServiceRef = nil
                    self.recordingState = .failed(message: "録画開始に必要な権限が不足、または開始に失敗しました")
                }
            }
        }
    }

    func stopRecording() {
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

    private func preferredRecordingDisplayID() -> CGDirectDisplayID {
        if let firstVisibleWindow = windows.first(where: { $0.isVisible }),
           let displayID = firstVisibleWindow.screen?.displayID {
            return displayID
        }
        return CGMainDisplayID()
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
