import AppKit
import Foundation

struct PointerSnapshot {
    let cursorLocation: CGPoint
    let isPrimaryButtonPressed: Bool
}

final class PointerTrackingService {
    private let fps: Int
    private let stateQueue = DispatchQueue(label: "com.screenseal.pointer.state")
    private var timer: Timer?
    private var cursorLocation: CGPoint = .zero
    private var isPrimaryButtonPressed = false

    init(fps: Int = ZoomProfile.standard.fps) {
        self.fps = max(1, fps)
    }

    func start() {
        guard timer == nil else { return }

        let interval = 1.0 / Double(fps)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let location = NSEvent.mouseLocation
            let pressed = (NSEvent.pressedMouseButtons & 0x1) != 0

            self.stateQueue.async {
                self.cursorLocation = location
                self.isPrimaryButtonPressed = pressed
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    var snapshot: PointerSnapshot {
        stateQueue.sync {
            PointerSnapshot(
                cursorLocation: cursorLocation,
                isPrimaryButtonPressed: isPrimaryButtonPressed
            )
        }
    }
}
