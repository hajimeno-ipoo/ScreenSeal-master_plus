import CoreGraphics
import Foundation

struct ZoomProfile {
    let zoomInScale: CGFloat
    let zoomOutScale: CGFloat
    let easingDuration: TimeInterval
    let fps: Int

    static let standard = ZoomProfile(
        zoomInScale: 1.8,
        zoomOutScale: 1.0,
        easingDuration: 0.18,
        fps: 30
    )
}
