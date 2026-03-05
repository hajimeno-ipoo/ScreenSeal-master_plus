import AppKit
@preconcurrency import AVFoundation
import CoreImage
import Foundation
import ScreenCaptureKit
import os.log

private let recordingLogger = Logger(subsystem: "com.screenseal.app", category: "Recording")

@available(macOS 15.0, *)
final class RecordingService: NSObject, SCStreamOutput, SCStreamDelegate {
    private let outputResolution = CGSize(width: 1920, height: 1080)
    private let idleCameraScale: CGFloat = 0.6
    private let idlePanDeadzoneRatio: CGFloat = 0.20
    private let zoomPanDeadzoneRatio: CGFloat = 0.08
    private let idlePanDurationMultiplier: CGFloat = 2.4
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var lastOutputURL: URL?
    private var sessionStarted = false
    private var captureDisplayFrame: CGRect = .zero
    private let mediaQueue = DispatchQueue(label: "com.screenseal.recording.media", qos: .userInitiated)
    private let ciContext = CIContext()
    private let pointerTrackingService = PointerTrackingService(fps: ZoomProfile.standard.fps)
    private let zoomProfile = ZoomProfile.standard
    private var currentZoomScale: CGFloat = ZoomProfile.standard.zoomOutScale
    private var currentZoomCenter: CGPoint?
    private var lastZoomUpdateTimestamp: CFTimeInterval = CACurrentMediaTime()
    private var isFinalizing = false

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

            let scaleFactor: CGFloat = await MainActor.run {
                NSScreen.screens.first(where: { $0.displayID == display.displayID })?.backingScaleFactor ?? 2.0
            }
            let screenFrame: CGRect = await MainActor.run {
                NSScreen.screens.first(where: { $0.displayID == display.displayID })?.frame ?? .zero
            }

            let config = SCStreamConfiguration()
            config.width = Int(CGFloat(display.width) * scaleFactor)
            config.height = Int(CGFloat(display.height) * scaleFactor)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(max(1, zoomProfile.fps)))
            config.queueDepth = 5
            config.showsCursor = true
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = false
            config.captureMicrophone = false
            config.sampleRate = 48_000
            config.channelCount = 2

            let outputURL = try makeOutputURL()
            let writerBundle = try makeWriter(
                outputURL: outputURL,
                width: Int(outputResolution.width),
                height: Int(outputResolution.height)
            )

            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let stream = SCStream(filter: filter, configuration: config, delegate: self)

            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: mediaQueue)
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: mediaQueue)

            self.writer = writerBundle.writer
            self.videoInput = writerBundle.videoInput
            self.audioInput = writerBundle.audioInput
            self.pixelBufferAdaptor = writerBundle.pixelBufferAdaptor
            self.stream = stream
            self.lastOutputURL = outputURL
            self.captureDisplayFrame = screenFrame
            self.sessionStarted = false
            self.currentZoomScale = zoomProfile.zoomOutScale
            self.currentZoomCenter = nil
            self.lastZoomUpdateTimestamp = CACurrentMediaTime()

            await MainActor.run {
                pointerTrackingService.start()
            }
            try await stream.startCapture()

            state = .recording(url: outputURL, startedAt: Date())
            recordingLogger.info("Recording started: \(outputURL.path)")
            return outputURL
        } catch {
            await MainActor.run {
                pointerTrackingService.stop()
            }
            cleanupResources()
            state = .failed(message: "録画開始に必要な権限が不足、または開始に失敗しました")
            recordingLogger.error("Recording start failed: \(error.localizedDescription)")
            throw error
        }
    }

    func stop() async throws -> URL {
        guard let outputURL = lastOutputURL else {
            throw RecordingError.invalidState
        }

        if case .idle = state {
            return outputURL
        }
        if case .failed = state {
            return outputURL
        }

        if isFinalizing {
            return outputURL
        }

        state = .stopping
        isFinalizing = true
        await MainActor.run {
            pointerTrackingService.stop()
        }

        do {
            let finalizedURL = try await finalizeRecording(skipStreamStop: false)
            state = .idle
            recordingLogger.info("Recording stopped: \(finalizedURL.path)")
            return finalizedURL
        } catch {
            cleanupResources()
            if case RecordingError.noVideoFrame = error {
                state = .failed(message: "録画データを取得できませんでした")
            } else {
                state = .failed(message: "録画停止に失敗しました")
            }
            recordingLogger.error("Recording stop failed: \(error.localizedDescription)")
            throw error
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        guard case .recording = state else { return }

        switch outputType {
        case .screen:
            appendVideoSampleBuffer(sampleBuffer)
        case .audio:
            appendAudioSampleBuffer(sampleBuffer)
        default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: any Error) {
        recordingLogger.warning("Stream stopped with error: \(error.localizedDescription)")
        guard case .recording = state else { return }
        guard !isFinalizing else { return }

        Task { [weak self] in
            guard let self else { return }
            self.state = .stopping
            self.isFinalizing = true
            await MainActor.run {
                self.pointerTrackingService.stop()
            }
            do {
                _ = try await self.finalizeRecording(skipStreamStop: true)
                self.state = .idle
                recordingLogger.info("Recording stopped by system control")
            } catch {
                self.cleanupResources()
                self.state = .failed(message: "録画停止に失敗しました")
            }
        }
    }

    private func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let writer, let videoInput, let pixelBufferAdaptor else { return }
        guard writer.status == .unknown || writer.status == .writing else { return }
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if !sessionStarted {
            writer.startWriting()
            writer.startSession(atSourceTime: presentationTime)
            sessionStarted = true
            lastZoomUpdateTimestamp = CACurrentMediaTime()
            currentZoomScale = zoomProfile.zoomOutScale
        }

        guard videoInput.isReadyForMoreMediaData else { return }
        guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
            recordingLogger.error("Pixel buffer pool is unavailable")
            return
        }

        var outputPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &outputPixelBuffer)
        guard status == kCVReturnSuccess, let outputPixelBuffer else {
            recordingLogger.error("Failed to create output pixel buffer")
            return
        }

        let sourceImage = CIImage(cvPixelBuffer: imageBuffer)
        let outputSize = CGSize(
            width: CVPixelBufferGetWidth(outputPixelBuffer),
            height: CVPixelBufferGetHeight(outputPixelBuffer)
        )
        let zoomedImage = applyRecordingZoom(to: sourceImage, outputSize: outputSize)
        let renderBounds = CGRect(origin: .zero, size: outputSize)
        ciContext.render(zoomedImage, to: outputPixelBuffer, bounds: renderBounds, colorSpace: CGColorSpaceCreateDeviceRGB())

        if !pixelBufferAdaptor.append(outputPixelBuffer, withPresentationTime: presentationTime), writer.status == .failed {
            recordingLogger.error("Video append failed: \(writer.error?.localizedDescription ?? "unknown")")
        }
    }

    private func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard sessionStarted else { return }
        guard let writer, let audioInput else { return }
        guard writer.status == .writing else { return }
        guard audioInput.isReadyForMoreMediaData else { return }

        if !audioInput.append(sampleBuffer), writer.status == .failed {
            recordingLogger.error("Audio append failed: \(writer.error?.localizedDescription ?? "unknown")")
        }
    }

    private func applyRecordingZoom(to image: CIImage, outputSize: CGSize) -> CIImage {
        let extent = image.extent
        guard !captureDisplayFrame.isEmpty, outputSize.width > 0, outputSize.height > 0 else { return image }

        let pointer = pointerTrackingService.snapshot
        let targetLocation = pointer.cursorLocation
        let shouldZoom = pointer.isZoomActive
        let targetScale: CGFloat = shouldZoom
            ? zoomProfile.zoomInScale
            : zoomProfile.zoomOutScale

        let now = CACurrentMediaTime()
        let elapsed = max(0, now - lastZoomUpdateTimestamp)
        lastZoomUpdateTimestamp = now
        currentZoomScale = smoothValue(
            currentZoomScale,
            toward: targetScale,
            elapsed: elapsed,
            duration: zoomProfile.easingDuration
        )

        let cursorPoint = convertScreenPointToImagePoint(targetLocation, imageExtent: extent)
        let initialCenter = currentZoomCenter ?? pointer.zoomAnchorLocation.map {
            convertScreenPointToImagePoint($0, imageExtent: extent)
        } ?? cursorPoint
        let baseCropSize = baseCameraCropSize(in: extent, outputSize: outputSize)
        let deadzoneRatio = shouldZoom ? zoomPanDeadzoneRatio : idlePanDeadzoneRatio
        let deadzoneSize = CGSize(
            width: baseCropSize.width * deadzoneRatio,
            height: baseCropSize.height * deadzoneRatio
        )
        let targetCenter = applyPanDeadzone(
            currentCenter: initialCenter,
            targetCursor: cursorPoint,
            deadzoneSize: deadzoneSize
        )
        let panDuration: TimeInterval = shouldZoom
            ? zoomProfile.cursorFollowDuration
            : max(zoomProfile.cursorFollowDuration * idlePanDurationMultiplier, 0.24)
        currentZoomCenter = smoothPoint(
            initialCenter,
            toward: targetCenter,
            elapsed: elapsed,
            duration: panDuration
        )

        guard let zoomCenter = currentZoomCenter else {
            return image
        }

        let effectiveScale = shouldZoom
            ? currentZoomScale
            : max(0.01, currentZoomScale * idleCameraScale)
        let zoomedWidth = baseCropSize.width / effectiveScale
        let zoomedHeight = baseCropSize.height / effectiveScale
        let minX = extent.minX
        let minY = extent.minY
        let maxX = extent.maxX - zoomedWidth
        let maxY = extent.maxY - zoomedHeight

        let clampedX = min(max(zoomCenter.x - (zoomedWidth / 2), minX), maxX)
        let clampedY = min(max(zoomCenter.y - (zoomedHeight / 2), minY), maxY)
        let cropRect = CGRect(x: clampedX, y: clampedY, width: zoomedWidth, height: zoomedHeight)

        let translated = image
            .cropped(to: cropRect)
            .transformed(by: CGAffineTransform(translationX: -cropRect.origin.x, y: -cropRect.origin.y))

        let scaleTransform = CGAffineTransform(
            scaleX: outputSize.width / cropRect.width,
            y: outputSize.height / cropRect.height
        )
        let scaled = translated.transformed(by: scaleTransform)
        return scaled.cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    private func applyPanDeadzone(
        currentCenter: CGPoint,
        targetCursor: CGPoint,
        deadzoneSize: CGSize
    ) -> CGPoint {
        let deltaX = targetCursor.x - currentCenter.x
        let deltaY = targetCursor.y - currentCenter.y
        let withinDeadzoneX = abs(deltaX) <= deadzoneSize.width
        let withinDeadzoneY = abs(deltaY) <= deadzoneSize.height
        if withinDeadzoneX && withinDeadzoneY {
            return currentCenter
        }
        return targetCursor
    }

    private func convertScreenPointToImagePoint(_ point: CGPoint, imageExtent: CGRect) -> CGPoint {
        let scaleX = imageExtent.width / captureDisplayFrame.width
        let scaleY = imageExtent.height / captureDisplayFrame.height
        let localX = point.x - captureDisplayFrame.minX
        let localY = point.y - captureDisplayFrame.minY
        return CGPoint(x: localX * scaleX, y: localY * scaleY)
    }

    private func baseCameraCropSize(in imageExtent: CGRect, outputSize: CGSize) -> CGSize {
        let aspect = outputSize.width / outputSize.height
        var width = min(imageExtent.width, outputSize.width)
        var height = width / aspect

        if height > imageExtent.height {
            height = imageExtent.height
            width = height * aspect
        }

        return CGSize(width: width, height: height)
    }

    private func smoothValue(
        _ current: CGFloat,
        toward target: CGFloat,
        elapsed: CFTimeInterval,
        duration: TimeInterval
    ) -> CGFloat {
        guard duration > 0 else { return target }
        let progress = min(1.0, elapsed / duration)
        let eased = progress * progress * (3.0 - (2.0 * progress))
        return current + ((target - current) * eased)
    }

    private func smoothPoint(
        _ current: CGPoint,
        toward target: CGPoint,
        elapsed: CFTimeInterval,
        duration: TimeInterval
    ) -> CGPoint {
        CGPoint(
            x: smoothValue(current.x, toward: target.x, elapsed: elapsed, duration: duration),
            y: smoothValue(current.y, toward: target.y, elapsed: elapsed, duration: duration)
        )
    }

    private func makeWriter(
        outputURL: URL,
        width: Int,
        height: Int
    ) throws -> (
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput,
        pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
    ) {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)

        let videoCompression: [String: Any] = [
            AVVideoAverageBitRateKey: 12_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        ]
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: videoCompression
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(videoInput) else { throw RecordingError.writerConfigurationFailed }
        writer.add(videoInput)

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(audioInput) else { throw RecordingError.writerConfigurationFailed }
        writer.add(audioInput)

        return (writer, videoInput, audioInput, pixelBufferAdaptor)
    }

    private func finishWriting() async throws {
        guard let writer else { return }
        let writerBox = SendableWriterBox(writer)

        if writerBox.writer.status == .completed {
            return
        }
        if writerBox.writer.status == .failed {
            throw RecordingError.writerFailed(writerBox.writer.error?.localizedDescription ?? "unknown")
        }
        if writerBox.writer.status == .cancelled {
            throw RecordingError.writerFailed("writer cancelled")
        }
        if writerBox.writer.status == .unknown {
            writerBox.writer.cancelWriting()
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writerBox.writer.finishWriting {
                if writerBox.writer.status == .completed {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: RecordingError.writerFailed(writerBox.writer.error?.localizedDescription ?? "finishWriting failed"))
                }
            }
        }
    }

    private func finalizeRecording(skipStreamStop: Bool) async throws -> URL {
        guard let outputURL = lastOutputURL else {
            throw RecordingError.invalidState
        }

        if !skipStreamStop, let stream {
            do {
                try await stream.stopCapture()
            } catch {
                recordingLogger.warning("stopCapture failed but continuing finalize: \(error.localizedDescription)")
            }
        }

        await waitForMediaQueueDrain()

        if sessionStarted {
            videoInput?.markAsFinished()
            audioInput?.markAsFinished()
            try await finishWriting()
        } else if let writer {
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw RecordingError.noVideoFrame
        }

        cleanupResources()
        return outputURL
    }

    private func waitForMediaQueueDrain() async {
        await withCheckedContinuation { continuation in
            mediaQueue.async {
                continuation.resume()
            }
        }
    }

    private func cleanupResources() {
        stream = nil
        writer = nil
        videoInput = nil
        audioInput = nil
        pixelBufferAdaptor = nil
        sessionStarted = false
        captureDisplayFrame = .zero
        currentZoomScale = zoomProfile.zoomOutScale
        currentZoomCenter = nil
        isFinalizing = false
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
private final class SendableWriterBox: @unchecked Sendable {
    let writer: AVAssetWriter

    init(_ writer: AVAssetWriter) {
        self.writer = writer
    }
}

@available(macOS 15.0, *)
private enum RecordingError: Error {
    case invalidState
    case displayNotFound
    case writerConfigurationFailed
    case writerFailed(String)
    case noVideoFrame
}
