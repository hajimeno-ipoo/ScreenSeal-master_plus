import AppKit
@preconcurrency import AVFoundation
import Combine
import CoreImage
import ScreenCaptureKit
import os.log

enum AppLanguage: String, CaseIterable, Equatable {
    case english = "en"
    case japanese = "ja"

    static let userDefaultsKey = "ScreenSeal_plus.appLanguage"

    static func resolved(userDefaults: UserDefaults = .standard) -> AppLanguage {
        if let rawValue = userDefaults.string(forKey: userDefaultsKey),
           let language = AppLanguage(rawValue: rawValue) {
            return language
        }
        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        return preferred.hasPrefix("ja") ? .japanese : .english
    }

    var menuTitle: String {
        switch self {
        case .english:
            return "English"
        case .japanese:
            return "日本語"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english:
            return "en_US"
        case .japanese:
            return "ja_JP"
        }
    }
}

enum AppStringKey {
    case newMosaicWindow
    case removeAllWindows
    case saveCurrentLayout
    case loadPreset
    case deletePreset
    case openScreenRecordingSettings
    case quitApp
    case startRecording
    case cancelCountdown
    case stopRecording
    case takeScreenshot
    case stopScrollCapture
    case language
    case captureMode
    case record
    case screenshot
    case screenshotType
    case singleScreenshot
    case scrollCapture
    case screenshotScale
    case captureTarget
    case fullDisplay
    case chooseWindow
    case selectRegion
    case screenshotClickAction
    case recordingClickAction
    case preview
    case finder
    case quickTime
    case zoomMagnification
    case followCursor
    case livePreviewDuringRecording
    case cursorHighlight
    case clickRing
    case cursorHighlightColor
    case clickRingColor
    case resetCursorColors
    case saveLayoutPreset
    case saveLayoutPresetMessage
    case save
    case cancel
    case presetName
    case version
    case selectedWindow
    case screenshotSavedTitle
    case scrollCaptureSavedTitle
    case recordingSavedTitle
    case mosaicType
    case intensity
    case unlockPosition
    case lockPosition
    case closeWindow
    case livePreview
    case pinPreview
    case pin
    case unpin
    case pinLivePreview
    case unpinLivePreview
    case mosaicOverlay
    case mosaicOverlayHelp
    case noDisplayFound
}

struct AppStrings {
    private static let english: [AppStringKey: String] = [
        .newMosaicWindow: "New Mosaic Window",
        .removeAllWindows: "Remove All Windows",
        .saveCurrentLayout: "Save Current Layout...",
        .loadPreset: "Load Preset",
        .deletePreset: "Delete Preset",
        .openScreenRecordingSettings: "Open Screen Recording Settings",
        .quitApp: "Quit ScreenSeal_plus",
        .startRecording: "Start Recording",
        .cancelCountdown: "Cancel Countdown",
        .stopRecording: "Stop Recording",
        .takeScreenshot: "Take Screenshot",
        .stopScrollCapture: "Stop Scroll Capture",
        .language: "Language",
        .captureMode: "Capture Mode",
        .record: "Record",
        .screenshot: "Screenshot",
        .screenshotType: "Screenshot Type",
        .singleScreenshot: "Single Screenshot",
        .scrollCapture: "Scroll Capture",
        .screenshotScale: "Screenshot Scale",
        .captureTarget: "Capture Target",
        .fullDisplay: "Full Display",
        .chooseWindow: "Choose Window...",
        .selectRegion: "Select Region...",
        .screenshotClickAction: "Screenshot Click Action",
        .recordingClickAction: "Recording Click Action",
        .preview: "Preview",
        .finder: "Finder",
        .quickTime: "QuickTime",
        .zoomMagnification: "Zoom Magnification",
        .followCursor: "Follow Cursor",
        .livePreviewDuringRecording: "Live Preview During Recording",
        .cursorHighlight: "Cursor Highlight",
        .clickRing: "Click Ring",
        .cursorHighlightColor: "Cursor Highlight Color...",
        .clickRingColor: "Click Ring Color...",
        .resetCursorColors: "Reset Cursor Colors",
        .saveLayoutPreset: "Save Layout Preset",
        .saveLayoutPresetMessage: "Enter a name for this layout:",
        .save: "Save",
        .cancel: "Cancel",
        .presetName: "Preset name",
        .version: "Version",
        .selectedWindow: "Selected Window",
        .screenshotSavedTitle: "Screenshot Saved",
        .scrollCaptureSavedTitle: "Scroll Capture Saved",
        .recordingSavedTitle: "Recording Saved",
        .mosaicType: "Mosaic Type",
        .intensity: "Intensity",
        .unlockPosition: "Unlock Position",
        .lockPosition: "Lock Position",
        .closeWindow: "Close Window",
        .livePreview: "Live Preview",
        .pinPreview: "Pin Preview",
        .pin: "Pin",
        .unpin: "Unpin",
        .pinLivePreview: "Pin live preview",
        .unpinLivePreview: "Unpin live preview",
        .mosaicOverlay: "Mosaic Overlay",
        .mosaicOverlayHelp: "Right-click to change mosaic settings. Scroll to adjust intensity.",
        .noDisplayFound: "No display found",
    ]

    private static let japanese: [AppStringKey: String] = [
        .newMosaicWindow: "新しいモザイクウィンドウ",
        .removeAllWindows: "すべてのウィンドウを削除",
        .saveCurrentLayout: "現在のレイアウトを保存...",
        .loadPreset: "プリセットを読み込む",
        .deletePreset: "プリセットを削除",
        .openScreenRecordingSettings: "画面収録の設定を開く",
        .quitApp: "ScreenSeal_plus を終了",
        .startRecording: "録画開始",
        .cancelCountdown: "カウントダウンを中止",
        .stopRecording: "録画停止",
        .takeScreenshot: "スクリーンショットを撮る",
        .stopScrollCapture: "スクロールキャプチャを停止",
        .language: "言語",
        .captureMode: "キャプチャモード",
        .record: "録画",
        .screenshot: "スクリーンショット",
        .screenshotType: "スクリーンショット種別",
        .singleScreenshot: "通常スクリーンショット",
        .scrollCapture: "スクロールキャプチャ",
        .screenshotScale: "保存倍率",
        .captureTarget: "キャプチャ対象",
        .fullDisplay: "フルディスプレイ",
        .chooseWindow: "ウィンドウを選ぶ...",
        .selectRegion: "範囲を選ぶ...",
        .screenshotClickAction: "スクリーンショットのクリック動作",
        .recordingClickAction: "録画のクリック動作",
        .preview: "プレビュー",
        .finder: "Finder",
        .quickTime: "QuickTime",
        .zoomMagnification: "ズーム倍率",
        .followCursor: "カーソルを追う",
        .livePreviewDuringRecording: "録画中のライブプレビュー",
        .cursorHighlight: "カーソル強調",
        .clickRing: "クリックリング",
        .cursorHighlightColor: "カーソル強調色...",
        .clickRingColor: "クリックリング色...",
        .resetCursorColors: "カーソル色をリセット",
        .saveLayoutPreset: "レイアウトを保存",
        .saveLayoutPresetMessage: "このレイアウト名を入力してください:",
        .save: "保存",
        .cancel: "キャンセル",
        .presetName: "プリセット名",
        .version: "バージョン",
        .selectedWindow: "選択中のウィンドウ",
        .screenshotSavedTitle: "スクリーンショットを保存しました",
        .scrollCaptureSavedTitle: "スクロールキャプチャを保存しました",
        .recordingSavedTitle: "録画を保存しました",
        .mosaicType: "モザイク種類",
        .intensity: "強さ",
        .unlockPosition: "位置固定を解除",
        .lockPosition: "位置を固定",
        .closeWindow: "ウィンドウを閉じる",
        .livePreview: "ライブプレビュー",
        .pinPreview: "プレビューを固定",
        .pin: "固定",
        .unpin: "固定解除",
        .pinLivePreview: "ライブプレビューを固定",
        .unpinLivePreview: "ライブプレビューの固定を解除",
        .mosaicOverlay: "モザイクオーバーレイ",
        .mosaicOverlayHelp: "右クリックで設定変更。スクロールで強さ調整。",
        .noDisplayFound: "画面が見つかりません。",
    ]

    static func text(_ key: AppStringKey, in language: AppLanguage) -> String {
        switch language {
        case .english:
            return english[key] ?? ""
        case .japanese:
            return japanese[key] ?? ""
        }
    }

    static func text(_ key: AppStringKey) -> String {
        text(key, in: AppLanguage.resolved())
    }

    static func languageDisplayName(_ language: AppLanguage) -> String {
        language.menuTitle
    }

    static func version(short: String, build: String, in language: AppLanguage) -> String {
        "\(text(.version, in: language)) \(short) (\(build))"
    }

    static func presetDefaultName(_ count: Int, in language: AppLanguage) -> String {
        switch language {
        case .english:
            return "Preset \(count)"
        case .japanese:
            return "プリセット \(count)"
        }
    }

    static func presetSummary(name: String, count: Int, in language: AppLanguage) -> String {
        switch language {
        case .english:
            return "\(name) (\(count) windows)"
        case .japanese:
            return "\(name)（\(count)ウィンドウ）"
        }
    }

    static func selectedWindow(_ name: String, in language: AppLanguage) -> String {
        "\(text(.selectedWindow, in: language)): \(name)"
    }

    static func screenshotSaving(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Screenshot: saving..."
        case .japanese: return "スクリーンショット: 保存中..."
        }
    }

    static func screenshotSaved(filename: String, in language: AppLanguage) -> String {
        switch language {
        case .english: return "Screenshot saved: \(filename)"
        case .japanese: return "スクリーンショット保存: \(filename)"
        }
    }

    static func scrollCapturePreparing(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Scroll Capture: preparing..."
        case .japanese: return "スクロールキャプチャ: 準備中..."
        }
    }

    static func scrollCaptureStopping(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Scroll Capture: stopping..."
        case .japanese: return "スクロールキャプチャ: 停止中..."
        }
    }

    static func scrollCaptureSaved(filename: String, in language: AppLanguage) -> String {
        switch language {
        case .english: return "Scroll Capture saved: \(filename)"
        case .japanese: return "スクロールキャプチャ保存: \(filename)"
        }
    }

    static func recordingStartsIn(_ secondsRemaining: Int, in language: AppLanguage) -> String {
        switch language {
        case .english: return "Recording starts in \(secondsRemaining)..."
        case .japanese: return "録画開始まで \(secondsRemaining)..."
        }
    }

    static func recordingStarting(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Recording: starting..."
        case .japanese: return "録画: 開始中..."
        }
    }

    static func recordingStartedAt(_ timeText: String, in language: AppLanguage) -> String {
        switch language {
        case .english: return "Recording: ON (started at \(timeText))"
        case .japanese: return "録画中（開始 \(timeText)）"
        }
    }

    static func recordingStopping(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Recording: stopping..."
        case .japanese: return "録画: 停止中..."
        }
    }

    static func clickToOpenIn(_ target: String, in language: AppLanguage) -> String {
        switch language {
        case .english: return "Click to open in \(target)"
        case .japanese: return "クリックで \(target) で開く"
        }
    }

    static func recordingFeatureRequiresMacOS15(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Recording is available on macOS 15.0 or later."
        case .japanese: return "録画機能は macOS 15.0 以降で利用できます。"
        }
    }

    static func recordingStartFailed(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Recording permission is missing, or recording could not start."
        case .japanese: return "録画開始に必要な権限が不足、または開始に失敗しました。"
        }
    }

    static func recordingDataUnavailable(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Recording data could not be captured."
        case .japanese: return "録画データを取得できませんでした。"
        }
    }

    static func recordingStopFailed(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Recording could not be stopped."
        case .japanese: return "録画停止に失敗しました。"
        }
    }

    static func windowNotFound(in language: AppLanguage) -> String {
        switch language {
        case .english: return "The selected window could not be found. Please select it again."
        case .japanese: return "選択したウィンドウが見つかりません。もう一度選んでください。"
        }
    }

    static func regionDisplayNotFound(in language: AppLanguage) -> String {
        switch language {
        case .english: return "The selected region is no longer available. Please choose it again."
        case .japanese: return "選択した範囲を使えません。もう一度選び直してください。"
        }
    }

    static func screenshotDisplayNotFound(in language: AppLanguage) -> String {
        switch language {
        case .english: return "The display for this capture could not be found."
        case .japanese: return "キャプチャ対象の画面が見つかりません。"
        }
    }

    static func screenshotWindowNotFound(in language: AppLanguage) -> String {
        switch language {
        case .english: return "The selected window could not be found."
        case .japanese: return "選択したウィンドウが見つかりません。"
        }
    }

    static func screenshotImageCreationFailed(in language: AppLanguage) -> String {
        switch language {
        case .english: return "The screenshot image could not be created."
        case .japanese: return "スクリーンショット画像を取得できませんでした。"
        }
    }

    static func screenshotPngEncodingFailed(in language: AppLanguage) -> String {
        switch language {
        case .english: return "The screenshot PNG could not be created."
        case .japanese: return "スクリーンショットの保存形式を作れませんでした。"
        }
    }

    static func scrollCaptureInvalidTarget(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Scroll Capture requires Window or Region."
        case .japanese: return "スクロールキャプチャは Window か Region が必要です。"
        }
    }

    static func accessibilityPermissionRequired(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Scroll Capture requires Accessibility permission."
        case .japanese: return "スクロールキャプチャにはアクセシビリティ権限が必要です。"
        }
    }

    static func scrollEventCreationFailed(in language: AppLanguage) -> String {
        switch language {
        case .english: return "The scroll event could not be created."
        case .japanese: return "スクロールイベントを作成できませんでした。"
        }
    }

    static func scrollImageProcessingFailed(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Scroll Capture image processing failed."
        case .japanese: return "スクロールキャプチャの画像処理に失敗しました。"
        }
    }

    static func noScrollCaptureFrames(in language: AppLanguage) -> String {
        switch language {
        case .english: return "No scroll capture frames were produced."
        case .japanese: return "スクロールキャプチャ画像を取得できませんでした。"
        }
    }

    static func scrollCaptureZipCreationFailed(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Scroll Capture ZIP creation failed."
        case .japanese: return "スクロールキャプチャの ZIP 作成に失敗しました。"
        }
    }

    static func screenCaptureFailed(_ message: String, in language: AppLanguage) -> String {
        switch language {
        case .english: return "Screen capture failed: \(message)"
        case .japanese: return "画面キャプチャに失敗しました: \(message)"
        }
    }

    static func screenCapturePermissionRequired(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Screen Recording permission is not granted. Allow it in System Settings."
        case .japanese: return "画面収録の権限が未許可です。システム設定で許可してください。"
        }
    }

    static func mosaicWindowName(index: Int, in language: AppLanguage) -> String {
        switch language {
        case .english: return "Mosaic #\(index)"
        case .japanese: return "モザイク #\(index)"
        }
    }

    static func defaultWindowName(in language: AppLanguage) -> String {
        switch language {
        case .english: return "Window"
        case .japanese: return "ウィンドウ"
        }
    }
}

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
        windowManager?.setOverlayWindowsInteractive(true)
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { [weak self] in
            guard let self else { return }
            let selection = try await Self.resolveSelection(from: filter)
            await MainActor.run {
                picker.isActive = false
                self.windowManager?.setOverlayWindowsInteractive(true)
                if let selection {
                    self.windowManager?.applySystemWindowSelection(selection)
                }
            }
        }
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        windowManager?.setOverlayWindowsInteractive(true)
        logger.error("Window picker failed to start: \(error.localizedDescription)")
    }

    private static func resolveSelection(from filter: SCContentFilter) async throws -> (windowID: CGWindowID, displayID: CGDirectDisplayID?, displayName: String)? {
        if #available(macOS 15.2, *), let window = filter.includedWindows.first {
            return (window.windowID, Self.displayID(for: window.frame), makeDisplayName(for: window))
        }

        let info = SCShareableContent.info(for: filter)
        guard info.style == .window else { return nil }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { approximatelyMatches($0.frame, info.contentRect) }) else {
            return nil
        }
        return (window.windowID, Self.displayID(for: window.frame), makeDisplayName(for: window))
    }

    private static func approximatelyMatches(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.origin.x - rhs.origin.x) < 2 &&
        abs(lhs.origin.y - rhs.origin.y) < 2 &&
        abs(lhs.size.width - rhs.size.width) < 2 &&
        abs(lhs.size.height - rhs.size.height) < 2
    }

    private static func makeDisplayName(for window: SCWindow) -> String {
        let appName = window.owningApplication?.applicationName ?? AppStrings.defaultWindowName(in: AppLanguage.resolved())
        let cleanedTitle = (window.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return appName }
        return "\(appName) - \(cleanedTitle)"
    }

    private static func displayID(for frame: CGRect) -> CGDirectDisplayID? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return screen.displayID
        }
        return NSScreen.screens.first(where: { $0.frame.intersects(frame) })?.displayID
    }
}

enum RecordingTarget: Equatable {
    case display
    case window(windowID: CGWindowID)
    case region(RecordingRegionSelection)
}

enum CaptureMode: String, Equatable {
    case record = "Record"
    case screenshot = "Screenshot"

    func localizedTitle(in language: AppLanguage) -> String {
        switch self {
        case .record:
            return AppStrings.text(.record, in: language)
        case .screenshot:
            return AppStrings.text(.screenshot, in: language)
        }
    }
}

enum ScreenshotOpenAction: String, CaseIterable, Equatable {
    case preview = "Preview"
    case finder = "Finder"

    func localizedTitle(in language: AppLanguage) -> String {
        switch self {
        case .preview:
            return AppStrings.text(.preview, in: language)
        case .finder:
            return AppStrings.text(.finder, in: language)
        }
    }
}

enum ScreenshotCaptureType: String, CaseIterable, Equatable {
    case single = "Single Screenshot"
    case scroll = "Scroll Capture"

    func localizedTitle(in language: AppLanguage) -> String {
        switch self {
        case .single:
            return AppStrings.text(.singleScreenshot, in: language)
        case .scroll:
            return AppStrings.text(.scrollCapture, in: language)
        }
    }
}

enum ScreenshotScaleOption: String, CaseIterable, Equatable {
    case original = "original"
    case x2 = "2x"
    case x1 = "1x"
    case x0_5 = "0.5x"

    func localizedTitle(in language: AppLanguage) -> String {
        switch self {
        case .original:
            return rawValue
        case .x2, .x1, .x0_5:
            return rawValue
        }
    }
}

enum RecordingOpenAction: String, CaseIterable, Equatable {
    case quickTime = "QuickTime"
    case finder = "Finder"

    func localizedTitle(in language: AppLanguage) -> String {
        switch self {
        case .quickTime:
            return AppStrings.text(.quickTime, in: language)
        case .finder:
            return AppStrings.text(.finder, in: language)
        }
    }
}

enum RecordingZoomScale: Double, CaseIterable, Equatable {
    case x1_2 = 1.2
    case x1_5 = 1.5
    case x1_8 = 1.8
    case x2_0 = 2.0
    case x2_5 = 2.5

    var menuTitle: String {
        String(format: "%.1fx", rawValue)
    }
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
            return AppStrings.windowNotFound(in: AppLanguage.resolved())
        case .regionDisplayNotFound:
            return AppStrings.regionDisplayNotFound(in: AppLanguage.resolved())
        }
    }
}

private final class ScreenshotPreviewView: NSView {
    private let titleLabel: NSTextField
    private let subtitleLabel: NSTextField
    private let imageContainerView = NSView()
    private let imageLayer = CALayer()
    var onClick: (() -> Void)?

    init(image: CGImage, title: String, subtitle: String) {
        self.titleLabel = NSTextField(labelWithString: title)
        self.subtitleLabel = NSTextField(labelWithString: subtitle)
        super.init(frame: NSRect(x: 0, y: 0, width: 200, height: 150))
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.84).cgColor
        layer?.cornerRadius = 16
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor

        imageContainerView.wantsLayer = true
        imageContainerView.layer?.cornerRadius = 10
        imageContainerView.layer?.masksToBounds = true
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.layer?.addSublayer(imageLayer)

        imageLayer.contents = image
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.cornerRadius = 10
        imageLayer.masksToBounds = true
        imageLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .white.withAlphaComponent(0.76)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(imageContainerView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            imageContainerView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            imageContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            imageContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            imageContainerView.heightAnchor.constraint(equalToConstant: 88),

            titleLabel.topAnchor.constraint(equalTo: imageContainerView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func layout() {
        super.layout()
        imageLayer.frame = imageContainerView.bounds
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

private final class ScreenshotPreviewWindow: NSWindow {
    private let previewView: ScreenshotPreviewView

    init(image: CGImage, title: String, subtitle: String, frame: NSRect) {
        self.previewView = ScreenshotPreviewView(image: image, title: title, subtitle: subtitle)
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = previewView
        setFrame(frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func onClick(_ handler: @escaping () -> Void) {
        previewView.onClick = handler
    }

    static func frame(on screenFrame: CGRect) -> NSRect {
        let size = CGSize(width: 200, height: 150)
        return NSRect(
            x: screenFrame.maxX - size.width - 56,
            y: screenFrame.minY + 112,
            width: size.width,
            height: size.height
        )
    }
}

private final class RecordingLivePreviewView: NSView {
    enum ResizeRegion {
        case topLeft
        case top
        case topRight
        case right
        case bottomRight
        case bottom
        case bottomLeft
        case left

        var cursor: NSCursor {
            switch self {
            case .left, .right:
                return .resizeLeftRight
            case .top, .bottom:
                return .resizeUpDown
            case .topLeft, .topRight, .bottomLeft, .bottomRight:
                return .crosshair
            }
        }
    }

    private static let resizeHitInset: CGFloat = 12

    private let titleLabel = NSTextField(labelWithString: AppStrings.text(.livePreview))
    private let imageContainerView = NSView()
    private let imageLayer = CALayer()
    private let pinButton = NSButton()
    private var isPinned = false
    private var trackingArea: NSTrackingArea?

    var onTogglePin: (() -> Void)?
    var onResizeStart: ((ResizeRegion, CGPoint) -> Void)?
    var onResizeChange: ((CGPoint) -> Void)?
    var onResizeEnd: ((CGPoint) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.86).cgColor
        layer?.cornerRadius = 16
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .white.withAlphaComponent(0.92)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        pinButton.bezelStyle = .texturedRounded
        pinButton.isBordered = false
        pinButton.contentTintColor = .white
        pinButton.target = self
        pinButton.action = #selector(handlePinButton)
        pinButton.translatesAutoresizingMaskIntoConstraints = false

        imageContainerView.wantsLayer = true
        imageContainerView.layer?.cornerRadius = 10
        imageContainerView.layer?.masksToBounds = true
        imageContainerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.22).cgColor
        imageContainerView.translatesAutoresizingMaskIntoConstraints = false
        imageContainerView.layer?.addSublayer(imageLayer)

        imageLayer.contentsGravity = .resizeAspect
        imageLayer.masksToBounds = true
        imageLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0

        addSubview(titleLabel)
        addSubview(pinButton)
        addSubview(imageContainerView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pinButton.leadingAnchor, constant: -8),

            pinButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            pinButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            pinButton.widthAnchor.constraint(equalToConstant: 20),
            pinButton.heightAnchor.constraint(equalToConstant: 20),

            imageContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            imageContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            imageContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            imageContainerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])

        updateLocalizedStrings(language: AppLanguage.resolved())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        imageLayer.frame = imageContainerView.bounds
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        updateCursor(for: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let region = resizeRegion(at: point), !isPinned {
            window?.acceptsMouseMovedEvents = true
            onResizeStart?(region, window?.convertPoint(toScreen: event.locationInWindow) ?? .zero)
            return
        }
        guard !isPinned else { return }
        window?.performDrag(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard !isPinned, let window else { return }
        onResizeChange?(window.convertPoint(toScreen: event.locationInWindow))
    }

    override func mouseUp(with event: NSEvent) {
        guard !isPinned, let window else { return }
        onResizeEnd?(window.convertPoint(toScreen: event.locationInWindow))
    }

    func update(image: CGImage) {
        imageLayer.contents = image
        if let scale = window?.screen?.backingScaleFactor {
            imageLayer.contentsScale = scale
        }
    }

    func setPinned(_ pinned: Bool) {
        isPinned = pinned
        let symbolName = pinned ? "pin.fill" : "pin"
        let language = AppLanguage.resolved()
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: AppStrings.text(.pinPreview, in: language)) {
            pinButton.image = image
            pinButton.title = ""
        } else {
            pinButton.image = nil
            pinButton.title = pinned ? AppStrings.text(.unpin, in: language) : AppStrings.text(.pin, in: language)
        }
        pinButton.toolTip = pinned ? AppStrings.text(.unpinLivePreview, in: language) : AppStrings.text(.pinLivePreview, in: language)
    }

    func updateLocalizedStrings(language: AppLanguage) {
        titleLabel.stringValue = AppStrings.text(.livePreview, in: language)
        setPinned(isPinned)
    }

    @objc
    private func handlePinButton() {
        onTogglePin?()
    }

    private func resizeRegion(at point: CGPoint) -> ResizeRegion? {
        let left = point.x <= Self.resizeHitInset
        let right = point.x >= bounds.maxX - Self.resizeHitInset
        let bottom = point.y <= Self.resizeHitInset
        let top = point.y >= bounds.maxY - Self.resizeHitInset

        if top && left { return .topLeft }
        if top && right { return .topRight }
        if bottom && left { return .bottomLeft }
        if bottom && right { return .bottomRight }
        if left { return .left }
        if right { return .right }
        if top { return .top }
        if bottom { return .bottom }
        return nil
    }

    private func updateCursor(for point: CGPoint) {
        guard !isPinned, let region = resizeRegion(at: point) else {
            NSCursor.arrow.set()
            return
        }
        region.cursor.set()
    }
}

private final class RecordingLivePreviewWindow: NSWindow {
    private static let minimumSize = CGSize(width: 240, height: 135)

    private let previewView = RecordingLivePreviewView(frame: .zero)
    private let aspectRatioValue: CGFloat
    private var resizeRegion: RecordingLivePreviewView.ResizeRegion?
    private var resizeStartPoint: CGPoint?
    private var resizeStartFrame: CGRect = .zero
    private var observers: [Any] = []
    private var suppressFrameChangeCallback = false

    var onPinToggle: (() -> Void)?
    var onFrameChanged: ((CGRect) -> Void)?

    init(frame: NSRect, aspectRatio: CGFloat, pinned: Bool) {
        self.aspectRatioValue = max(0.1, aspectRatio)
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = !pinned
        acceptsMouseMovedEvents = true
        contentAspectRatio = NSSize(width: aspectRatioValue * 100, height: 100)
        contentMinSize = Self.minimumSize
        contentView = previewView
        setFrame(frame, display: false)
        setPinned(pinned)
        configureCallbacks()
        installObservers()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func update(image: CGImage) {
        previewView.update(image: image)
    }

    func setPinned(_ pinned: Bool) {
        previewView.setPinned(pinned)
        isMovableByWindowBackground = !pinned
        level = pinned ? .statusBar : .floating
    }

    func updateLocalizedStrings(language: AppLanguage) {
        previewView.updateLocalizedStrings(language: language)
    }

    func applyPersistedFrame(_ frame: CGRect) {
        suppressFrameChangeCallback = true
        setFrame(frame, display: true)
        suppressFrameChangeCallback = false
    }

    private func configureCallbacks() {
        previewView.onTogglePin = { [weak self] in
            self?.onPinToggle?()
        }
        previewView.onResizeStart = { [weak self] region, point in
            self?.resizeRegion = region
            self?.resizeStartPoint = point
            self?.resizeStartFrame = self?.frame ?? .zero
        }
        previewView.onResizeChange = { [weak self] point in
            self?.resize(to: point)
        }
        previewView.onResizeEnd = { [weak self] point in
            self?.resize(to: point)
            self?.resizeRegion = nil
            self?.resizeStartPoint = nil
            self?.resizeStartFrame = .zero
            self?.notifyFrameChanged()
        }
    }

    private func installObservers() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSWindow.didMoveNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.notifyFrameChanged()
        })
        observers.append(center.addObserver(
            forName: NSWindow.didResizeNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            self?.notifyFrameChanged()
        })
    }

    private func resize(to screenPoint: CGPoint) {
        guard let resizeStartPoint else { return }
        guard let resizeRegion else { return }
        guard resizeStartFrame != .zero else { return }

        let deltaX = screenPoint.x - resizeStartPoint.x
        let deltaY = screenPoint.y - resizeStartPoint.y
        let widthFromPositiveX = resizeStartFrame.width + deltaX
        let widthFromNegativeX = resizeStartFrame.width - deltaX
        let widthFromPositiveY = resizeStartFrame.width + (deltaY * aspectRatioValue)
        let widthFromNegativeY = resizeStartFrame.width - (deltaY * aspectRatioValue)
        let proposedWidth: CGFloat
        let anchorMaxX: CGFloat
        let anchorMaxY: CGFloat

        switch resizeRegion {
        case .right:
            proposedWidth = widthFromPositiveX
            anchorMaxX = resizeStartFrame.minX
            anchorMaxY = resizeStartFrame.maxY
        case .left:
            proposedWidth = widthFromNegativeX
            anchorMaxX = resizeStartFrame.maxX
            anchorMaxY = resizeStartFrame.maxY
        case .top:
            proposedWidth = widthFromPositiveY
            anchorMaxX = resizeStartFrame.minX
            anchorMaxY = resizeStartFrame.minY
        case .bottom:
            proposedWidth = widthFromNegativeY
            anchorMaxX = resizeStartFrame.minX
            anchorMaxY = resizeStartFrame.maxY
        case .topRight:
            proposedWidth = preferredCornerWidth(horizontal: widthFromPositiveX, vertical: widthFromPositiveY)
            anchorMaxX = resizeStartFrame.minX
            anchorMaxY = resizeStartFrame.minY
        case .topLeft:
            proposedWidth = preferredCornerWidth(horizontal: widthFromNegativeX, vertical: widthFromPositiveY)
            anchorMaxX = resizeStartFrame.maxX
            anchorMaxY = resizeStartFrame.minY
        case .bottomRight:
            proposedWidth = preferredCornerWidth(horizontal: widthFromPositiveX, vertical: widthFromNegativeY)
            anchorMaxX = resizeStartFrame.minX
            anchorMaxY = resizeStartFrame.maxY
        case .bottomLeft:
            proposedWidth = preferredCornerWidth(horizontal: widthFromNegativeX, vertical: widthFromNegativeY)
            anchorMaxX = resizeStartFrame.maxX
            anchorMaxY = resizeStartFrame.maxY
        }

        let width = max(Self.minimumSize.width, proposedWidth)
        let height = max(Self.minimumSize.height, width / aspectRatioValue)
        let originX: CGFloat
        let originY: CGFloat

        switch resizeRegion {
        case .left, .topLeft, .bottomLeft:
            originX = anchorMaxX - width
        default:
            originX = anchorMaxX
        }

        switch resizeRegion {
        case .top, .topLeft, .topRight:
            originY = anchorMaxY
        default:
            originY = anchorMaxY - height
        }

        var newFrame = CGRect(x: originX, y: originY, width: width, height: height)
        if let currentScreenFrame = screen?.visibleFrame ?? screen?.frame {
            newFrame = RecordingLivePreviewWindow.constrain(frame: newFrame, to: currentScreenFrame)
        }
        newFrame = newFrame.integral

        suppressFrameChangeCallback = true
        setFrame(newFrame, display: true)
        suppressFrameChangeCallback = false
    }

    private func preferredCornerWidth(horizontal: CGFloat, vertical: CGFloat) -> CGFloat {
        let horizontalDelta = abs(horizontal - resizeStartFrame.width)
        let verticalDelta = abs(vertical - resizeStartFrame.width)
        return horizontalDelta >= verticalDelta ? horizontal : vertical
    }

    private static func constrain(frame: CGRect, to screenFrame: CGRect) -> CGRect {
        var adjusted = frame
        if adjusted.maxX > screenFrame.maxX {
            adjusted.origin.x = screenFrame.maxX - adjusted.width
        }
        if adjusted.minX < screenFrame.minX {
            adjusted.origin.x = screenFrame.minX
        }
        if adjusted.maxY > screenFrame.maxY {
            adjusted.origin.y = screenFrame.maxY - adjusted.height
        }
        if adjusted.minY < screenFrame.minY {
            adjusted.origin.y = screenFrame.minY
        }
        return adjusted
    }

    private func notifyFrameChanged() {
        guard !suppressFrameChangeCallback else { return }
        onFrameChanged?(frame)
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
    private static let livePreviewDuringRecordingKey = "ScreenSeal_plus.livePreviewDuringRecording"
    private static let livePreviewPinnedKey = "ScreenSeal_plus.livePreviewPinned"
    private static let livePreviewFrameKey = "ScreenSeal_plus.livePreviewFrame"
    private static let cursorHighlightColorKey = "ScreenSeal_plus.cursorHighlightColor"
    private static let clickRingColorKey = "ScreenSeal_plus.clickRingColor"
    private static let screenshotOpenActionKey = "ScreenSeal_plus.screenshotOpenAction"
    private static let screenshotScaleOptionKey = "ScreenSeal_plus.screenshotScaleOption"
    private static let recordingOpenActionKey = "ScreenSeal_plus.recordingOpenAction"
    private static let recordingZoomScaleKey = "ScreenSeal_plus.recordingZoomScale"
    private static let previewBundleIdentifier = "com.apple.Preview"
    private static let quickTimeBundleIdentifier = "com.apple.QuickTimePlayerX"
    private static let screenshotPreviewDurationNanoseconds: UInt64 = 10_000_000_000
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
    @Published var captureMode: CaptureMode = .record {
        didSet {
            clearStatusForModeChange()
        }
    }
    @Published var appLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: AppLanguage.userDefaultsKey)
            recordingLivePreviewWindow?.updateLocalizedStrings(language: appLanguage)
            windows.forEach { $0.updateLocalizedStrings(language: appLanguage) }
        }
    }
    @Published var recordingState: RecordingState = .idle
    @Published private(set) var screenshotStatusMessage: String?
    @Published private(set) var screenshotStatusIsFailure = false
    @Published private(set) var isTakingScreenshot = false
    @Published var screenshotCaptureType: ScreenshotCaptureType = .single
    @Published var screenshotScaleOption: ScreenshotScaleOption {
        didSet { UserDefaults.standard.set(screenshotScaleOption.rawValue, forKey: Self.screenshotScaleOptionKey) }
    }
    @Published private(set) var isScrollCaptureRunning = false
    @Published var screenshotOpenAction: ScreenshotOpenAction {
        didSet { UserDefaults.standard.set(screenshotOpenAction.rawValue, forKey: Self.screenshotOpenActionKey) }
    }
    @Published var recordingOpenAction: RecordingOpenAction {
        didSet { UserDefaults.standard.set(recordingOpenAction.rawValue, forKey: Self.recordingOpenActionKey) }
    }
    @Published var recordingZoomScale: RecordingZoomScale {
        didSet { UserDefaults.standard.set(recordingZoomScale.rawValue, forKey: Self.recordingZoomScaleKey) }
    }
    @Published var recordingTarget: RecordingTarget = .display
    @Published private(set) var selectedWindowDisplayName: String?
    @Published private(set) var selectedWindowDisplayID: CGDirectDisplayID?
    @Published var followCursorRecording = false {
        didSet {
            guard followCursorRecording else { return }
            if recordingTarget != .display {
                selectDisplayRecordingTarget()
            }
        }
    }
    @Published var livePreviewDuringRecording: Bool {
        didSet {
            UserDefaults.standard.set(livePreviewDuringRecording, forKey: Self.livePreviewDuringRecordingKey)
            DispatchQueue.main.async { [weak self] in
                self?.syncRecordingLivePreviewVisibility()
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
    private var appActivationObserver: Any?
    private let colorPanelCoordinator = ColorPanelCoordinator()
    private let regionSelectionCoordinator = RegionSelectionCoordinator()
    private let windowSelectionPickerCoordinator = WindowSelectionPickerCoordinator()
    private var countdownTask: Task<Void, Never>?
    private var countdownOverlayWindow: CountdownOverlayWindow?
    private var regionRecordingOverlayWindow: RegionRecordingOverlayWindow?
    private var screenshotPreviewDismissTask: Task<Void, Never>?
    private var screenshotPreviewWindow: ScreenshotPreviewWindow?
    private var scrollCaptureTask: Task<Void, Never>?
    private var recordingLivePreviewWindow: RecordingLivePreviewWindow?
    private var lastResolvedRecordingTarget: ResolvedRecordingTarget?
    private var lastExternalFrontmostApp: NSRunningApplication?
    private var livePreviewPinned: Bool
    private var livePreviewSavedFrame: CGRect?
    private var scrollCaptureStopRequested = false
    private var temporaryScrollPreviewURLs: Set<URL> = []

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

    var isCaptureModeSelectionDisabled: Bool {
        isRecordingPreparationActive || isTakingScreenshot
    }

    var recordingOptionsDisabled: Bool {
        isRecordingPreparationActive || isTakingScreenshot || captureMode == .screenshot
    }

    var livePreviewToggleDisabled: Bool {
        if captureMode == .screenshot || isTakingScreenshot || isSelectingRecordingRegion {
            return true
        }
        switch recordingState {
        case .starting, .stopping:
            return true
        case .idle, .countdown, .recording, .failed:
            return false
        }
    }

    var shouldDisableNonDisplayTargets: Bool {
        captureMode == .record && followCursorRecording
    }

    var isFullDisplayTargetDisabled: Bool {
        isCaptureModeSelectionDisabled
            || (captureMode == .screenshot && screenshotCaptureType == .scroll)
    }

    var isScreenshotActionDisabled: Bool {
        guard captureMode == .screenshot else { return false }
        if isScrollCaptureRunning { return false }
        if isTakingScreenshot { return true }
        if screenshotCaptureType == .scroll, recordingTarget == .display { return true }
        return false
    }

    var screenshotActionTitle: String {
        isScrollCaptureRunning
            ? AppStrings.text(.stopScrollCapture, in: appLanguage)
            : AppStrings.text(.takeScreenshot, in: appLanguage)
    }

    var availableScreenshotScaleOptions: [ScreenshotScaleOption] {
        var options: [ScreenshotScaleOption] = [.original]
        if isCurrentScreenshotTargetRetina {
            options.append(.x2)
        }
        options.append(contentsOf: [.x1, .x0_5])
        return options
    }

    private var effectiveScreenshotScaleOption: ScreenshotScaleOption {
        availableScreenshotScaleOptions.contains(screenshotScaleOption) ? screenshotScaleOption : .original
    }

    var statusText: String? {
        switch captureMode {
        case .record:
            return recordingState.statusText(in: appLanguage) ?? screenshotStatusMessage
        case .screenshot:
            return screenshotStatusMessage ?? recordingState.statusText(in: appLanguage)
        }
    }

    var isStatusFailure: Bool {
        switch captureMode {
        case .record:
            return recordingState.statusText(in: appLanguage) != nil ? recordingState.isFailure : screenshotStatusIsFailure
        case .screenshot:
            return screenshotStatusMessage != nil ? screenshotStatusIsFailure : recordingState.isFailure
        }
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
        self.appLanguage = AppLanguage.resolved()
        self.screenshotScaleOption = ScreenshotScaleOption(
            rawValue: UserDefaults.standard.string(forKey: Self.screenshotScaleOptionKey) ?? ""
        ) ?? .original
        self.screenshotOpenAction = ScreenshotOpenAction(
            rawValue: UserDefaults.standard.string(forKey: Self.screenshotOpenActionKey) ?? ""
        ) ?? .preview
        self.recordingOpenAction = RecordingOpenAction(
            rawValue: UserDefaults.standard.string(forKey: Self.recordingOpenActionKey) ?? ""
        ) ?? .quickTime
        self.recordingZoomScale = RecordingZoomScale(
            rawValue: UserDefaults.standard.double(forKey: Self.recordingZoomScaleKey)
        ) ?? .x1_8
        self.livePreviewDuringRecording = UserDefaults.standard.bool(forKey: Self.livePreviewDuringRecordingKey)
        self.livePreviewPinned = UserDefaults.standard.bool(forKey: Self.livePreviewPinnedKey)
        self.livePreviewSavedFrame = Self.loadRect(forKey: Self.livePreviewFrameKey)
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
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
                return
            }
            self.lastExternalFrontmostApp = app
        }
        windowSelectionPickerCoordinator.windowManager = self

    }

    deinit {
        countdownTask?.cancel()
        scrollCaptureTask?.cancel()
        screenshotPreviewDismissTask?.cancel()
        dismissCountdownOverlay()
        dismissRegionRecordingOverlay()
        dismissScreenshotPreview()
        dismissRecordingLivePreview()
        cleanupTemporaryScrollPreviewArtifacts()
        regionSelectionCoordinator.dismiss()
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = appActivationObserver {
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

    func performPrimaryCaptureAction() {
        switch captureMode {
        case .record:
            if isCountdownActive {
                cancelRecordingCountdown()
            } else if canStopRecording {
                stopRecording()
            } else {
                startRecording()
            }
        case .screenshot:
            switch screenshotCaptureType {
            case .single:
                takeScreenshot()
            case .scroll:
                if isScrollCaptureRunning {
                    stopScrollCapture()
                } else {
                    startScrollCapture()
                }
            }
        }
    }

    func startRecording() {
        if isRecordingPreparationActive { return }
        clearScreenshotStatus()

        guard #available(macOS 15.0, *) else {
            recordingState = .failed(message: AppStrings.recordingFeatureRequiresMacOS15(in: appLanguage))
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let target = try await self.resolveRecordingTarget()
                await MainActor.run {
                    self.lastResolvedRecordingTarget = target
                    self.beginRecordingCountdown(target: target)
                }
            } catch {
                await MainActor.run {
                    self.recordingState = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    func takeScreenshot() {
        if isRecordingPreparationActive || isTakingScreenshot { return }

        clearScreenshotStatus()
        isTakingScreenshot = true
        screenshotStatusMessage = AppStrings.screenshotSaving(in: appLanguage)

        Task { [weak self] in
            guard let self else { return }
            do {
                let target = try await self.resolveRecordingTarget()
                let service = ScreenshotService()
                let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                let filterContext = await MainActor.run {
                    (
                        excludedApplications: self.excludedCurrentApplications(from: shareableContent),
                        exceptingWindows: self.includedOverlayShareableWindows(from: shareableContent),
                        includedOverlayWindowIDs: self.includedRecordingOverlayWindowIDs()
                    )
                }
                let result = try await service.capture(
                    target: target,
                    scaleOption: self.effectiveScreenshotScaleOption,
                    excludedApplications: filterContext.excludedApplications,
                    exceptingWindows: filterContext.exceptingWindows,
                    overlayWindowIDs: Array(filterContext.includedOverlayWindowIDs)
                )
                await MainActor.run {
                    self.isTakingScreenshot = false
                    self.screenshotStatusIsFailure = false
                    self.screenshotStatusMessage = AppStrings.screenshotSaved(
                        filename: result.outputURL.lastPathComponent,
                        in: self.appLanguage
                    )
                    self.showCapturePreview(
                        image: result.image,
                        outputURL: result.outputURL,
                        target: target,
                        title: AppStrings.text(.screenshotSavedTitle, in: self.appLanguage),
                        subtitle: AppStrings.clickToOpenIn(
                            self.screenshotOpenAction.localizedTitle(in: self.appLanguage),
                            in: self.appLanguage
                        ),
                        opener: self.openScreenshot
                    )
                    if case .region = self.recordingTarget {
                        self.selectDisplayRecordingTarget()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isTakingScreenshot = false
                    self.screenshotStatusIsFailure = true
                    self.screenshotStatusMessage = error.localizedDescription
                }
            }
        }
    }

    func stopScrollCapture() {
        guard isScrollCaptureRunning else { return }
        scrollCaptureStopRequested = true
        screenshotStatusIsFailure = false
        screenshotStatusMessage = AppStrings.scrollCaptureStopping(in: appLanguage)
    }

    private func startScrollCapture() {
        if isRecordingPreparationActive || isTakingScreenshot { return }
        guard recordingTarget != .display else {
            screenshotStatusIsFailure = true
            screenshotStatusMessage = AppStrings.scrollCaptureInvalidTarget(in: appLanguage)
            return
        }

        clearScreenshotStatus()
        dismissScreenshotPreview()
        isTakingScreenshot = true
        isScrollCaptureRunning = true
        scrollCaptureStopRequested = false
        screenshotStatusMessage = AppStrings.scrollCapturePreparing(in: appLanguage)

        scrollCaptureTask = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isTakingScreenshot = false
                    self.isScrollCaptureRunning = false
                    self.scrollCaptureTask = nil
                }
            }

            do {
                let target = try await self.resolveRecordingTarget()
                guard case .display = target else {
                    let service = ScrollCaptureService()
                    let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                    let filterContext = await MainActor.run {
                        (
                            excludedApplications: self.excludedCurrentApplications(from: shareableContent),
                            exceptingWindows: self.includedOverlayShareableWindows(from: shareableContent),
                            includedOverlayWindowIDs: self.includedRecordingOverlayWindowIDs()
                        )
                    }
                    let result = try await service.capture(
                        target: target,
                        scaleOption: self.effectiveScreenshotScaleOption,
                        excludedApplications: filterContext.excludedApplications,
                        exceptingWindows: filterContext.exceptingWindows,
                        overlayWindowIDs: Array(filterContext.includedOverlayWindowIDs),
                        stopRequested: { [weak self] in
                            self?.scrollCaptureStopRequested ?? true
                        }
                    )
                    await MainActor.run {
                        self.scrollCaptureStopRequested = false
                        self.screenshotStatusIsFailure = false
                        self.temporaryScrollPreviewURLs.insert(result.previewImageURL)
                        self.screenshotStatusMessage = AppStrings.scrollCaptureSaved(
                            filename: result.archiveURL.lastPathComponent,
                            in: self.appLanguage
                        )
                        if let previewImage = self.scrollCapturePreviewImage(for: result.previewImageURL) {
                            self.showCapturePreview(
                                image: previewImage,
                                target: target,
                                title: AppStrings.text(.scrollCaptureSavedTitle, in: self.appLanguage),
                                subtitle: AppStrings.clickToOpenIn(
                                    self.screenshotOpenAction.localizedTitle(in: self.appLanguage),
                                    in: self.appLanguage
                                )
                            ) { [weak self] in
                                guard let self else { return }
                                switch self.screenshotOpenAction {
                                case .preview:
                                    self.openScreenshot(at: result.previewImageURL)
                                case .finder:
                                    self.openScreenshot(at: result.archiveURL)
                                }
                            }
                        }
                    }
                    return
                }
                await MainActor.run {
                    self.screenshotStatusIsFailure = true
                    self.screenshotStatusMessage = AppStrings.scrollCaptureInvalidTarget(in: self.appLanguage)
                }
            } catch {
                await MainActor.run {
                    self.scrollCaptureStopRequested = false
                    self.screenshotStatusIsFailure = true
                    self.screenshotStatusMessage = error.localizedDescription
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
                let outputURL = try await service.stop()
                let previewImage = try? await self.recordingPreviewImage(for: outputURL)
                await MainActor.run {
                    SCContentSharingPicker.shared.isActive = false
                    self.dismissRecordingLivePreview()
                    self.recordingServiceRef = nil
                    self.recordingState = .idle
                    self.recordingTarget = .display
                    self.dismissRegionRecordingOverlay()
                    self.removeAllWindows()
                    if let previewImage,
                       let target = self.lastResolvedRecordingTarget {
                        self.showCapturePreview(
                            image: previewImage,
                            outputURL: outputURL,
                            target: target,
                            title: AppStrings.text(.recordingSavedTitle, in: self.appLanguage),
                            subtitle: AppStrings.clickToOpenIn(
                                self.recordingOpenAction.localizedTitle(in: self.appLanguage),
                                in: self.appLanguage
                            ),
                            opener: self.openRecording
                        )
                    }
                    self.lastResolvedRecordingTarget = nil
                }
            } catch {
                do {
                    let outputURL = try await service.stop()
                    let previewImage = try? await self.recordingPreviewImage(for: outputURL)
                    await MainActor.run {
                        SCContentSharingPicker.shared.isActive = false
                        self.dismissRecordingLivePreview()
                        self.recordingServiceRef = nil
                        self.recordingState = .idle
                        self.recordingTarget = .display
                        self.dismissRegionRecordingOverlay()
                        self.removeAllWindows()
                        if let previewImage,
                           let target = self.lastResolvedRecordingTarget {
                            self.showCapturePreview(
                                image: previewImage,
                                outputURL: outputURL,
                                target: target,
                                title: AppStrings.text(.recordingSavedTitle, in: self.appLanguage),
                                subtitle: AppStrings.clickToOpenIn(
                                    self.recordingOpenAction.localizedTitle(in: self.appLanguage),
                                    in: self.appLanguage
                                ),
                                opener: self.openRecording
                            )
                        }
                        self.lastResolvedRecordingTarget = nil
                    }
                } catch {
                    await MainActor.run {
                        SCContentSharingPicker.shared.isActive = false
                        self.dismissRecordingLivePreview()
                        self.recordingServiceRef = nil
                        self.recordingState = .failed(message: AppStrings.recordingStopFailed(in: self.appLanguage))
                        self.recordingTarget = .display
                        self.dismissRegionRecordingOverlay()
                        self.lastResolvedRecordingTarget = nil
                    }
                }
            }
        }
    }

    func cancelRecordingCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        dismissCountdownOverlay()
        dismissRecordingLivePreview()
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
        selectedWindowDisplayID = nil
        dismissRegionRecordingOverlay()
    }

    func beginSystemWindowSelection() {
        guard !isRecordingPreparationActive, !isTakingScreenshot, !shouldDisableNonDisplayTargets else { return }
        setOverlayWindowsInteractive(false)
        let excludedWindowIDs = windows.map { Int($0.windowNumber) }
        windowSelectionPickerCoordinator.presentPicker(
            excludedBundleIDs: [Bundle.main.bundleIdentifier ?? ""],
            excludedWindowIDs: excludedWindowIDs
        )
    }

    func applySystemWindowSelection(_ selection: (windowID: CGWindowID, displayID: CGDirectDisplayID?, displayName: String)) {
        recordingTarget = .window(windowID: selection.windowID)
        selectedWindowDisplayName = selection.displayName
        selectedWindowDisplayID = selection.displayID
        dismissRegionRecordingOverlay()
    }

    func beginRecordingRegionSelection() {
        guard !isRecordingPreparationActive, !isTakingScreenshot, !shouldDisableNonDisplayTargets else { return }

        isSelectingRecordingRegion = true
        dismissRegionRecordingOverlay()
        regionSelectionCoordinator.present { [weak self] selection in
            self?.isSelectingRecordingRegion = false
            self?.recordingTarget = .region(selection)
            self?.selectedWindowDisplayName = nil
            self?.selectedWindowDisplayID = nil
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
            title: AppStrings.text(.cursorHighlightColor, in: appLanguage).replacingOccurrences(of: "...", with: ""),
            color: cursorHighlightColor
        ) { [weak self] color in
            self?.cursorHighlightColor = color
        }
    }

    func openClickRingColorPanel() {
        colorPanelCoordinator.present(
            title: AppStrings.text(.clickRingColor, in: appLanguage).replacingOccurrences(of: "...", with: ""),
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
        if livePreviewDuringRecording {
            _ = prepareRecordingLivePreviewWindow(for: target)
        } else {
            dismissRecordingLivePreview()
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
                self.restoreLastExternalFrontmostApp()
                self.startRecordingNow(target: target)
            }
        }
    }

    @MainActor
    @available(macOS 15.0, *)
    private func startRecordingNow(target: ResolvedRecordingTarget) {
        let service = (recordingServiceRef as? RecordingService)
            ?? RecordingService(
                followCursorCameraEnabled: followCursorRecording,
                cursorHighlightEnabled: cursorHighlightEnabled,
                clickRingEnabled: clickRingEnabled,
                livePreviewEnabled: false,
                zoomScale: recordingZoomScale.rawValue,
                cursorHighlightColor: cursorHighlightColor,
                clickRingColor: clickRingColor
            )
        service.onStateChange = { [weak self] state in
            DispatchQueue.main.async {
                self?.recordingState = state

                if case .idle = state {
                    self?.dismissRecordingLivePreview()
                    self?.recordingServiceRef = nil
                } else if case .failed = state {
                    self?.dismissRecordingLivePreview()
                    self?.recordingServiceRef = nil
                }
            }
        }
        recordingServiceRef = service
        syncRecordingLivePreviewVisibility()
        Task {
            do {
                let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                let recordingFilterContext = await MainActor.run {
                    return (
                        excludedApplications: self.excludedCurrentApplications(from: shareableContent),
                        exceptingWindows: self.includedOverlayShareableWindows(from: shareableContent),
                        includedOverlayWindowIDs: Array(self.includedRecordingOverlayWindowIDs())
                    )
                }
                _ = try await service.start(
                    target: target,
                    excludedApplications: recordingFilterContext.excludedApplications,
                    exceptingWindows: recordingFilterContext.exceptingWindows,
                    includedOverlayWindowIDs: recordingFilterContext.includedOverlayWindowIDs
                )
            } catch {
                await MainActor.run {
                    self.dismissRecordingLivePreview()
                    self.recordingServiceRef = nil
                    self.recordingState = .failed(message: AppStrings.recordingStartFailed(in: self.appLanguage))
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

    private func restoreLastExternalFrontmostApp() {
        guard let app = lastExternalFrontmostApp,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        guard !app.isTerminated,
              let runningApp = NSRunningApplication(processIdentifier: app.processIdentifier),
              runningApp.activationPolicy != .prohibited else {
            return
        }
        _ = runningApp.activate(options: [.activateAllWindows])
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
            self.selectedWindowDisplayID = nil
        }
        regionRecordingOverlayWindow = window
        window.orderFrontRegardless()
    }

    private func dismissRegionRecordingOverlay() {
        regionRecordingOverlayWindow?.orderOut(nil)
        regionRecordingOverlayWindow?.close()
        regionRecordingOverlayWindow = nil
    }

    private func prepareRecordingLivePreviewWindow(for target: ResolvedRecordingTarget) -> RecordingLivePreviewWindow? {
        guard let screenFrame = previewScreenFrame(for: target) else { return nil }

        let aspectRatio = livePreviewAspectRatio(for: target)
        let frame = resolvedLivePreviewFrame(on: screenFrame, aspectRatio: aspectRatio)

        if let window = recordingLivePreviewWindow {
            window.setPinned(livePreviewPinned)
            window.applyPersistedFrame(frame)
            window.orderFrontRegardless()
            return window
        }

        let window = RecordingLivePreviewWindow(frame: frame, aspectRatio: aspectRatio, pinned: livePreviewPinned)
        window.onPinToggle = { [weak self] in
            guard let self else { return }
            self.livePreviewPinned.toggle()
            UserDefaults.standard.set(self.livePreviewPinned, forKey: Self.livePreviewPinnedKey)
            self.recordingLivePreviewWindow?.setPinned(self.livePreviewPinned)
            self.recordingLivePreviewWindow?.orderFrontRegardless()
        }
        window.onFrameChanged = { [weak self] frame in
            self?.persistLivePreviewFrame(frame)
        }
        recordingLivePreviewWindow = window
        window.orderFrontRegardless()
        return window
    }

    private func dismissRecordingLivePreview() {
        recordingLivePreviewWindow?.orderOut(nil)
        recordingLivePreviewWindow?.close()
        recordingLivePreviewWindow = nil
    }

    @MainActor
    private func syncRecordingLivePreviewVisibility() {
        let shouldShowWindow: Bool
        switch recordingState {
        case .countdown, .recording:
            shouldShowWindow = livePreviewDuringRecording && lastResolvedRecordingTarget != nil
        case .starting:
            shouldShowWindow = livePreviewDuringRecording && lastResolvedRecordingTarget != nil
        case .idle, .stopping, .failed:
            shouldShowWindow = false
        }

        if shouldShowWindow, let target = lastResolvedRecordingTarget {
            _ = prepareRecordingLivePreviewWindow(for: target)
        } else {
            dismissRecordingLivePreview()
        }

        if #available(macOS 15.0, *), let service = recordingServiceRef as? RecordingService {
            service.setLivePreviewEnabled(
                shouldShowWindow,
                onPreviewFrame: shouldShowWindow ? livePreviewFrameHandler() : nil
            )
        }
    }

    private func livePreviewFrameHandler() -> ((CGImage) -> Void) {
        { [weak self] image in
            self?.recordingLivePreviewWindow?.update(image: image)
        }
    }

    private func excludedCurrentApplications(from content: SCShareableContent) -> [SCRunningApplication] {
        let selfBundleID = Bundle.main.bundleIdentifier ?? ""
        return content.applications.filter { $0.bundleIdentifier == selfBundleID }
    }

    private func includedRecordingOverlayWindowIDs() -> Set<CGWindowID> {
        Set(windows.map { CGWindowID($0.windowNumber) })
    }

    private func includedOverlayShareableWindows(from content: SCShareableContent, windowIDs: Set<CGWindowID>? = nil) -> [SCWindow] {
        let targetWindowIDs = windowIDs ?? includedRecordingOverlayWindowIDs()
        return content.windows.filter { targetWindowIDs.contains($0.windowID) }
    }

    private func clearStatusForModeChange() {
        clearScreenshotStatus()
        if captureMode == .record, followCursorRecording, recordingTarget != .display {
            selectDisplayRecordingTarget()
        }
        if case .failed = recordingState {
            recordingState = .idle
        }
    }

    private func clearScreenshotStatus() {
        screenshotStatusMessage = nil
        screenshotStatusIsFailure = false
    }

    private func showCapturePreview(
        image: CGImage,
        outputURL: URL,
        target: ResolvedRecordingTarget,
        title: String,
        subtitle: String,
        opener: @escaping (URL) -> Void
    ) {
        guard let screenFrame = previewScreenFrame(for: target) else {
            return
        }
        screenshotPreviewDismissTask?.cancel()
        dismissScreenshotPreview()

        let window = ScreenshotPreviewWindow(
            image: image,
            title: title,
            subtitle: subtitle,
            frame: ScreenshotPreviewWindow.frame(on: screenFrame)
        )
        window.onClick { [weak self] in
            opener(outputURL)
            self?.dismissScreenshotPreview()
        }
        screenshotPreviewWindow = window
        window.orderFrontRegardless()

        screenshotPreviewDismissTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.screenshotPreviewDurationNanoseconds)
            } catch {
                return
            }
            guard let self else { return }
            await MainActor.run {
                self.dismissScreenshotPreview()
            }
        }
    }

    private func showCapturePreview(
        image: CGImage,
        target: ResolvedRecordingTarget,
        title: String,
        subtitle: String,
        onClick: @escaping () -> Void
    ) {
        guard let screenFrame = previewScreenFrame(for: target) else {
            return
        }
        screenshotPreviewDismissTask?.cancel()
        dismissScreenshotPreview()

        let window = ScreenshotPreviewWindow(
            image: image,
            title: title,
            subtitle: subtitle,
            frame: ScreenshotPreviewWindow.frame(on: screenFrame)
        )
        window.onClick { [weak self] in
            onClick()
            self?.dismissScreenshotPreview()
        }
        screenshotPreviewWindow = window
        window.orderFrontRegardless()

        screenshotPreviewDismissTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.screenshotPreviewDurationNanoseconds)
            } catch {
                return
            }
            guard let self else { return }
            await MainActor.run {
                self.dismissScreenshotPreview()
            }
        }
    }

    @available(macOS 15.0, *)
    private func recordingPreviewImage(for url: URL) async throws -> CGImage {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let captureSeconds: Double
        if durationSeconds.isFinite, durationSeconds > 0 {
            captureSeconds = min(max(durationSeconds * 0.5, 0), max(durationSeconds - 0.1, 0))
        } else {
            captureSeconds = 0
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 360)
        return try generator.copyCGImage(
            at: CMTime(seconds: captureSeconds, preferredTimescale: 600),
            actualTime: nil
        )
    }

    private func dismissScreenshotPreview() {
        screenshotPreviewWindow?.orderOut(nil)
        screenshotPreviewWindow?.close()
        screenshotPreviewWindow = nil
        screenshotPreviewDismissTask?.cancel()
        screenshotPreviewDismissTask = nil
    }

    private func scrollCapturePreviewImage(for url: URL) -> CGImage? {
        guard let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    private var isCurrentScreenshotTargetRetina: Bool {
        currentScreenshotTargetBackingScaleFactor > 1.0
    }

    private var currentScreenshotTargetBackingScaleFactor: CGFloat {
        switch recordingTarget {
        case .display:
            let displayID =
                windows.first(where: { $0.isVisible })?.screen?.displayID
                ?? CGMainDisplayID()
            return NSScreen.screens.first(where: { $0.displayID == displayID })?.backingScaleFactor ?? 1.0
        case .window:
            guard let displayID = selectedWindowDisplayID else { return 1.0 }
            return NSScreen.screens.first(where: { $0.displayID == displayID })?.backingScaleFactor ?? 1.0
        case .region(let selection):
            return NSScreen.screens.first(where: { $0.displayID == selection.displayID })?.backingScaleFactor ?? 1.0
        }
    }

    func cleanupTemporaryScrollPreviewArtifacts() {
        for url in temporaryScrollPreviewURLs {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryScrollPreviewURLs.removeAll()
    }

    private func livePreviewAspectRatio(for target: ResolvedRecordingTarget) -> CGFloat {
        switch target {
        case .display(_, let frame):
            return max(0.1, frame.width / max(frame.height, 1))
        case .window(_, let windowFrame, _, _):
            return max(0.1, windowFrame.width / max(windowFrame.height, 1))
        case .region(let selection):
            return max(0.1, selection.rect.width / max(selection.rect.height, 1))
        }
    }

    private func resolvedLivePreviewFrame(on screenFrame: CGRect, aspectRatio: CGFloat) -> CGRect {
        let defaultFrame = Self.defaultLivePreviewFrame(on: screenFrame, aspectRatio: aspectRatio)
        guard let savedFrame = livePreviewSavedFrame else { return defaultFrame }
        let minimumSize = CGSize(width: 240, height: 135)
        let width = max(minimumSize.width, savedFrame.width)
        let height = max(minimumSize.height, width / max(aspectRatio, 0.1))
        let normalized = CGRect(
            x: savedFrame.origin.x,
            y: savedFrame.maxY - height,
            width: width,
            height: height
        )
        return Self.constrainLivePreviewFrame(normalized, to: screenFrame, defaultFrame: defaultFrame)
    }

    private func persistLivePreviewFrame(_ frame: CGRect) {
        livePreviewSavedFrame = frame.integral
        Self.saveRect(frame.integral, forKey: Self.livePreviewFrameKey)
    }

    private func previewScreenFrame(for target: ResolvedRecordingTarget) -> CGRect? {
        switch target {
        case .display(_, let frame):
            return frame
        case .window(_, _, _, let displayFrame):
            return displayFrame
        case .region(let selection):
            return NSScreen.screens.first(where: { $0.displayID == selection.displayID })?.frame
        }
    }

    private func openScreenshot(at url: URL) {
        switch screenshotOpenAction {
        case .finder:
            NSWorkspace.shared.activateFileViewerSelecting([url])
        case .preview:
            let configuration = NSWorkspace.OpenConfiguration()
            guard let applicationURL = preferredApplicationURL(
                bundleIdentifier: Self.previewBundleIdentifier,
                fallbackOpenURL: url
            ) else {
                logger.error("Failed to resolve Preview app")
                return
            }
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: applicationURL,
                configuration: configuration
            ) { _, error in
                if let error {
                    logger.error("Failed to open screenshot in Preview: \(error.localizedDescription)")
                }
            }
        }
    }

    private func openRecording(at url: URL) {
        switch recordingOpenAction {
        case .finder:
            NSWorkspace.shared.activateFileViewerSelecting([url])
        case .quickTime:
            let configuration = NSWorkspace.OpenConfiguration()
            guard let applicationURL = preferredApplicationURL(
                bundleIdentifier: Self.quickTimeBundleIdentifier,
                fallbackOpenURL: url
            ) else {
                logger.error("Failed to resolve QuickTime app")
                return
            }
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: applicationURL,
                configuration: configuration
            ) { _, error in
                if let error {
                    logger.error("Failed to open recording in QuickTime: \(error.localizedDescription)")
                }
            }
        }
    }

    private func preferredApplicationURL(bundleIdentifier: String, fallbackOpenURL: URL) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            ?? NSWorkspace.shared.urlForApplication(toOpen: fallbackOpenURL)
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

    private static func saveRect(_ rect: CGRect, forKey key: String) {
        UserDefaults.standard.set(NSStringFromRect(rect), forKey: key)
    }

    private static func loadRect(forKey key: String) -> CGRect? {
        guard let text = UserDefaults.standard.string(forKey: key) else { return nil }
        let rect = NSRectFromString(text)
        guard rect.width > 0, rect.height > 0 else { return nil }
        return rect
    }

    private static func defaultLivePreviewFrame(on screenFrame: CGRect, aspectRatio: CGFloat) -> CGRect {
        let width = min(320.0, max(240.0, screenFrame.width * 0.22))
        let height = max(135.0, width / max(aspectRatio, 0.1))
        return CGRect(
            x: screenFrame.maxX - width - 56,
            y: screenFrame.minY + 112,
            width: width,
            height: height
        ).integral
    }

    private static func constrainLivePreviewFrame(_ frame: CGRect, to screenFrame: CGRect, defaultFrame: CGRect) -> CGRect {
        guard !frame.isEmpty else { return defaultFrame }
        let clampedWidth = min(max(frame.width, 240), screenFrame.width)
        let clampedHeight = min(max(frame.height, 135), screenFrame.height)
        var adjusted = CGRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: clampedWidth,
            height: clampedHeight
        )
        if adjusted.maxX > screenFrame.maxX {
            adjusted.origin.x = screenFrame.maxX - adjusted.width
        }
        if adjusted.maxY > screenFrame.maxY {
            adjusted.origin.y = screenFrame.maxY - adjusted.height
        }
        adjusted.origin.x = max(screenFrame.minX, adjusted.origin.x)
        adjusted.origin.y = max(screenFrame.minY, adjusted.origin.y)
        return adjusted.integral
    }

    fileprivate func setOverlayWindowsInteractive(_ interactive: Bool) {
        for window in windows {
            window.ignoresMouseEvents = !interactive
        }
    }

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
            return AppStrings.screenCapturePermissionRequired(in: AppLanguage.resolved())
        }
        return rawMessage
    }
}
