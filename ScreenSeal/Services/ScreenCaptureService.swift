import AppKit
import CoreImage
import Foundation
import ScreenCaptureKit
import os.log

private let logger = Logger(subsystem: "com.screenseal.app", category: "ScreenCapture")
private let screenshotLogger = Logger(subsystem: "com.screenseal.app", category: "Screenshot")

final class ScreenCaptureService: NSObject {
    private var streams: [CGDirectDisplayID: SCStream] = [:]
    private var streamOutputs: [CGDirectDisplayID: StreamOutput] = [:]
    private var isRunning = false

    var onFrame: ((CIImage, CGDirectDisplayID) -> Void)?
    var onError: ((String) -> Void)?

    func startCapture() async {
        guard !isRunning else { return }
        isRunning = true

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

            guard !content.displays.isEmpty else {
                logger.error("No display found")
                onError?("No display found")
                isRunning = false
                return
            }

            let selfBundleID = Bundle.main.bundleIdentifier ?? ""
            let excludedApps = content.applications.filter { $0.bundleIdentifier == selfBundleID }

            for display in content.displays {
                let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])

                let config = SCStreamConfiguration()
                let scaleFactor: CGFloat = await MainActor.run {
                    NSScreen.screens
                        .first(where: { $0.displayID == display.displayID })?
                        .backingScaleFactor ?? 2.0
                }
                config.width = Int(CGFloat(display.width) * scaleFactor)
                config.height = Int(CGFloat(display.height) * scaleFactor)
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = false
                config.queueDepth = 3

                let output = StreamOutput(displayID: display.displayID)
                output.onFrame = { [weak self] image, id in
                    self?.onFrame?(image, id)
                }

                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
                try await stream.startCapture()

                streams[display.displayID] = stream
                streamOutputs[display.displayID] = output

                logger.info("Started capture for display \(display.displayID)")
            }
        } catch {
            logger.error("Failed to start capture: \(error.localizedDescription)")
            onError?("Screen capture failed: \(error.localizedDescription)")
            isRunning = false
        }
    }

    func stopCapture() async {
        let currentStreams = streams
        streams.removeAll()
        streamOutputs.removeAll()
        isRunning = false

        for (displayID, stream) in currentStreams {
            do {
                try await stream.stopCapture()
                logger.info("Stopped capture for display \(displayID)")
            } catch {
                logger.error("Failed to stop capture for display \(displayID): \(error.localizedDescription)")
            }
        }
    }

    func updateExclusion() async {
        guard !streams.isEmpty else { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            let selfBundleID = Bundle.main.bundleIdentifier ?? ""
            let excludedApps = content.applications.filter { $0.bundleIdentifier == selfBundleID }

            for (displayID, stream) in streams {
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else { continue }
                let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
                try await stream.updateContentFilter(filter)
            }
        } catch {
            logger.error("Failed to update exclusion: \(error.localizedDescription)")
        }
    }
}

// MARK: - Stream Output

private final class StreamOutput: NSObject, SCStreamOutput, @unchecked Sendable {
    let displayID: CGDirectDisplayID
    var onFrame: ((CIImage, CGDirectDisplayID) -> Void)?

    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        onFrame?(ciImage, displayID)
    }
}

@available(macOS 14.0, *)
struct ScreenshotCaptureResult {
    let outputURL: URL
    let image: CGImage
}

@available(macOS 14.0, *)
final class ScreenshotService {
    func capture(
        target: ResolvedRecordingTarget,
        excludedApplications: [SCRunningApplication] = [],
        exceptingWindows: [SCWindow] = [],
        overlayWindowIDs: [CGWindowID] = []
    ) async throws -> ScreenshotCaptureResult {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let configuration = SCStreamConfiguration()
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false

        let filter: SCContentFilter

        switch target {
        case .display(let displayID, _):
            guard let display = content.displays.first(where: { $0.displayID == displayID }) ?? content.displays.first else {
                throw ScreenshotError.displayNotFound
            }

            let scaleFactor = await MainActor.run {
                Self.screen(forDisplayID: display.displayID)?.backingScaleFactor ?? 2.0
            }
            configuration.width = Int(CGFloat(display.width) * scaleFactor)
            configuration.height = Int(CGFloat(display.height) * scaleFactor)
            filter = SCContentFilter(
                display: display,
                excludingApplications: excludedApplications,
                exceptingWindows: exceptingWindows
            )

        case .window(let windowID, let windowFrame, let displayID, let displayFrame):
            guard content.windows.contains(where: { $0.windowID == windowID }) else {
                throw ScreenshotError.windowNotFound
            }
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                throw ScreenshotError.displayNotFound
            }

            let scaleFactor = await MainActor.run {
                Self.screen(containing: windowFrame)?.backingScaleFactor ?? 2.0
            }
            let localRect = CGRect(
                x: windowFrame.minX - displayFrame.minX,
                y: displayFrame.maxY - windowFrame.maxY,
                width: windowFrame.width,
                height: windowFrame.height
            )
            let includedWindowIDs = Set(overlayWindowIDs).union([windowID])
            let includedWindows = content.windows.filter { includedWindowIDs.contains($0.windowID) }
            configuration.sourceRect = localRect
            configuration.width = max(1, Int(localRect.width * scaleFactor))
            configuration.height = max(1, Int(localRect.height * scaleFactor))
            filter = SCContentFilter(display: display, including: includedWindows)

        case .region(let selection):
            guard let display = content.displays.first(where: { $0.displayID == selection.displayID }) else {
                throw ScreenshotError.displayNotFound
            }
            guard let screenFrame = await MainActor.run(body: {
                Self.screen(forDisplayID: selection.displayID)?.frame
            }) else {
                throw ScreenshotError.displayNotFound
            }

            let localRect = CGRect(
                x: selection.rect.minX - screenFrame.minX,
                y: screenFrame.maxY - selection.rect.maxY,
                width: selection.rect.width,
                height: selection.rect.height
            )
            let scaleFactor = await MainActor.run {
                Self.screen(forDisplayID: selection.displayID)?.backingScaleFactor ?? 2.0
            }
            configuration.sourceRect = localRect
            configuration.width = max(1, Int(localRect.width * scaleFactor))
            configuration.height = max(1, Int(localRect.height * scaleFactor))
            filter = SCContentFilter(
                display: display,
                excludingApplications: excludedApplications,
                exceptingWindows: exceptingWindows
            )
        }

        let image = try await captureImage(contentFilter: filter, configuration: configuration)
        let outputURL = try makeOutputURL()
        try savePNG(image, to: outputURL)
        screenshotLogger.info("Screenshot saved: \(outputURL.path)")
        return ScreenshotCaptureResult(outputURL: outputURL, image: image)
    }

    private func captureImage(
        contentFilter: SCContentFilter,
        configuration: SCStreamConfiguration
    ) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let image else {
                    continuation.resume(throwing: ScreenshotError.imageCreationFailed)
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }

    private func savePNG(_ image: CGImage, to url: URL) throws {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.pngEncodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    private func makeOutputURL() throws -> URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures", isDirectory: true)
        let directory = pictures.appendingPathComponent("ScreenSeal_plus", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let timestamp = formatter.string(from: Date())
        return directory.appendingPathComponent("ScreenSeal_plus-\(timestamp).png")
    }

    @MainActor
    private static func screen(forDisplayID displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first(where: { $0.displayID == displayID })
    }

    @MainActor
    private static func screen(containing frame: CGRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return screen
        }
        return NSScreen.screens.first(where: { $0.frame.intersects(frame) })
    }
}

private enum ScreenshotError: LocalizedError {
    case displayNotFound
    case windowNotFound
    case imageCreationFailed
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .displayNotFound:
            return "キャプチャ対象の画面が見つかりません。"
        case .windowNotFound:
            return "選択したウィンドウが見つかりません。"
        case .imageCreationFailed:
            return "スクリーンショット画像を取得できませんでした。"
        case .pngEncodingFailed:
            return "スクリーンショットの保存形式を作れませんでした。"
        }
    }
}
