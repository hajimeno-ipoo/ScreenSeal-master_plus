import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowManager = WindowManager()
    private let permissionManager = PermissionManager()
    private var recordingControlItem: NSStatusItem?
    private var recordingStateCancellable: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureRecordingControlItem()
        recordingStateCancellable = windowManager.$recordingState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateRecordingControlItem()
            }

        Task {
            await permissionManager.requestPermissionIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let recordingControlItem {
            NSStatusBar.system.removeStatusItem(recordingControlItem)
        }
        windowManager.cancelRecordingCountdown()
        windowManager.stopRecording()
        windowManager.removeAllWindows()
    }

    private func configureRecordingControlItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(handleRecordingControlClick(_:))
        item.button?.sendAction(on: [.leftMouseUp])
        recordingControlItem = item
        updateRecordingControlItem()
    }

    private func updateRecordingControlItem() {
        guard let button = recordingControlItem?.button else { return }

        let configuration: (symbol: String, description: String, color: NSColor?)
        switch windowManager.recordingState {
        case .idle, .failed:
            configuration = ("record.circle", "Start Recording", nil)
        case .countdown:
            configuration = ("xmark.circle", "Cancel Countdown", .systemOrange)
        case .starting, .recording, .stopping:
            configuration = ("stop.circle.fill", "Stop Recording", .systemRed)
        }

        button.image = NSImage(systemSymbolName: configuration.symbol, accessibilityDescription: configuration.description)
        button.contentTintColor = configuration.color
        button.toolTip = configuration.description
    }

    @objc
    private func handleRecordingControlClick(_ sender: Any?) {
        switch windowManager.recordingState {
        case .countdown:
            windowManager.cancelRecordingCountdown()
        case .starting, .recording, .stopping:
            windowManager.stopRecording()
        case .idle, .failed:
            windowManager.startRecording()
        }
    }
}
