import AppKit
import ApplicationServices
import Foundation

struct PointerSnapshot {
    let cursorLocation: CGPoint
    let isPrimaryButtonPressed: Bool
    let zoomAnchorLocation: CGPoint?
    let isZoomActive: Bool
    let lastClickEventID: UInt64
    let lastClickLocation: CGPoint?
}

final class PointerTrackingService {
    private let topSystemUIExclusionHeight: CGFloat = 64
    private let fps: Int
    private let stateQueue = DispatchQueue(label: "com.screenseal.pointer.state")
    private var timer: Timer?
    private var globalMouseDownMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var cursorLocationState: CGPoint = .zero
    private var isPrimaryButtonPressedState = false
    private var zoomAnchorLocationState: CGPoint?
    private var isZoomActiveState = false
    private var lastClickEventIDState: UInt64 = 0
    private var lastClickLocationState: CGPoint?
    private var zoomAnchorLocation: CGPoint?
    private var isZoomActive = false
    private var lastClickEventID: UInt64 = 0
    private var lastClickLocation: CGPoint?
    private var previousPrimaryButtonPressed = false
    private var zoomReleaseDeadline: CFTimeInterval = 0
    private let zoomReleaseDelay: CFTimeInterval = 0.9

    init(fps: Int = ZoomProfile.standard.fps) {
        self.fps = max(1, fps)
    }

    func start() {
        guard timer == nil else { return }
        installMouseMonitors()

        let interval = 1.0 / Double(fps)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let location = NSEvent.mouseLocation
            let pressed = (NSEvent.pressedMouseButtons & 0x1) != 0
            let now = CACurrentMediaTime()

            if pressed {
                if !previousPrimaryButtonPressed && zoomAnchorLocation == nil {
                    if shouldTriggerZoom(at: location) {
                        zoomAnchorLocation = location
                        zoomReleaseDeadline = 0
                    } else {
                        zoomAnchorLocation = nil
                        zoomReleaseDeadline = 0
                    }
                }
            } else if !pressed && previousPrimaryButtonPressed, zoomAnchorLocation != nil, zoomReleaseDeadline == 0 {
                zoomReleaseDeadline = now + zoomReleaseDelay
            }

            if pressed {
                isZoomActive = (zoomAnchorLocation != nil)
            } else if zoomAnchorLocation != nil {
                if now < zoomReleaseDeadline {
                    isZoomActive = true
                } else {
                    isZoomActive = false
                    zoomAnchorLocation = nil
                    zoomReleaseDeadline = 0
                }
            } else {
                isZoomActive = false
            }

            previousPrimaryButtonPressed = pressed
            let anchor = zoomAnchorLocation
            let active = isZoomActive
            self.stateQueue.sync {
                self.cursorLocationState = location
                self.isPrimaryButtonPressedState = pressed
                self.zoomAnchorLocationState = anchor
                self.isZoomActiveState = active
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        removeMouseMonitors()
        previousPrimaryButtonPressed = false
        zoomReleaseDeadline = 0
        zoomAnchorLocation = nil
        isZoomActive = false
        lastClickEventID = 0
        lastClickLocation = nil
    }

    var snapshot: PointerSnapshot {
        stateQueue.sync {
            PointerSnapshot(
                cursorLocation: cursorLocationState,
                isPrimaryButtonPressed: isPrimaryButtonPressedState,
                zoomAnchorLocation: zoomAnchorLocationState,
                isZoomActive: isZoomActiveState,
                lastClickEventID: lastClickEventIDState,
                lastClickLocation: lastClickLocationState
            )
        }
    }

    private func shouldTriggerZoom(at location: CGPoint) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(location.x), Float(location.y), &element)
        guard result == .success, let element else { return false }
        if isMenuBarInteraction(location: location, element: element) {
            return false
        }

        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        if pid == ProcessInfo.processInfo.processIdentifier {
            return false
        }

        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else { return false }
        if frontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }

        guard let elementApp = NSRunningApplication(processIdentifier: pid),
              belongsToFrontmostApp(elementApp: elementApp, frontmostApp: frontmostApp) else {
            return false
        }

        return isInteractiveElement(element)
    }

    private func isMenuBarInteraction(location: CGPoint, element: AXUIElement) -> Bool {
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) {
            let exclusionHeight = max(NSStatusBar.system.thickness, topSystemUIExclusionHeight)
            let menuBarBandMinY = screen.frame.maxY - exclusionHeight
            if location.y >= menuBarBandMinY {
                return true
            }
        }

        var current: AXUIElement? = element
        for _ in 0..<8 {
            guard let target = current else { break }
            if isMenuRelatedRole(target) {
                return true
            }
            current = parentElement(of: target)
        }
        return false
    }

    private func isMenuRelatedRole(_ element: AXUIElement) -> Bool {
        let role = attributeString(kAXRoleAttribute as CFString, element: element)
        let subrole = attributeString(kAXSubroleAttribute as CFString, element: element)

        if role == "AXMenuBar" || role == "AXMenuBarItem" || role == "AXMenu" || role == "AXMenuItem" {
            return true
        }

        if subrole == "AXMenuExtra" || subrole == "AXSystemDialog" {
            return true
        }

        return false
    }

    private func isInteractiveElement(_ element: AXUIElement) -> Bool {
        var current: AXUIElement? = element
        for _ in 0..<8 {
            guard let target = current else { return false }
            if hasAllowedRole(target) {
                return true
            }
            current = parentElement(of: target)
        }
        return false
    }

    private func hasAllowedRole(_ element: AXUIElement) -> Bool {
        guard let role = attributeString(kAXRoleAttribute as CFString, element: element) else {
            return false
        }

        if role == (kAXButtonRole as String) || role == "AXLink" {
            return true
        }

        if role == "AXMenuItem" || role == "AXPopUpButton" {
            return true
        }

        if let subrole = attributeString(kAXSubroleAttribute as CFString, element: element),
           subrole == "AXLink" {
            return true
        }

        if hasURLAttribute(element) {
            return true
        }

        // Some apps expose clickable image links as AXImage with press action.
        if (role == (kAXImageRole as String) || role == "AXGroup") && hasPressAction(element) {
            return true
        }

        return false
    }

    private func hasPressAction(_ element: AXUIElement) -> Bool {
        var actionsValue: CFArray?
        let result = AXUIElementCopyActionNames(element, &actionsValue)
        guard result == .success, let actions = actionsValue as? [String] else {
            return false
        }
        return actions.contains(kAXPressAction as String)
    }

    private func parentElement(of element: AXUIElement) -> AXUIElement? {
        var parentValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentValue)
        guard result == .success, let parentValue else { return nil }
        guard CFGetTypeID(parentValue) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(parentValue, to: AXUIElement.self)
    }

    private func attributeString(_ name: CFString, element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name, &value)
        guard result == .success else { return nil }
        return value as? String
    }

    private func hasURLAttribute(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &value)
        return result == .success && value != nil
    }

    private func belongsToFrontmostApp(elementApp: NSRunningApplication, frontmostApp: NSRunningApplication) -> Bool {
        guard let frontBundleID = frontmostApp.bundleIdentifier,
              let elementBundleID = elementApp.bundleIdentifier else {
            return false
        }

        if elementBundleID == frontBundleID {
            return true
        }

        // Browser/Electron helper processes often expose accessibility elements.
        if elementBundleID.hasPrefix(frontBundleID + ".") {
            return true
        }

        if frontBundleID.hasPrefix(elementBundleID + ".") {
            return true
        }

        return false
    }

    private func installMouseMonitors() {
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            self?.handleMouseDown(at: self?.screenLocation(from: event) ?? .zero)
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.handleMouseUp()
        }

        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            self?.handleMouseDown(at: self?.screenLocation(from: event) ?? .zero)
            return event
        }

        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            self?.handleMouseUp()
            return event
        }
    }

    private func removeMouseMonitors() {
        if let globalMouseDownMonitor {
            NSEvent.removeMonitor(globalMouseDownMonitor)
            self.globalMouseDownMonitor = nil
        }
        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }
        if let localMouseDownMonitor {
            NSEvent.removeMonitor(localMouseDownMonitor)
            self.localMouseDownMonitor = nil
        }
        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
            self.localMouseUpMonitor = nil
        }
    }

    private func handleMouseDown(at location: CGPoint) {
        let shouldRing = shouldShowClickRing(at: location)
        lastClickEventID &+= 1
        lastClickLocation = shouldRing ? location : nil

        if shouldTriggerZoom(at: location) {
            zoomAnchorLocation = location
            isZoomActive = true
            zoomReleaseDeadline = 0
        } else {
            zoomAnchorLocation = nil
            isZoomActive = false
            zoomReleaseDeadline = 0
        }

        // Reflect click immediately so recording thread does not wait for timer tick.
        let clickEventID = lastClickEventID
        let clickLocation = lastClickLocation
        stateQueue.sync {
            self.cursorLocationState = location
            self.isPrimaryButtonPressedState = true
            self.zoomAnchorLocationState = zoomAnchorLocation
            self.isZoomActiveState = isZoomActive
            self.lastClickEventIDState = clickEventID
            self.lastClickLocationState = clickLocation
        }
    }

    private func shouldShowClickRing(at location: CGPoint) -> Bool {
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(location) }) {
            let exclusionHeight = max(NSStatusBar.system.thickness, topSystemUIExclusionHeight)
            if location.y >= (screen.frame.maxY - exclusionHeight) {
                return false
            }
        }

        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }

        return true
    }

    private func handleMouseUp() {
        guard zoomAnchorLocation != nil else { return }
        zoomReleaseDeadline = CACurrentMediaTime() + zoomReleaseDelay
    }

    private func screenLocation(from _: NSEvent) -> CGPoint {
        return NSEvent.mouseLocation
    }

}
