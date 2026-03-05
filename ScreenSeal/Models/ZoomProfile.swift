import CoreGraphics
import Foundation

struct ZoomProfile {
    let zoomInScale: CGFloat
    let zoomOutScale: CGFloat
    let easingDuration: TimeInterval
    let cursorFollowDuration: TimeInterval
    let fps: Int

    static let standard = ZoomProfile(
        zoomInScale: 1.8,
        zoomOutScale: 1.0,
        easingDuration: 0.18,
        cursorFollowDuration: 0.12,
        fps: 30
    )
}
