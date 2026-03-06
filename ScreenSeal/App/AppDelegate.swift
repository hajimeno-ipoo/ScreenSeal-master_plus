import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    let windowManager = WindowManager()
    private let permissionManager = PermissionManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await permissionManager.requestPermissionIfNeeded()
            await windowManager.refreshRecordingWindowOptions()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowManager.cancelRecordingCountdown()
        windowManager.stopRecording()
        windowManager.removeAllWindows()
    }
}
