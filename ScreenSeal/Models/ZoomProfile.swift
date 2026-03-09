import CoreGraphics
import Foundation

struct ZoomProfile {
    let zoomInScale: CGFloat
    let zoomOutScale: CGFloat
    let zoomInDuration: TimeInterval
    let zoomOutDuration: TimeInterval
    let cursorFollowInDuration: TimeInterval
    let cursorFollowOutDuration: TimeInterval
    let fps: Int

    static let standard = ZoomProfile(
        zoomInScale: 1.8,
        zoomOutScale: 1.0,
        zoomInDuration: 0.18,
        zoomOutDuration: 0.22,
        cursorFollowInDuration: 0.13,
        cursorFollowOutDuration: 0.17,
        fps: 60
    )
}
