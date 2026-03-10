import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var windowManager: WindowManager

    var body: some View {
        Button(AppStrings.text(.newMosaicWindow, in: windowManager.appLanguage)) {
            windowManager.createWindow()
        }
        .keyboardShortcut("n")

        captureSection

        Divider()

        // Window list
        if !windowManager.windows.isEmpty {
            ForEach(windowManager.windows, id: \.windowIndex) { window in
                Button {
                    windowManager.toggleWindow(window)
                } label: {
                    HStack {
                        Image(systemName: window.isVisible ? "eye.fill" : "eye.slash")
                            .frame(width: 16)
                        Text(window.displayName)
                        Spacer()
                        Text(window.configuration.mosaicType.localizedTitle(in: windowManager.appLanguage))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }

            Divider()

            Button(AppStrings.text(.removeAllWindows, in: windowManager.appLanguage)) {
                windowManager.removeAllWindows()
            }

            Divider()
        }

        // Presets
        if windowManager.windows.isEmpty {
            Divider()
        }

        Button(AppStrings.text(.saveCurrentLayout, in: windowManager.appLanguage)) {
            promptSavePreset()
        }
        .disabled(windowManager.windows.isEmpty)

        let presets = windowManager.presetManager.presets
        if !presets.isEmpty {
            Menu(AppStrings.text(.loadPreset, in: windowManager.appLanguage)) {
                ForEach(presets) { preset in
                    Button(AppStrings.presetSummary(name: preset.name, count: preset.windows.count, in: windowManager.appLanguage)) {
                        windowManager.loadPreset(preset)
                    }
                }
            }

            Menu(AppStrings.text(.deletePreset, in: windowManager.appLanguage)) {
                ForEach(presets) { preset in
                    Button(preset.name, role: .destructive) {
                        windowManager.presetManager.delete(preset)
                        windowManager.objectWillChange.send()
                    }
                }
            }
        }

        if let error = windowManager.captureError {
            Divider()
            Text(error)
                .foregroundColor(.red)
                .font(.caption)

            Button(AppStrings.text(.openScreenRecordingSettings, in: windowManager.appLanguage)) {
                openScreenRecordingSettings()
            }
        }

        if let status = windowManager.statusText {
            Divider()
            Text(status)
                .foregroundColor(windowManager.isStatusFailure ? .red : .secondary)
                .font(.caption)
        }

        Divider()
        Text(appVersionText)
            .foregroundColor(.secondary)
            .font(.caption2)

        Divider()

        Button(AppStrings.text(.quitApp, in: windowManager.appLanguage)) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    @ViewBuilder
    private var captureSection: some View {
        if windowManager.captureMode == .record {
            if windowManager.isCountdownActive {
                Button(AppStrings.text(.cancelCountdown, in: windowManager.appLanguage)) {
                    windowManager.performPrimaryCaptureAction()
                }
                .keyboardShortcut("r")
            } else if windowManager.canStopRecording {
                Button(AppStrings.text(.stopRecording, in: windowManager.appLanguage)) {
                    windowManager.performPrimaryCaptureAction()
                }
                .keyboardShortcut("r")
            } else {
                Button(AppStrings.text(.startRecording, in: windowManager.appLanguage)) {
                    windowManager.performPrimaryCaptureAction()
                }
                .keyboardShortcut("r")
            }
        } else {
            Button(windowManager.screenshotActionTitle) {
                windowManager.performPrimaryCaptureAction()
            }
            .keyboardShortcut("r")
            .disabled(windowManager.isScreenshotActionDisabled)
        }

        Picker(AppStrings.text(.captureMode, in: windowManager.appLanguage), selection: $windowManager.captureMode) {
            Text(CaptureMode.record.localizedTitle(in: windowManager.appLanguage)).tag(CaptureMode.record)
            Text(CaptureMode.screenshot.localizedTitle(in: windowManager.appLanguage)).tag(CaptureMode.screenshot)
        }
        .disabled(windowManager.isCaptureModeSelectionDisabled)

        Picker(AppStrings.text(.language, in: windowManager.appLanguage), selection: $windowManager.appLanguage) {
            ForEach(AppLanguage.allCases, id: \.self) { language in
                Text(AppStrings.languageDisplayName(language)).tag(language)
            }
        }
        .disabled(windowManager.isCaptureModeSelectionDisabled)

        if windowManager.captureMode == .screenshot {
            Picker(AppStrings.text(.screenshotType, in: windowManager.appLanguage), selection: $windowManager.screenshotCaptureType) {
                Text(ScreenshotCaptureType.single.localizedTitle(in: windowManager.appLanguage)).tag(ScreenshotCaptureType.single)
                Text(ScreenshotCaptureType.scroll.localizedTitle(in: windowManager.appLanguage)).tag(ScreenshotCaptureType.scroll)
            }
            .disabled(windowManager.isTakingScreenshot)

            Picker(AppStrings.text(.screenshotScale, in: windowManager.appLanguage), selection: $windowManager.screenshotScaleOption) {
                ForEach(windowManager.availableScreenshotScaleOptions, id: \.self) { option in
                    Text(option.localizedTitle(in: windowManager.appLanguage)).tag(option)
                }
            }
            .disabled(windowManager.isTakingScreenshot)
        }

        Menu(AppStrings.text(.captureTarget, in: windowManager.appLanguage)) {
            Button {
                windowManager.selectDisplayRecordingTarget()
            } label: {
                selectionMenuLabel(AppStrings.text(.fullDisplay, in: windowManager.appLanguage), selected: windowManager.recordingTarget == .display)
            }
            .disabled(windowManager.isFullDisplayTargetDisabled)

            Button(AppStrings.text(.chooseWindow, in: windowManager.appLanguage)) {
                windowManager.beginSystemWindowSelection()
            }
            .disabled(windowManager.isCaptureModeSelectionDisabled || windowManager.shouldDisableNonDisplayTargets)

            if case .window = windowManager.recordingTarget,
               let selectedWindowDisplayName = windowManager.selectedWindowDisplayName {
                Text(AppStrings.selectedWindow(selectedWindowDisplayName, in: windowManager.appLanguage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                windowManager.beginRecordingRegionSelection()
            } label: {
                selectionMenuLabel(AppStrings.text(.selectRegion, in: windowManager.appLanguage), selected: windowManager.isRegionRecordingTarget)
            }
            .disabled(windowManager.isCaptureModeSelectionDisabled || windowManager.shouldDisableNonDisplayTargets)
        }
        .disabled(windowManager.isCaptureModeSelectionDisabled)

        Picker(AppStrings.text(.screenshotClickAction, in: windowManager.appLanguage), selection: $windowManager.screenshotOpenAction) {
            Text(ScreenshotOpenAction.preview.localizedTitle(in: windowManager.appLanguage)).tag(ScreenshotOpenAction.preview)
            Text(ScreenshotOpenAction.finder.localizedTitle(in: windowManager.appLanguage)).tag(ScreenshotOpenAction.finder)
        }
        .disabled(windowManager.isTakingScreenshot)

        Picker(AppStrings.text(.recordingClickAction, in: windowManager.appLanguage), selection: $windowManager.recordingOpenAction) {
            Text(RecordingOpenAction.quickTime.localizedTitle(in: windowManager.appLanguage)).tag(RecordingOpenAction.quickTime)
            Text(RecordingOpenAction.finder.localizedTitle(in: windowManager.appLanguage)).tag(RecordingOpenAction.finder)
        }
        .disabled(windowManager.isRecordingPreparationActive)

        Picker(AppStrings.text(.zoomMagnification, in: windowManager.appLanguage), selection: $windowManager.recordingZoomScale) {
            ForEach(RecordingZoomScale.allCases, id: \.self) { scale in
                Text(scale.menuTitle).tag(scale)
            }
        }
        .disabled(windowManager.recordingOptionsDisabled)

        Toggle(AppStrings.text(.followCursor, in: windowManager.appLanguage), isOn: $windowManager.followCursorRecording)
            .disabled(windowManager.recordingOptionsDisabled)
        Toggle(AppStrings.text(.livePreviewDuringRecording, in: windowManager.appLanguage), isOn: $windowManager.livePreviewDuringRecording)
            .disabled(windowManager.livePreviewToggleDisabled)
        Toggle(AppStrings.text(.cursorHighlight, in: windowManager.appLanguage), isOn: $windowManager.cursorHighlightEnabled)
            .disabled(windowManager.recordingOptionsDisabled)
        Toggle(AppStrings.text(.clickRing, in: windowManager.appLanguage), isOn: $windowManager.clickRingEnabled)
            .disabled(windowManager.recordingOptionsDisabled)
        Button(AppStrings.text(.cursorHighlightColor, in: windowManager.appLanguage)) {
            windowManager.openCursorHighlightColorPanel()
        }
        .disabled(windowManager.recordingOptionsDisabled)
        Button(AppStrings.text(.clickRingColor, in: windowManager.appLanguage)) {
            windowManager.openClickRingColorPanel()
        }
        .disabled(windowManager.recordingOptionsDisabled)
        Button(AppStrings.text(.resetCursorColors, in: windowManager.appLanguage)) {
            windowManager.resetRecordingCursorColors()
        }
        .disabled(windowManager.recordingOptionsDisabled)
    }

    private func promptSavePreset() {
        let alert = NSAlert()
        alert.messageText = AppStrings.text(.saveLayoutPreset, in: windowManager.appLanguage)
        alert.informativeText = AppStrings.text(.saveLayoutPresetMessage, in: windowManager.appLanguage)
        alert.addButton(withTitle: AppStrings.text(.save, in: windowManager.appLanguage))
        alert.addButton(withTitle: AppStrings.text(.cancel, in: windowManager.appLanguage))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.placeholderString = AppStrings.text(.presetName, in: windowManager.appLanguage)
        let count = windowManager.presetManager.presets.count + 1
        textField.stringValue = AppStrings.presetDefaultName(count, in: windowManager.appLanguage)
        alert.accessoryView = textField

        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                windowManager.saveCurrentLayout(name: name)
            }
        }
    }

    private var appVersionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return AppStrings.version(short: short, build: build, in: windowManager.appLanguage)
    }

    private func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @ViewBuilder
    private func selectionMenuLabel(_ title: String, selected: Bool) -> some View {
        HStack {
            Image(systemName: selected ? "checkmark" : "")
                .frame(width: 12)
            Text(title)
        }
    }

}
