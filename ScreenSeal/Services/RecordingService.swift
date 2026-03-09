import AppKit
@preconcurrency import AVFoundation
import CoreImage
import Foundation
import ScreenCaptureKit
import os.log

private let recordingLogger = Logger(subsystem: "com.screenseal.app", category: "Recording")

@available(macOS 15.0, *)
final class RecordingService: NSObject, SCStreamOutput, SCStreamDelegate {
    private static let defaultHighlightColor = NSColor(
        deviceRed: 0.10,
        green: 0.65,
        blue: 1.0,
        alpha: 0.52
    )
    private static let defaultClickRingColor = NSColor(
        deviceRed: 0.10,
        green: 0.72,
        blue: 1.0,
        alpha: 0.95
    )

    private let outputResolution = CGSize(width: 1920, height: 1080)
    private let idleCameraScale: CGFloat = 0.6
    private let idleFollowMinimumScale: CGFloat = 1.15
    private let idlePanDeadzoneRatio: CGFloat = 0.04
    private let zoomPanDeadzoneRatio: CGFloat = 0.08
    private let idlePanDurationMultiplier: CGFloat = 1.8
    private let followCursorCameraEnabled: Bool
    private let cursorHighlightEnabled: Bool
    private let clickRingEnabled: Bool
    private let highlightRadius: CGFloat = 100
    private let highlightColor: NSColor
    private let clickRingDuration: CFTimeInterval = 0.9
    private let clickRingBaseRadius: CGFloat = 20
    private let clickRingMaxRadius: CGFloat = 90
    private let clickRingSpacing: CGFloat = 30
    private let clickRingLineWidth: CGFloat = 6
    private let clickRingColor: NSColor
    private var livePreviewEnabled: Bool
    private var activeTarget: ResolvedRecordingTarget?
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
    private let zoomProfile: ZoomProfile
    private var currentZoomScale: CGFloat
    private var currentZoomCenter: CGPoint?
    private var lastZoomUpdateTimestamp: CFTimeInterval = 0
    private var hasAppendedVideoFrame = false
    private var lastAppendedVideoPTS: CMTime?
    private var lastHandledClickEventID: UInt64 = 0
    private var lastClickTimestamp: CFTimeInterval?
    private var lastClickScreenLocation: CGPoint?
    private var clickRingStampCacheKey: ClickRingStampKey?
    private var clickRingStampCacheImage: CIImage?
    private var isFinalizing = false
    private var remainingWindowDebugLogs = 0
    private let audioVideoLeadToleranceFrames: Int64 = 3
    private let livePreviewFrameInterval: CFTimeInterval = 1.0 / 15.0
    private var lastLivePreviewTimestamp: CFTimeInterval = -.greatestFiniteMagnitude

    private struct ClickRingStampKey: Equatable {
        let progressBucket: Int
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Int
    }

    private(set) var state: RecordingState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((RecordingState) -> Void)?
    var onPreviewFrame: ((CGImage) -> Void)?

    init(
        followCursorCameraEnabled: Bool = true,
        cursorHighlightEnabled: Bool = true,
        clickRingEnabled: Bool = true,
        livePreviewEnabled: Bool = false,
        zoomScale: Double = Double(ZoomProfile.standard.zoomInScale),
        cursorHighlightColor: CGColor = RecordingService.defaultHighlightColor.cgColor,
        clickRingColor: CGColor = RecordingService.defaultClickRingColor.cgColor
    ) {
        let standardZoomProfile = ZoomProfile.standard
        self.followCursorCameraEnabled = followCursorCameraEnabled
        self.cursorHighlightEnabled = cursorHighlightEnabled
        self.clickRingEnabled = clickRingEnabled
        self.livePreviewEnabled = livePreviewEnabled
        self.zoomProfile = ZoomProfile(
            zoomInScale: CGFloat(zoomScale),
            zoomOutScale: standardZoomProfile.zoomOutScale,
            zoomInDuration: standardZoomProfile.zoomInDuration,
            zoomOutDuration: standardZoomProfile.zoomOutDuration,
            cursorFollowInDuration: standardZoomProfile.cursorFollowInDuration,
            cursorFollowOutDuration: standardZoomProfile.cursorFollowOutDuration,
            fps: standardZoomProfile.fps
        )
        self.currentZoomScale = standardZoomProfile.zoomOutScale
        self.highlightColor = Self.normalizedColor(
            from: cursorHighlightColor,
            fallback: Self.defaultHighlightColor
        )
        self.clickRingColor = Self.normalizedColor(
            from: clickRingColor,
            fallback: Self.defaultClickRingColor
        )
        super.init()
    }

    func start(
        target: ResolvedRecordingTarget,
        excludedApplications: [SCRunningApplication] = [],
        exceptingWindows: [SCWindow] = [],
        includedOverlayWindowIDs: [CGWindowID] = []
    ) async throws -> URL {
        guard case .idle = state else {
            throw RecordingError.invalidState
        }

        state = .starting

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)

            let config = SCStreamConfiguration()
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(max(1, zoomProfile.fps)))
            config.queueDepth = 5
            config.showsCursor = true
            config.capturesAudio = true
            config.excludesCurrentProcessAudio = false
            config.captureMicrophone = false
            config.sampleRate = 48_000
            config.channelCount = 2

            let filter: SCContentFilter
            let captureFrame: CGRect

            switch target {
            case .display(let displayID, let frame):
                guard let display = content.displays.first(where: { $0.displayID == displayID })
                    ?? content.displays.first else {
                    throw RecordingError.displayNotFound
                }

                let scaleFactor = await MainActor.run {
                    Self.screen(forDisplayID: display.displayID)?.backingScaleFactor ?? 2.0
                }
                let nativeSize = CGSize(
                    width: CGFloat(display.width) * scaleFactor,
                    height: CGFloat(display.height) * scaleFactor
                )
                let captureSize = Self.fittedSize(nativeSize, maxSize: outputResolution)
                config.width = max(1, Int(captureSize.width.rounded()))
                config.height = max(1, Int(captureSize.height.rounded()))
                filter = SCContentFilter(
                    display: display,
                    excludingApplications: excludedApplications,
                    exceptingWindows: exceptingWindows
                )
                captureFrame = frame

            case .window(let windowID, let windowFrame, let displayID, let displayFrame):
                guard content.windows.contains(where: { $0.windowID == windowID }) else {
                    throw RecordingError.windowNotFound
                }
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                    throw RecordingError.displayNotFound
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
                let includedWindowIDs = Set(includedOverlayWindowIDs).union([windowID])
                let includedWindows = content.windows.filter { includedWindowIDs.contains($0.windowID) }
                config.sourceRect = localRect
                let windowNativeSize = CGSize(
                    width: localRect.width * scaleFactor,
                    height: localRect.height * scaleFactor
                )
                let windowCaptureSize = Self.fittedSize(windowNativeSize, maxSize: outputResolution)
                config.width = max(1, Int(windowCaptureSize.width.rounded()))
                config.height = max(1, Int(windowCaptureSize.height.rounded()))
                filter = SCContentFilter(display: display, including: includedWindows)
                captureFrame = windowFrame

            case .region(let selection):
                guard let display = content.displays.first(where: { $0.displayID == selection.displayID }) else {
                    throw RecordingError.displayNotFound
                }
                guard let screenFrame = await MainActor.run(body: {
                    Self.screen(forDisplayID: selection.displayID)?.frame
                }) else {
                    throw RecordingError.displayNotFound
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
                config.sourceRect = localRect
                let regionNativeSize = CGSize(
                    width: localRect.width * scaleFactor,
                    height: localRect.height * scaleFactor
                )
                let regionCaptureSize = Self.fittedSize(regionNativeSize, maxSize: outputResolution)
                config.width = max(1, Int(regionCaptureSize.width.rounded()))
                config.height = max(1, Int(regionCaptureSize.height.rounded()))
                filter = SCContentFilter(
                    display: display,
                    excludingApplications: excludedApplications,
                    exceptingWindows: exceptingWindows
                )
                captureFrame = selection.rect
            }

            let outputURL = try makeOutputURL()
            let writerSize: CGSize
            switch target {
            case .display:
                writerSize = CGSize(width: config.width, height: config.height)
            case .window, .region:
                writerSize = CGSize(width: config.width, height: config.height)
            }
            let writerBundle = try makeWriter(
                outputURL: outputURL,
                width: Int(writerSize.width),
                height: Int(writerSize.height)
            )

            let stream = SCStream(filter: filter, configuration: config, delegate: self)

            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: mediaQueue)
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: mediaQueue)

            self.writer = writerBundle.writer
            self.videoInput = writerBundle.videoInput
            self.audioInput = writerBundle.audioInput
            self.pixelBufferAdaptor = writerBundle.pixelBufferAdaptor
            self.stream = stream
            self.lastOutputURL = outputURL
            self.captureDisplayFrame = captureFrame
            self.activeTarget = target
            self.remainingWindowDebugLogs = {
                if case .window = target { return 3 }
                return 0
            }()
            self.sessionStarted = false
            self.currentZoomScale = zoomProfile.zoomOutScale
            self.currentZoomCenter = nil
            self.lastZoomUpdateTimestamp = 0
            self.hasAppendedVideoFrame = false
            self.lastHandledClickEventID = 0
            self.lastClickTimestamp = nil
            self.lastClickScreenLocation = nil
            self.lastLivePreviewTimestamp = -.greatestFiniteMagnitude

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

    func setLivePreviewEnabled(_ enabled: Bool, onPreviewFrame: ((CGImage) -> Void)?) {
        livePreviewEnabled = enabled
        self.onPreviewFrame = onPreviewFrame
        if enabled {
            lastLivePreviewTimestamp = -.greatestFiniteMagnitude
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
        guard let writer, let pixelBufferAdaptor else { return }
        guard writer.status == .unknown || writer.status == .writing else { return }
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let sampleTimestamp = CMTimeGetSeconds(presentationTime)
        if !sessionStarted {
            writer.startWriting()
            writer.startSession(atSourceTime: presentationTime)
            sessionStarted = true
            lastZoomUpdateTimestamp = sampleTimestamp.isFinite ? sampleTimestamp : 0
            hasAppendedVideoFrame = false
            lastAppendedVideoPTS = nil
            currentZoomScale = zoomProfile.zoomOutScale
        }
        guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
            recordingLogger.error("Pixel buffer pool is unavailable")
            return
        }

        let sourceImage = normalizedSourceImage(from: sampleBuffer, imageBuffer: imageBuffer)
        let pointer = pointerTrackingService.snapshot
        let outputWidth = (pixelBufferAdaptor.sourcePixelBufferAttributes?[kCVPixelBufferWidthKey as String] as? Int)
            ?? CVPixelBufferGetWidth(imageBuffer)
        let outputHeight = (pixelBufferAdaptor.sourcePixelBufferAttributes?[kCVPixelBufferHeightKey as String] as? Int)
            ?? CVPixelBufferGetHeight(imageBuffer)
        let outputSize = CGSize(
            width: outputWidth,
            height: outputHeight
        )

        if !appendRenderedVideoFrame(
            sourceImage: sourceImage,
            pointer: pointer,
            outputSize: outputSize,
            presentationTime: presentationTime,
            sampleTime: sampleTimestamp,
            pixelBufferPool: pixelBufferPool,
            debugSampleBuffer: sampleBuffer
        ) {
            if writer.status == .failed {
                recordingLogger.error("Video append failed: \(writer.error?.localizedDescription ?? "unknown")")
            }
            return
        }
    }

    private func appendRenderedVideoFrame(
        sourceImage: CIImage,
        pointer: PointerSnapshot,
        outputSize: CGSize,
        presentationTime: CMTime,
        sampleTime: CFTimeInterval,
        pixelBufferPool: CVPixelBufferPool,
        debugSampleBuffer: CMSampleBuffer?
    ) -> Bool {
        guard let videoInput, let pixelBufferAdaptor else { return false }
        guard videoInput.isReadyForMoreMediaData else { return false }

        var outputPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &outputPixelBuffer)
        guard status == kCVReturnSuccess, let outputPixelBuffer else {
            recordingLogger.error("Failed to create output pixel buffer")
            return false
        }

        let transformed = applyRecordingTransform(
            to: sourceImage,
            outputSize: outputSize,
            pointer: pointer,
            sampleTime: sampleTime
        )

        if let debugSampleBuffer {
            logWindowDebugFrameIfNeeded(
                sampleBuffer: debugSampleBuffer,
                sourceImage: sourceImage,
                transformed: transformed,
                outputSize: outputSize
            )
        }

        let effectTime = sampleTime.isFinite ? sampleTime : CACurrentMediaTime()
        let effectedImage = applyCursorEffects(
            to: transformed.image,
            outputSize: outputSize,
            pointer: pointer,
            cursorPoint: transformed.cursorPoint,
            clickPoint: transformed.clickPoint,
            sourceRect: transformed.sourceRect,
            imageExtent: transformed.imageExtent,
            now: effectTime
        )
        let renderBounds = CGRect(origin: .zero, size: outputSize)
        ciContext.render(effectedImage, to: outputPixelBuffer, bounds: renderBounds, colorSpace: CGColorSpaceCreateDeviceRGB())
        emitLivePreviewFrameIfNeeded(image: effectedImage, bounds: renderBounds, sampleTime: sampleTime)

        guard pixelBufferAdaptor.append(outputPixelBuffer, withPresentationTime: presentationTime) else {
            return false
        }

        hasAppendedVideoFrame = true
        lastAppendedVideoPTS = presentationTime
        return true
    }

    private func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard sessionStarted else { return }
        guard let writer, let audioInput else { return }
        guard writer.status == .writing else { return }
        guard audioInput.isReadyForMoreMediaData else { return }
        let audioPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let lastVideoPTS = lastAppendedVideoPTS {
            let tolerance = CMTime(
                value: audioVideoLeadToleranceFrames,
                timescale: CMTimeScale(max(1, zoomProfile.fps))
            )
            let maxAllowedAudioPTS = CMTimeAdd(lastVideoPTS, tolerance)
            if CMTimeCompare(audioPTS, maxAllowedAudioPTS) == 1 {
                return
            }
        }

        if !audioInput.append(sampleBuffer), writer.status == .failed {
            recordingLogger.error("Audio append failed: \(writer.error?.localizedDescription ?? "unknown")")
        }
    }

    private func emitLivePreviewFrameIfNeeded(image: CIImage, bounds: CGRect, sampleTime: CFTimeInterval) {
        guard livePreviewEnabled, let onPreviewFrame else { return }
        guard sampleTime.isFinite else { return }
        guard (sampleTime - lastLivePreviewTimestamp) >= livePreviewFrameInterval else { return }
        guard let cgImage = ciContext.createCGImage(image, from: bounds) else { return }

        lastLivePreviewTimestamp = sampleTime
        DispatchQueue.main.async {
            onPreviewFrame(cgImage)
        }
    }

    private func logWindowDebugFrameIfNeeded(
        sampleBuffer: CMSampleBuffer,
        sourceImage: CIImage,
        transformed: TransformResult,
        outputSize: CGSize
    ) {
        guard remainingWindowDebugLogs > 0 else { return }
        guard case .window(let windowID, let windowFrame, _, _) = activeTarget else { return }

        remainingWindowDebugLogs -= 1
        let attachments = sampleBufferAttachments(from: sampleBuffer)
        let contentRectText = attachments.contentRect.map(Self.rectDescription) ?? "nil"
        let screenRectText = attachments.screenRect.map(Self.rectDescription) ?? "nil"
        let contentScaleText = attachments.contentScale.map { String(format: "%.3f", $0) } ?? "nil"
        let scaleFactorText = attachments.scaleFactor.map { String(format: "%.3f", $0) } ?? "nil"

        recordingLogger.info(
            """
            WindowDebug windowID=\(windowID) windowFrame=\(Self.rectDescription(windowFrame)) \
            captureDisplayFrame=\(Self.rectDescription(self.captureDisplayFrame)) sourceExtent=\(Self.rectDescription(sourceImage.extent)) \
            imageExtent=\(Self.rectDescription(transformed.imageExtent)) sourceRect=\(Self.rectDescription(transformed.sourceRect)) \
            outputSize=\(Self.sizeDescription(outputSize)) contentRect=\(contentRectText) screenRect=\(screenRectText) \
            contentScale=\(contentScaleText) scaleFactor=\(scaleFactorText)
            """
        )
    }

    private func sampleBufferAttachments(from sampleBuffer: CMSampleBuffer) -> (
        contentRect: CGRect?,
        screenRect: CGRect?,
        contentScale: Double?,
        scaleFactor: Double?
    ) {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let attachments = attachmentsArray.first else {
            return (nil, nil, nil, nil)
        }

        return (
            rectValue(from: attachments[.contentRect]),
            rectValue(from: attachments[.screenRect]),
            doubleValue(from: attachments[.contentScale]),
            doubleValue(from: attachments[.scaleFactor])
        )
    }

    private func rectValue(from value: Any?) -> CGRect? {
        guard let value else { return nil }
        if let rect = value as? CGRect {
            return rect
        }
        if let dictionary = value as? NSDictionary {
            return CGRect(dictionaryRepresentation: dictionary)
        }
        return nil
    }

    private func doubleValue(from value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let value = value as? Double {
            return value
        }
        if let value = value as? CGFloat {
            return Double(value)
        }
        return nil
    }

    private static func rectDescription(_ rect: CGRect) -> String {
        String(format: "(x:%.2f y:%.2f w:%.2f h:%.2f)", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height)
    }

    private static func sizeDescription(_ size: CGSize) -> String {
        String(format: "(w:%.2f h:%.2f)", size.width, size.height)
    }

    private func normalizedSourceImage(from sampleBuffer: CMSampleBuffer, imageBuffer: CVImageBuffer) -> CIImage {
        let image = CIImage(cvPixelBuffer: imageBuffer)
        let attachments = sampleBufferAttachments(from: sampleBuffer)
        guard let contentRect = attachments.contentRect else {
            return image
        }

        let scaleFactor = CGFloat(attachments.scaleFactor ?? 1.0)
        let pixelContentRect = CGRect(
            x: contentRect.origin.x * scaleFactor,
            y: contentRect.origin.y * scaleFactor,
            width: contentRect.size.width * scaleFactor,
            height: contentRect.size.height * scaleFactor
        )

        let translatedImage = image
            .cropped(to: pixelContentRect)
            .transformed(by: CGAffineTransform(translationX: -pixelContentRect.origin.x, y: -pixelContentRect.origin.y))

        return translatedImage
    }

    private typealias TransformResult = (
        image: CIImage,
        cursorPoint: CGPoint?,
        clickPoint: CGPoint?,
        sourceRect: CGRect,
        imageExtent: CGRect
    )

    private func applyRecordingTransform(
        to image: CIImage,
        outputSize: CGSize,
        pointer: PointerSnapshot,
        sampleTime: CFTimeInterval
    ) -> TransformResult {
        if case .window = activeTarget, !pointer.isZoomActive, !followCursorCameraEnabled {
            let extent = image.extent
            let cursor = outputCursorPoint(for: pointer.cursorLocation, imageExtent: extent, sourceRect: extent, outputSize: outputSize)
            let clickPoint = pointer.lastClickLocation.flatMap {
                outputCursorPoint(for: $0, imageExtent: extent, sourceRect: extent, outputSize: outputSize)
            }
            return (image, cursor, clickPoint, extent, extent)
        }

        if followCursorCameraEnabled {
            return applyFollowCursorCamera(
                to: image,
                outputSize: outputSize,
                pointer: pointer,
                sampleTime: sampleTime
            )
        }
        return applyClassicRecordingZoom(
            to: image,
            outputSize: outputSize,
            pointer: pointer,
            sampleTime: sampleTime
        )
    }

    private func applyClassicRecordingZoom(
        to image: CIImage,
        outputSize: CGSize,
        pointer: PointerSnapshot,
        sampleTime: CFTimeInterval
    ) -> TransformResult {
        let extent = image.extent
        guard !captureDisplayFrame.isEmpty, outputSize.width > 0, outputSize.height > 0 else {
            return (image, nil, nil, extent, extent)
        }

        let targetLocation = pointer.cursorLocation
        let shouldZoom = pointer.isZoomActive && captureDisplayFrame.contains(targetLocation)
        let targetScale: CGFloat = shouldZoom
            ? zoomProfile.zoomInScale
            : zoomProfile.zoomOutScale

        let elapsed = zoomElapsed(for: sampleTime)
        let zoomDuration = shouldZoom ? zoomProfile.zoomInDuration : zoomProfile.zoomOutDuration
        currentZoomScale = smoothValue(
            currentZoomScale,
            toward: targetScale,
            elapsed: elapsed,
            duration: zoomDuration
        )

        if shouldZoom {
            let initialCenter = currentZoomCenter ?? pointer.zoomAnchorLocation.map {
                convertScreenPointToImagePoint($0, imageExtent: extent)
            } ?? convertScreenPointToImagePoint(targetLocation, imageExtent: extent)
            currentZoomCenter = smoothPoint(
                initialCenter,
                toward: convertScreenPointToImagePoint(targetLocation, imageExtent: extent),
                elapsed: elapsed,
                duration: zoomProfile.cursorFollowInDuration
            )
        }

        let effectiveScale = max(zoomProfile.zoomOutScale, currentZoomScale)
        guard shouldZoom || effectiveScale > (zoomProfile.zoomOutScale + 0.001) else {
            currentZoomCenter = nil
            let cursor = outputCursorPoint(for: targetLocation, imageExtent: extent, sourceRect: extent, outputSize: outputSize)
            let clickPoint = pointer.lastClickLocation.flatMap {
                outputCursorPoint(for: $0, imageExtent: extent, sourceRect: extent, outputSize: outputSize)
            }
            return (image, cursor, clickPoint, extent, extent)
        }
        guard let zoomCenter = currentZoomCenter else {
            return (image, nil, nil, extent, extent)
        }

        let zoomedWidth = extent.width / effectiveScale
        let zoomedHeight = extent.height / effectiveScale
        let clampedX = min(max(zoomCenter.x - (zoomedWidth / 2), extent.minX), extent.maxX - zoomedWidth)
        let clampedY = min(max(zoomCenter.y - (zoomedHeight / 2), extent.minY), extent.maxY - zoomedHeight)
        let cropRect = CGRect(x: clampedX, y: clampedY, width: zoomedWidth, height: zoomedHeight)

        let transformedImage = renderedImage(image, from: cropRect, outputSize: outputSize)
        let cursor = outputCursorPoint(for: targetLocation, imageExtent: extent, sourceRect: cropRect, outputSize: outputSize)
        let clickPoint = pointer.lastClickLocation.flatMap {
            outputCursorPoint(for: $0, imageExtent: extent, sourceRect: cropRect, outputSize: outputSize)
        }
        return (transformedImage, cursor, clickPoint, cropRect, extent)
    }

    private func applyFollowCursorCamera(
        to image: CIImage,
        outputSize: CGSize,
        pointer: PointerSnapshot,
        sampleTime: CFTimeInterval
    ) -> TransformResult {
        let extent = image.extent
        guard !captureDisplayFrame.isEmpty, outputSize.width > 0, outputSize.height > 0 else {
            return (image, nil, nil, extent, extent)
        }

        let targetLocation = pointer.cursorLocation
        let shouldZoom = pointer.isZoomActive
        let targetScale: CGFloat = shouldZoom
            ? zoomProfile.zoomInScale
            : zoomProfile.zoomOutScale

        let elapsed = zoomElapsed(for: sampleTime)
        let zoomDuration = shouldZoom ? zoomProfile.zoomInDuration : zoomProfile.zoomOutDuration
        currentZoomScale = smoothValue(
            currentZoomScale,
            toward: targetScale,
            elapsed: elapsed,
            duration: zoomDuration
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
            ? zoomProfile.cursorFollowInDuration
            : max(zoomProfile.cursorFollowOutDuration * idlePanDurationMultiplier, 0.24)
        currentZoomCenter = smoothPoint(
            initialCenter,
            toward: targetCenter,
            elapsed: elapsed,
            duration: panDuration
        )

        guard let zoomCenter = currentZoomCenter else {
            return (image, nil, nil, extent, extent)
        }

        let effectiveScale = shouldZoom
            ? max(0.01, currentZoomScale)
            : max(idleFollowMinimumScale, currentZoomScale * idleCameraScale)
        let zoomedWidth = min(baseCropSize.width / effectiveScale, extent.width)
        let zoomedHeight = min(baseCropSize.height / effectiveScale, extent.height)
        let cropCenterX = zoomedWidth >= extent.width ? extent.midX : zoomCenter.x
        let cropCenterY = zoomedHeight >= extent.height ? extent.midY : zoomCenter.y
        let minX = extent.minX
        let minY = extent.minY
        let maxX = extent.maxX - zoomedWidth
        let maxY = extent.maxY - zoomedHeight

        let clampedX = min(max(cropCenterX - (zoomedWidth / 2), minX), maxX)
        let clampedY = min(max(cropCenterY - (zoomedHeight / 2), minY), maxY)
        let cropRect = CGRect(x: clampedX, y: clampedY, width: zoomedWidth, height: zoomedHeight)
            .intersection(extent)
        let transformedImage = renderedImage(image, from: cropRect, outputSize: outputSize)
        let cursor = outputCursorPoint(for: targetLocation, imageExtent: extent, sourceRect: cropRect, outputSize: outputSize)
        let clickPoint = pointer.lastClickLocation.flatMap {
            outputCursorPoint(for: $0, imageExtent: extent, sourceRect: cropRect, outputSize: outputSize)
        }
        return (transformedImage, cursor, clickPoint, cropRect, extent)
    }

    private func applyCursorEffects(
        to image: CIImage,
        outputSize: CGSize,
        pointer: PointerSnapshot,
        cursorPoint: CGPoint?,
        clickPoint: CGPoint?,
        sourceRect: CGRect,
        imageExtent: CGRect,
        now: CFTimeInterval
    ) -> CIImage {
        if pointer.lastClickEventID > 0, pointer.lastClickEventID != lastHandledClickEventID {
            lastHandledClickEventID = pointer.lastClickEventID
            if let clickLocation = pointer.lastClickLocation {
                lastClickTimestamp = now
                lastClickScreenLocation = clickLocation
            } else {
                lastClickTimestamp = nil
                lastClickScreenLocation = nil
            }
        }

        var output = image
        let outputRect = CGRect(origin: .zero, size: outputSize)
        var ringProgress: CGFloat?
        if clickRingEnabled, self.lastClickTimestamp != nil {
            let holdProgress: CGFloat = 1.0
            if pointer.isPrimaryButtonPressed {
                ringProgress = holdProgress
            } else {
                self.lastClickTimestamp = nil
                self.lastClickScreenLocation = nil
            }
        }
        let isRingActive = (ringProgress != nil)

        if cursorHighlightEnabled, let cursorPoint {
            let highlightAlphaMultiplier: CGFloat = isRingActive ? 0.75 : 1.0
            let effectiveHighlightColor = CIColor(
                red: highlightColor.redComponent,
                green: highlightColor.greenComponent,
                blue: highlightColor.blueComponent,
                alpha: highlightColor.alphaComponent * highlightAlphaMultiplier
            )
            let highlight = makeRadialGradientImage(
                center: cursorPoint,
                radius: highlightRadius,
                color: effectiveHighlightColor,
                outputRect: outputRect
            )
            output = highlight.composited(over: output)
        }

        let resolvedClickPoint = clickPoint ?? lastClickScreenLocation.flatMap {
            outputCursorPoint(
                for: $0,
                imageExtent: imageExtent,
                sourceRect: sourceRect,
                outputSize: outputSize
            )
        } ?? clickPoint ?? cursorPoint

        if let progress = ringProgress,
           let clickPoint = resolvedClickPoint,
           let ringOverlay = makeClickRingOverlayImage(
            outputSize: outputSize,
            center: clickPoint,
            progress: progress
           ) {
            output = ringOverlay.composited(over: output)
        }

        return output
    }

    private func makeRadialGradientImage(
        center: CGPoint,
        radius: CGFloat,
        color: CIColor,
        outputRect: CGRect
    ) -> CIImage {
        let transparent = CIColor(red: color.red, green: color.green, blue: color.blue, alpha: 0)
        let filter = CIFilter(
            name: "CIRadialGradient",
            parameters: [
                "inputCenter": CIVector(cgPoint: center),
                "inputRadius0": 0,
                "inputRadius1": radius,
                "inputColor0": color,
                "inputColor1": transparent
            ]
        )
        return (filter?.outputImage ?? CIImage(color: .clear)).cropped(to: outputRect)
    }

    private func makeClickRingOverlayImage(
        outputSize: CGSize,
        center: CGPoint,
        progress: CGFloat
    ) -> CIImage? {
        guard let stamp = clickRingStampImage(progress: progress) else { return nil }
        let translated = stamp.transformed(
            by: CGAffineTransform(
                translationX: center.x - (stamp.extent.width / 2),
                y: center.y - (stamp.extent.height / 2)
            )
        )
        return translated.cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    private func clickRingStampImage(progress: CGFloat) -> CIImage? {
        let fade = max(0.45, 1 - progress)
        let radius = clickRingBaseRadius + ((clickRingMaxRadius - clickRingBaseRadius) * progress)
        let innerRadius = max(1, radius - clickRingSpacing)
        let ringColor = NSColor(
            deviceRed: clickRingColor.redComponent,
            green: clickRingColor.greenComponent,
            blue: clickRingColor.blueComponent,
            alpha: clickRingColor.alphaComponent * fade
        )
        .cgColor

        let ringNSColor = NSColor(cgColor: ringColor)?.usingColorSpace(.deviceRGB) ?? .white
        let key = ClickRingStampKey(
            progressBucket: Int((progress * 1000).rounded()),
            red: Int((ringNSColor.redComponent * 1000).rounded()),
            green: Int((ringNSColor.greenComponent * 1000).rounded()),
            blue: Int((ringNSColor.blueComponent * 1000).rounded()),
            alpha: Int((ringNSColor.alphaComponent * 1000).rounded())
        )
        if key == clickRingStampCacheKey, let cached = clickRingStampCacheImage {
            return cached
        }

        let outerRadius = max(radius, innerRadius) + clickRingLineWidth + 2
        let stampDiameter = max(1, Int((outerRadius * 2).rounded(.up)))
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        guard let context = CGContext(
            data: nil,
            width: stampDiameter,
            height: stampDiameter,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.clear(CGRect(x: 0, y: 0, width: stampDiameter, height: stampDiameter))
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        context.setLineWidth(clickRingLineWidth)
        context.setBlendMode(.normal)
        let centerPoint = CGPoint(x: CGFloat(stampDiameter) / 2, y: CGFloat(stampDiameter) / 2)

        context.setStrokeColor(ringColor)
        context.strokeEllipse(
            in: CGRect(
                x: centerPoint.x - radius,
                y: centerPoint.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )

        context.setStrokeColor(ringColor)
        context.strokeEllipse(
            in: CGRect(
                x: centerPoint.x - innerRadius,
                y: centerPoint.y - innerRadius,
                width: innerRadius * 2,
                height: innerRadius * 2
            )
        )

        guard let cgImage = context.makeImage() else { return nil }
        let stampRect = CGRect(x: 0, y: 0, width: stampDiameter, height: stampDiameter)
        let stampImage = CIImage(cgImage: cgImage).cropped(to: stampRect)
        clickRingStampCacheKey = key
        clickRingStampCacheImage = stampImage
        return stampImage
    }

    private static func normalizedColor(from color: CGColor, fallback: NSColor) -> NSColor {
        NSColor(cgColor: color)?.usingColorSpace(.deviceRGB) ?? fallback
    }

    private static func screen(forDisplayID displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first(where: { $0.displayID == displayID })
    }

    private static func screen(containing frame: CGRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) {
            return screen
        }
        return NSScreen.screens.first(where: { $0.frame.intersects(frame) })
    }

    private static func fittedSize(_ size: CGSize, maxSize: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0, maxSize.width > 0, maxSize.height > 0 else {
            return maxSize
        }
        let ratio = min(maxSize.width / size.width, maxSize.height / size.height, 1.0)
        return CGSize(width: size.width * ratio, height: size.height * ratio)
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

    private func outputCursorPoint(
        for screenPoint: CGPoint,
        imageExtent: CGRect,
        sourceRect: CGRect,
        outputSize: CGSize
    ) -> CGPoint? {
        guard captureDisplayFrame.contains(screenPoint) else { return nil }
        guard sourceRect.width > 0, sourceRect.height > 0, outputSize.width > 0, outputSize.height > 0 else {
            return nil
        }

        let imagePoint = convertScreenPointToImagePoint(screenPoint, imageExtent: imageExtent)
        let mappedX = (imagePoint.x - sourceRect.minX) * (outputSize.width / sourceRect.width)
        let mappedY = (imagePoint.y - sourceRect.minY) * (outputSize.height / sourceRect.height)
        return CGPoint(
            x: min(max(mappedX, 0), outputSize.width),
            y: min(max(mappedY, 0), outputSize.height)
        )
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

    private func zoomElapsed(for sampleTime: CFTimeInterval) -> CFTimeInterval {
        let timelineTime = sampleTime.isFinite ? sampleTime : CACurrentMediaTime()
        guard lastZoomUpdateTimestamp > 0 else {
            lastZoomUpdateTimestamp = timelineTime
            return 0
        }

        let elapsed = max(0, timelineTime - lastZoomUpdateTimestamp)
        lastZoomUpdateTimestamp = timelineTime
        let frameDuration = 1.0 / Double(max(1, zoomProfile.fps))
        return min(elapsed, frameDuration * 3.0)
    }

    private func renderedImage(_ image: CIImage, from sourceRect: CGRect, outputSize: CGSize) -> CIImage {
        let translated = image
            .cropped(to: sourceRect)
            .transformed(by: CGAffineTransform(translationX: -sourceRect.origin.x, y: -sourceRect.origin.y))
        let scaled = translated.transformed(by: CGAffineTransform(
            scaleX: outputSize.width / sourceRect.width,
            y: outputSize.height / sourceRect.height
        ))
        return scaled.cropped(to: CGRect(origin: .zero, size: outputSize))
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
            if !hasAppendedVideoFrame, let writer {
                writer.cancelWriting()
                try? FileManager.default.removeItem(at: outputURL)
                throw RecordingError.noVideoFrame
            }
            if let writer, let lastVideoPTS = lastAppendedVideoPTS, lastVideoPTS.isValid {
                writer.endSession(atSourceTime: lastVideoPTS)
            }
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
        activeTarget = nil
        remainingWindowDebugLogs = 0
        sessionStarted = false
        captureDisplayFrame = .zero
        currentZoomScale = zoomProfile.zoomOutScale
        currentZoomCenter = nil
        lastZoomUpdateTimestamp = 0
        hasAppendedVideoFrame = false
        lastAppendedVideoPTS = nil
        lastHandledClickEventID = 0
        lastClickTimestamp = nil
        lastClickScreenLocation = nil
        clickRingStampCacheKey = nil
        clickRingStampCacheImage = nil
        isFinalizing = false
        lastLivePreviewTimestamp = -.greatestFiniteMagnitude
        onPreviewFrame = nil
    }

    private func makeOutputURL() throws -> URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Movies", isDirectory: true)

        let directory = movies.appendingPathComponent("ScreenSeal_plus", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "ScreenSeal_plus-\(formatter.string(from: Date())).mp4"
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
    case windowNotFound
    case writerConfigurationFailed
    case writerFailed(String)
    case noVideoFrame
}
