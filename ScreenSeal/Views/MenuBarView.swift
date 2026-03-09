import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var windowManager: WindowManager

    var body: some View {
        Button("New Mosaic Window") {
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
                        Text(window.configuration.mosaicType.rawValue)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                }
            }

            Divider()

            Button("Remove All Windows") {
                windowManager.removeAllWindows()
            }

            Divider()
        }

        // Presets
        if windowManager.windows.isEmpty {
            Divider()
        }

        Button("Save Current Layout...") {
            promptSavePreset()
        }
        .disabled(windowManager.windows.isEmpty)

        let presets = windowManager.presetManager.presets
        if !presets.isEmpty {
            Menu("Load Preset") {
                ForEach(presets) { preset in
                    Button("\(preset.name) (\(preset.windows.count) windows)") {
                        windowManager.loadPreset(preset)
                    }
                }
            }

            Menu("Delete Preset") {
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

            Button("Open Screen Recording Settings") {
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

        Button("Quit ScreenSeal_plus") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    @ViewBuilder
    private var captureSection: some View {
        if windowManager.captureMode == .record {
            if windowManager.isCountdownActive {
                Button("Cancel Countdown") {
                    windowManager.performPrimaryCaptureAction()
                }
                .keyboardShortcut("r")
            } else if windowManager.canStopRecording {
                Button("Stop Recording") {
                    windowManager.performPrimaryCaptureAction()
                }
                .keyboardShortcut("r")
            } else {
                Button("Start Recording") {
                    windowManager.performPrimaryCaptureAction()
                }
                .keyboardShortcut("r")
            }
        } else {
            Button("Take Screenshot") {
                windowManager.performPrimaryCaptureAction()
            }
            .keyboardShortcut("r")
            .disabled(windowManager.isTakingScreenshot)
        }

        Menu("Capture Mode") {
            Button {
                windowManager.captureMode = .record
            } label: {
                selectionMenuLabel("Record", selected: windowManager.captureMode == .record)
            }

            Button {
                windowManager.captureMode = .screenshot
            } label: {
                selectionMenuLabel("Screenshot", selected: windowManager.captureMode == .screenshot)
            }
        }
        .disabled(windowManager.isCaptureModeSelectionDisabled)

        Menu("Capture Target") {
            Button {
                windowManager.selectDisplayRecordingTarget()
            } label: {
                selectionMenuLabel("Full Display", selected: windowManager.recordingTarget == .display)
            }

            Button("Choose Window...") {
                windowManager.beginSystemWindowSelection()
            }
            .disabled(windowManager.isCaptureModeSelectionDisabled || windowManager.shouldDisableNonDisplayTargets)

            if case .window = windowManager.recordingTarget,
               let selectedWindowDisplayName = windowManager.selectedWindowDisplayName {
                Text("Selected Window: \(selectedWindowDisplayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                windowManager.beginRecordingRegionSelection()
            } label: {
                selectionMenuLabel("Select Region...", selected: windowManager.isRegionRecordingTarget)
            }
            .disabled(windowManager.isCaptureModeSelectionDisabled || windowManager.shouldDisableNonDisplayTargets)
        }
        .disabled(windowManager.isCaptureModeSelectionDisabled)

        Menu("Screenshot Click Action") {
            Button {
                windowManager.screenshotOpenAction = .preview
            } label: {
                selectionMenuLabel("Preview", selected: windowManager.screenshotOpenAction == .preview)
            }

            Button {
                windowManager.screenshotOpenAction = .finder
            } label: {
                selectionMenuLabel("Finder", selected: windowManager.screenshotOpenAction == .finder)
            }
        }
        .disabled(windowManager.isTakingScreenshot)

        Menu("Recording Click Action") {
            Button {
                windowManager.recordingOpenAction = .quickTime
            } label: {
                selectionMenuLabel("QuickTime", selected: windowManager.recordingOpenAction == .quickTime)
            }

            Button {
                windowManager.recordingOpenAction = .finder
            } label: {
                selectionMenuLabel("Finder", selected: windowManager.recordingOpenAction == .finder)
            }
        }
        .disabled(windowManager.isRecordingPreparationActive)

        Menu("Zoom Magnification") {
            ForEach(RecordingZoomScale.allCases, id: \.self) { scale in
                Button {
                    windowManager.recordingZoomScale = scale
                } label: {
                    selectionMenuLabel(scale.menuTitle, selected: windowManager.recordingZoomScale == scale)
                }
            }
        }
        .disabled(windowManager.recordingOptionsDisabled)

        Toggle("Follow Cursor", isOn: $windowManager.followCursorRecording)
            .disabled(windowManager.recordingOptionsDisabled)
        Toggle("Live Preview During Recording", isOn: $windowManager.livePreviewDuringRecording)
            .disabled(windowManager.livePreviewToggleDisabled)
        Toggle("Cursor Highlight", isOn: $windowManager.cursorHighlightEnabled)
            .disabled(windowManager.recordingOptionsDisabled)
        Toggle("Click Ring", isOn: $windowManager.clickRingEnabled)
            .disabled(windowManager.recordingOptionsDisabled)
        Button("Cursor Highlight Color...") {
            windowManager.openCursorHighlightColorPanel()
        }
        .disabled(windowManager.recordingOptionsDisabled)
        Button("Click Ring Color...") {
            windowManager.openClickRingColorPanel()
        }
        .disabled(windowManager.recordingOptionsDisabled)
        Button("Reset Cursor Colors") {
            windowManager.resetRecordingCursorColors()
        }
        .disabled(windowManager.recordingOptionsDisabled)
    }

    private func promptSavePreset() {
        let alert = NSAlert()
        alert.messageText = "Save Layout Preset"
        alert.informativeText = "Enter a name for this layout:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.placeholderString = "Preset name"
        let count = windowManager.presetManager.presets.count + 1
        textField.stringValue = "Preset \(count)"
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
        return "Version \(short) (\(build))"
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
