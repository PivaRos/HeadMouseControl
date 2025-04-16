import Cocoa
import CoreMotion

// 1) Define a notification name for calibration
extension Notification.Name {
    static let headMouseCalibrate = Notification.Name("HeadMouseControlCalibrate")
}

class AppDelegate: NSObject, NSApplicationDelegate, CMHeadphoneMotionManagerDelegate {
    // MARK: – Motion & State
    private let motionManager = CMHeadphoneMotionManager()
    private let queue = OperationQueue()
    private var currentMotion: CMDeviceMotion?

    // MARK: – Calibration
    private var calibrationYaw:   Double = 0
    private var calibrationPitch: Double = 0
    private var isCalibrated = false

    // MARK: – Click Gesture
    private var lastPitch = 0.0
    private var clickLocked = false
    private let clickThreshold = 0.5
    
    private var velocityX: CGFloat = 0
    private let accelerationFactor: CGFloat = 5    // tweak this to taste
    private let friction: CGFloat = 0.85

    // MARK: – Startup
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🔥 AppDelegate didFinishLaunching fired")

        // Register for calibration notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCalibrateNotification),
            name: .headMouseCalibrate,
            object: nil
        )

        // Setup and start Core Motion
        guard motionManager.isDeviceMotionAvailable else {
            print("❌ Headphone motion not available")
            return
        }
        motionManager.delegate = self
        motionManager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            self.currentMotion = motion

            DispatchQueue.main.async {
                // Always log raw data
                print("🎧 Motion — yaw: \(motion.attitude.yaw), pitch: \(motion.attitude.pitch)")

                // Only update cursor once calibrated
                guard self.isCalibrated else { return }
                self.updateCursor(using: motion)
                self.detectClick(using: motion)
            }
        }
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

    // MARK: – Cursor Movement
    private func updateCursor(using motion: CMDeviceMotion) {
        let rawYaw   = motion.attitude.yaw   - calibrationYaw
        let rawPitch = motion.attitude.pitch - calibrationPitch

        // map ±45° yaw and ±30° pitch into –1…1
        let normX = -max(-1, min(1, rawYaw / (.pi/4)))
        let normY = -max(-1, min(1, rawPitch / (.pi/6)))

        guard let screen = NSScreen.main else { return }
        let frame = screen.frame
        let midX  = frame.midX
        let midY  = frame.midY

        let xPos = midX + CGFloat(normX) * (frame.width  / 2)
        let yPos = midY + CGFloat(normY) * (frame.height / 2)
        let newPos = CGPoint(x: xPos, y: yPos)

        print("🔀 normX:\(normX.rounded(to:2)), normY:\(normY.rounded(to:2)) → \(newPos)")

        CGWarpMouseCursorPosition(newPos)
        if let ev = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: newPos,
            mouseButton: .left
        ) {
            ev.post(tap: .cghidEventTap)
        }
    }

    // MARK: – Nod for Click
    private func detectClick(using motion: CMDeviceMotion) {
        let pitch = motion.attitude.pitch
        if !clickLocked && (pitch - lastPitch) > clickThreshold {
            let pt = NSEvent.mouseLocation
            performClick(at: pt)
            clickLocked = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.clickLocked = false
            }
        }
        lastPitch = pitch
    }

    private func performClick(at point: CGPoint) {
        print("👉 Click at \(point)")
        guard
            let down = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: point,
                mouseButton: .left
            ),
            let up = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: .left
            )
        else { return }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: – CMHeadphoneMotionManagerDelegate
    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        print("✅ AirPods connected")
    }
    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        print("❌ AirPods disconnected")
    }
}

// MARK: – Helper for nicer rounding
private extension Double {
    func rounded(to places: Int) -> Double {
        let mult = pow(10.0, Double(places))
        return (self * mult).rounded() / mult
    }
}
