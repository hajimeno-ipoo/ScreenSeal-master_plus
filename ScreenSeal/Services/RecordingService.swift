import AppKit
import AVFoundation
import Foundation
import ScreenCaptureKit
import os.log

private let recordingLogger = Logger(subsystem: "com.screenseal.app", category: "Recording")

@available(macOS 15.0, *)
final class RecordingService: NSObject, SCRecordingOutputDelegate {
    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private(set) var state: RecordingState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((RecordingState) -> Void)?

    func start(displayID: CGDirectDisplayID) async throws -> URL {
        guard case .idle = state else {
            throw RecordingError.invalidState
        }

        state = .starting

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let display = content.displays.first(where: { $0.displayID == displayID })
                ?? content.displays.first else {
                throw RecordingError.displayNotFound
            }

            let selfBundleID = Bundle.main.bundleIdentifier ?? ""
            let excludedApps = content.applications.filter { $0.bundleIdentifier == selfBundleID }
            let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])

            let config = SCStreamConfiguration()
            let scaleFactor: CGFloat = await MainActor.run {
                NSScreen.screens.first(where: { $0.displayID == display.displayID })?.backingScaleFactor ?? 2.0
            }

            config.width = Int(CGFloat(display.width) * scaleFactor)
            config.height = Int(CGFloat(display.height) * scaleFactor)
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.queueDepth = 5
            config.showsCursor = true
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = false
            config.captureMicrophone = false

            let outputURL = try makeOutputURL()
            let recordingConfig = SCRecordingOutputConfiguration()
            recordingConfig.outputURL = outputURL
            recordingConfig.outputFileType = .mp4
            recordingConfig.videoCodecType = .h264

            let output = SCRecordingOutput(configuration: recordingConfig, delegate: self)
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)

            try stream.addRecordingOutput(output)
            try await stream.startCapture()

            self.stream = stream
            self.recordingOutput = output
            state = .recording(url: outputURL, startedAt: Date())
            recordingLogger.info("Recording started: \(outputURL.path)")

            return outputURL
        } catch {
            state = .failed(message: "録画開始に必要な権限が不足、または開始に失敗しました")
            recordingLogger.error("Recording start failed: \(error.localizedDescription)")
            throw error
        }
    }

    func stop() async throws -> URL {
        guard case .recording(let url, _) = state else {
            throw RecordingError.invalidState
        }

        state = .stopping

        do {
            if let stream, let recordingOutput {
                try stream.removeRecordingOutput(recordingOutput)
            }
            if let stream {
                try await stream.stopCapture()
            }

            self.stream = nil
            self.recordingOutput = nil
            state = .idle
            recordingLogger.info("Recording stopped: \(url.path)")
            return url
        } catch {
            recordingLogger.error("Recording stop failed: \(error.localizedDescription)")
            state = .failed(message: "録画停止に失敗しました")
            throw error
        }
    }

    private func makeOutputURL() throws -> URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Movies", isDirectory: true)

        let directory = movies.appendingPathComponent("ScreenSeal", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "ScreenSeal-\(formatter.string(from: Date())).mp4"
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }
}

@available(macOS 15.0, *)
private enum RecordingError: Error {
    case invalidState
    case displayNotFound
}
