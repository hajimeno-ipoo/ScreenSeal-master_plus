import AppKit
import ApplicationServices
import CoreImage
import Foundation
import ScreenCaptureKit
import os.log

private let logger = Logger(subsystem: "com.screenseal.app", category: "ScreenCapture")
private let screenshotLogger = Logger(subsystem: "com.screenseal.app", category: "Screenshot")
private let scrollCaptureLogger = Logger(subsystem: "com.screenseal.app", category: "ScrollCapture")

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
        let image = try await captureImage(
            target: target,
            excludedApplications: excludedApplications,
            exceptingWindows: exceptingWindows,
            overlayWindowIDs: overlayWindowIDs
        )
        let outputURL = try Self.makeSingleScreenshotOutputURL()
        try Self.savePNG(image, to: outputURL)
        screenshotLogger.info("Screenshot saved: \(outputURL.path)")
        return ScreenshotCaptureResult(outputURL: outputURL, image: image)
    }

    func captureImage(
        target: ResolvedRecordingTarget,
        excludedApplications: [SCRunningApplication] = [],
        exceptingWindows: [SCWindow] = [],
        overlayWindowIDs: [CGWindowID] = []
    ) async throws -> CGImage {
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

        return try await captureImage(contentFilter: filter, configuration: configuration)
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

    static func savePNG(_ image: CGImage, to url: URL) throws {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.pngEncodingFailed
        }
        try data.write(to: url, options: .atomic)
    }

    static func makeOutputDirectory() throws -> URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Pictures", isDirectory: true)
        let directory = pictures.appendingPathComponent("ScreenSeal_plus", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func makeTimestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func makeSingleScreenshotOutputURL() throws -> URL {
        let directory = try makeOutputDirectory()
        return directory.appendingPathComponent("ScreenSeal_plus-\(makeTimestampString()).png")
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

@available(macOS 14.0, *)
struct ScrollCaptureResult {
    let outputURL: URL
}

@available(macOS 14.0, *)
final class ScrollCaptureService {
    private static let maxStepCount = 20
    private static let maxOutputHeight = 30_000
    private static let captureDelayNanoseconds: UInt64 = 350_000_000
    private static let minimumNewContentHeight = 32
    private static let endDetectionRepeatCount = 2
    private static let comparisonWidth = 72
    private static let minimumOverlapRatio = 0.10
    private static let maximumOverlapRatio = 1.0

    private let screenshotService = ScreenshotService()

    func capture(
        target: ResolvedRecordingTarget,
        excludedApplications: [SCRunningApplication] = [],
        exceptingWindows: [SCWindow] = [],
        overlayWindowIDs: [CGWindowID] = [],
        stopRequested: @escaping @Sendable () -> Bool
    ) async throws -> ScrollCaptureResult {
        if case .display = target {
            throw ScrollCaptureError.invalidTarget
        }
        guard AXIsProcessTrusted() else {
            throw ScrollCaptureError.accessibilityPermissionRequired
        }

        let sessionIdentifier = ScreenshotService.makeTimestampString()
        let workingDirectory = try Self.makeWorkingDirectory(sessionIdentifier: sessionIdentifier)
        defer {
            try? FileManager.default.removeItem(at: workingDirectory)
        }

        let scrollPoint = Self.scrollPoint(for: target)
        let firstImage = try await screenshotService.captureImage(
            target: target,
            excludedApplications: excludedApplications,
            exceptingWindows: exceptingWindows,
            overlayWindowIDs: overlayWindowIDs
        )
        var previousImage = firstImage
        var segments: [CGImage] = [firstImage]
        var totalHeight = firstImage.height
        var stepIndex = 1
        var noProgressCount = 0
        var scrollDirection: Int32 = -1
        var didReverseDirection = false

        try ScreenshotService.savePNG(firstImage, to: Self.stepImageURL(in: workingDirectory, stepIndex: stepIndex))

        while stepIndex < Self.maxStepCount {
            if stopRequested() { break }

            try Self.postScroll(at: scrollPoint, viewportHeight: previousImage.height, direction: scrollDirection)
            try await Task.sleep(nanoseconds: Self.captureDelayNanoseconds)

            let currentImage = try await screenshotService.captureImage(
                target: target,
                excludedApplications: excludedApplications,
                exceptingWindows: exceptingWindows,
                overlayWindowIDs: overlayWindowIDs
            )
            let analysis = try Self.analyzeAppend(previous: previousImage, current: currentImage)

            if !didReverseDirection, stepIndex == 1, analysis.newContentHeight < Self.minimumNewContentHeight {
                scrollDirection *= -1
                didReverseDirection = true
                continue
            }

            didReverseDirection = true
            stepIndex += 1
            try ScreenshotService.savePNG(currentImage, to: Self.stepImageURL(in: workingDirectory, stepIndex: stepIndex))

            if analysis.newContentHeight < Self.minimumNewContentHeight {
                noProgressCount += 1
                previousImage = currentImage
                if noProgressCount >= Self.endDetectionRepeatCount {
                    break
                }
                continue
            }

            noProgressCount = 0
            let remainingHeight = Self.maxOutputHeight - totalHeight
            if remainingHeight <= 0 { break }
            let appendedSegment = try Self.croppedBottomImage(
                from: currentImage,
                skippingTop: analysis.overlapHeight,
                maximumHeight: remainingHeight
            )
            if appendedSegment.height > 0 {
                segments.append(appendedSegment)
                totalHeight += appendedSegment.height
            }
            previousImage = currentImage

            if totalHeight >= Self.maxOutputHeight {
                break
            }
        }

        guard !segments.isEmpty else {
            throw ScrollCaptureError.noCapturedFrames
        }

        let stitchedImage = try Self.stitchedImage(from: segments)
        try ScreenshotService.savePNG(stitchedImage, to: workingDirectory.appendingPathComponent("stitched.png"))

        let archiveURL = try Self.makeArchiveURL(sessionIdentifier: sessionIdentifier)
        try Self.createArchive(from: workingDirectory, to: archiveURL)
        scrollCaptureLogger.info("Scroll capture saved: \(archiveURL.path)")
        return ScrollCaptureResult(outputURL: archiveURL)
    }

    private static func makeWorkingDirectory(sessionIdentifier: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenSeal_plus-scroll-\(sessionIdentifier)", isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func makeArchiveURL(sessionIdentifier: String) throws -> URL {
        let directory = try ScreenshotService.makeOutputDirectory()
        return directory.appendingPathComponent("ScreenSeal_plus-scroll-\(sessionIdentifier).zip")
    }

    private static func stepImageURL(in directory: URL, stepIndex: Int) -> URL {
        directory.appendingPathComponent(String(format: "step_%03d.png", stepIndex))
    }

    private static func createArchive(from directory: URL, to archiveURL: URL) throws {
        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try FileManager.default.removeItem(at: archiveURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", directory.path, archiveURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ScrollCaptureError.zipCreationFailed
        }
    }

    private static func scrollPoint(for target: ResolvedRecordingTarget) -> CGPoint {
        switch target {
        case .display(_, let frame):
            return CGPoint(x: frame.midX, y: frame.midY)
        case .window(_, let windowFrame, _, _):
            return CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        case .region(let selection):
            return CGPoint(x: selection.rect.midX, y: selection.rect.midY)
        }
    }

    private static func postScroll(at point: CGPoint, viewportHeight: Int, direction: Int32) throws {
        let baseDelta = max(240, min(900, Int(CGFloat(viewportHeight) * 0.65)))
        let chunkDelta = max(80, baseDelta / 3)
        for _ in 0..<3 {
            guard let event = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: direction * Int32(chunkDelta),
                wheel2: 0,
                wheel3: 0
            ) else {
                throw ScrollCaptureError.scrollEventCreationFailed
            }
            event.location = point
            event.post(tap: .cghidEventTap)
        }
    }

    private static func stitchedImage(from segments: [CGImage]) throws -> CGImage {
        let width = segments.map(\.width).max() ?? 1
        let height = max(1, segments.reduce(0) { $0 + $1.height })
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScrollCaptureError.imageProcessingFailed
        }

        var currentY = height
        for segment in segments {
            currentY -= segment.height
            context.draw(segment, in: CGRect(x: 0, y: currentY, width: segment.width, height: segment.height))
        }

        guard let image = context.makeImage() else {
            throw ScrollCaptureError.imageProcessingFailed
        }
        return image
    }

    private static func croppedBottomImage(
        from image: CGImage,
        skippingTop: Int,
        maximumHeight: Int
    ) throws -> CGImage {
        let top = min(max(0, skippingTop), image.height)
        let availableHeight = max(0, image.height - top)
        let cropHeight = min(availableHeight, maximumHeight)
        guard cropHeight > 0,
              let cropped = image.cropping(to: CGRect(x: 0, y: top, width: image.width, height: cropHeight)) else {
            throw ScrollCaptureError.imageProcessingFailed
        }
        return cropped
    }

    private static func analyzeAppend(previous: CGImage, current: CGImage) throws -> AppendAnalysis {
        let previousReduced = try reducedImage(from: previous)
        let currentReduced = try reducedImage(from: current)
        let maxOverlap = min(previousReduced.height, currentReduced.height)
        guard maxOverlap > 0 else {
            throw ScrollCaptureError.imageProcessingFailed
        }
        let minOverlap = max(8, Int(CGFloat(maxOverlap) * minimumOverlapRatio))
        let overlapRange = minOverlap...max(8, Int(CGFloat(maxOverlap) * maximumOverlapRatio))

        var bestOverlap = minOverlap
        var bestScore = Double.greatestFiniteMagnitude
        for overlap in overlapRange {
            let score = differenceScore(previous: previousReduced, current: currentReduced, overlap: overlap)
            if score < bestScore {
                bestScore = score
                bestOverlap = overlap
            }
        }

        let scale = Double(current.height) / Double(currentReduced.height)
        let overlapHeight = min(current.height, max(0, Int((Double(bestOverlap) * scale).rounded())))
        let newContentHeight = max(0, current.height - overlapHeight)
        return AppendAnalysis(overlapHeight: overlapHeight, newContentHeight: newContentHeight, score: bestScore)
    }

    private static func reducedImage(from image: CGImage) throws -> ReducedImage {
        let inset = image.width / 5
        let sampleWidth = max(1, image.width - (inset * 2))
        let sampleRect = CGRect(x: inset, y: 0, width: sampleWidth, height: image.height)
        let sourceImage = image.cropping(to: sampleRect) ?? image

        let targetWidth = min(comparisonWidth, max(1, sourceImage.width))
        let scale = CGFloat(targetWidth) / CGFloat(sourceImage.width)
        let targetHeight = max(1, Int(CGFloat(sourceImage.height) * scale))

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw ScrollCaptureError.imageProcessingFailed
        }
        context.interpolationQuality = .low
        context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let data = context.data else {
            throw ScrollCaptureError.imageProcessingFailed
        }
        let pixels = Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: targetWidth * targetHeight))
        return ReducedImage(width: targetWidth, height: targetHeight, pixels: pixels)
    }

    private static func differenceScore(previous: ReducedImage, current: ReducedImage, overlap: Int) -> Double {
        let rowStep = max(1, overlap / 64)
        let columnStep = max(1, previous.width / 36)
        var totalDifference = 0.0
        var sampleCount = 0

        for row in stride(from: 0, to: overlap, by: rowStep) {
            let previousRow = previous.height - overlap + row
            let currentRow = row
            for column in stride(from: 0, to: previous.width, by: columnStep) {
                let previousValue = previous.pixels[(previousRow * previous.width) + column]
                let currentValue = current.pixels[(currentRow * current.width) + column]
                totalDifference += Double(abs(Int(previousValue) - Int(currentValue)))
                sampleCount += 1
            }
        }

        guard sampleCount > 0 else { return Double.greatestFiniteMagnitude }
        return totalDifference / Double(sampleCount)
    }
}

private struct ReducedImage {
    let width: Int
    let height: Int
    let pixels: [UInt8]
}

private struct AppendAnalysis {
    let overlapHeight: Int
    let newContentHeight: Int
    let score: Double
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

private enum ScrollCaptureError: LocalizedError {
    case invalidTarget
    case accessibilityPermissionRequired
    case scrollEventCreationFailed
    case imageProcessingFailed
    case noCapturedFrames
    case zipCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidTarget:
            return "Scroll Capture requires Window or Region."
        case .accessibilityPermissionRequired:
            return "Scroll Capture requires Accessibility permission."
        case .scrollEventCreationFailed:
            return "Scroll event could not be created."
        case .imageProcessingFailed:
            return "Scroll Capture image processing failed."
        case .noCapturedFrames:
            return "No scroll capture frames were produced."
        case .zipCreationFailed:
            return "Scroll Capture ZIP creation failed."
        }
    }
}
