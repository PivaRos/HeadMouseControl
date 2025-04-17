// AppDelegate.swift

import Cocoa
import CoreMotion

extension Notification.Name {
    static let headMouseCalibrate          = Notification.Name("HeadMouseControlCalibrate")
    static let headMouseSensitivityChanged = Notification.Name("HeadMouseControlSensitivityChanged")
}

class AppDelegate: NSObject, NSApplicationDelegate, CMHeadphoneMotionManagerDelegate {
    // MARK: – Motion & State
    private let motionManager = CMHeadphoneMotionManager()
    private let queue = OperationQueue()
    private var currentMotion: CMDeviceMotion?

    /// whether we should control the cursor by head motion
    private var isHeadControlEnabled = false

    // MARK: – Calibration
    private var calibrationYaw:   Double = 0
    private var calibrationPitch: Double = 0
    private var isCalibrated = false

    // MARK: – Sensitivity (range in radians)
    private var yawRange:   Double = 40 * .pi / 180  // default 40°
    private var pitchRange: Double = 30 * .pi / 180  // default 30°

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🔥 AppDelegate didFinishLaunching")

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleCalibrateNotification),
                                               name: .headMouseCalibrate,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleSensitivityChange(_:)),
                                               name: .headMouseSensitivityChanged,
                                               object: nil)

        guard motionManager.isDeviceMotionAvailable else {
            print("❌ Headphone motion not available")
            return
        }

        motionManager.delegate = self
        // begin listening for connect/disconnect events
        motionManager.startConnectionStatusUpdates()

        // register key monitors for toggling head control (⌘⇧H)
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.maybeHandleToggleEvent(event)
            return event
        }
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.maybeHandleToggleEvent(event)
        }
    }

    // MARK: – CMHeadphoneMotionManagerDelegate

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        print("✅ AirPods connected — starting motion updates")
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            self.currentMotion = motion

            DispatchQueue.main.async {
                print("🎧 Motion — yaw: \(motion.attitude.yaw), pitch: \(motion.attitude.pitch)")
                guard self.isCalibrated else { return }
                self.updateCursor(using: motion)
            }
        }
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        print("❌ AirPods disconnected — stopping motion updates")
        manager.stopDeviceMotionUpdates()
    }

    // MARK: – Calibration Handler

    @objc private func handleCalibrateNotification() {
        guard let motion = currentMotion else {
            print("⚠️ No motion data yet. Move your head around first!")
            return
        }
        calibrationYaw   = motion.attitude.yaw
        calibrationPitch = motion.attitude.pitch
        isCalibrated     = true
        print("🎯 Calibrated — yaw: \(calibrationYaw), pitch: \(calibrationPitch)")
    }

    // MARK: – Sensitivity Handler

    @objc private func handleSensitivityChange(_ notification: Notification) {
        guard let info   = notification.userInfo,
              let yawDeg   = info["yawRange"]   as? Double,
              let pitchDeg = info["pitchRange"] as? Double
        else { return }

        yawRange   = yawDeg   * .pi / 180
        pitchRange = pitchDeg * .pi / 180
        print("🔧 Sensitivity updated — yawRange: \(yawDeg)°, pitchRange: \(pitchDeg)°")
    }

    // MARK: – Cursor Movement

    private func updateCursor(using motion: CMDeviceMotion) {
        // only move when calibrated and enabled
        guard isCalibrated, isHeadControlEnabled else { return }

        let rawYaw   = motion.attitude.yaw   - calibrationYaw
        let rawPitch = motion.attitude.pitch - calibrationPitch

        let normX = -max(-1, min(1, rawYaw   / yawRange))
        let normY = -max(-1, min(1, rawPitch / pitchRange))

        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let midX  = frame.midX
        let midY  = frame.midY

        let xPos = midX + CGFloat(normX) * (frame.width  / 2)
        let yPos = midY + CGFloat(normY) * (frame.height / 2)
        let newPos = CGPoint(x: xPos, y: yPos)

        print("🔀 normX:\(normX.rounded(to:2)), normY:\(normY.rounded(to:2)) → \(newPos)")

        CGWarpMouseCursorPosition(newPos)
        if let ev = CGEvent(mouseEventSource: nil,
                            mouseType: .mouseMoved,
                            mouseCursorPosition: newPos,
                            mouseButton: .left) {
            ev.post(tap: .cghidEventTap)
        }
    }

    // MARK: – Key Toggle Handler

    private func maybeHandleToggleEvent(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods == [.command, .shift],
           event.charactersIgnoringModifiers?.lowercased() == "h" {
            toggleHeadControl()
        }
    }

    /// flip head-control on/off
    private func toggleHeadControl() {
        isHeadControlEnabled.toggle()
        print("🕹 Head control \(isHeadControlEnabled ? "ENABLED" : "DISABLED")")
    }
}

// MARK: – Helper for nicer rounding
private extension Double {
    func rounded(to places: Int) -> Double {
        let mult = pow(10.0, Double(places))
        return (self * mult).rounded() / mult
    }
}
