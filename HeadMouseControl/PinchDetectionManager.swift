// PinchDetectionManager.swift

import Foundation
import AVFoundation
import Vision
import CoreGraphics
import AppKit

enum PinchType {
    case detected
    case none
}

class PinchDetectionManager: NSObject, ObservableObject {
    // MARK: - Properties
    @Published var cameraPermissionGranted = false
    @Published var isPinchDetectionEnabled = false
    @Published var lastDetectedPinch: PinchType = .none
    @Published var lastPinchTime: Date?
    
    // For camera access debugging
    @Published var cameraStatus: String = "Not initialized"
    @Published var handDetectionActive: Bool = false
    
    private var captureSession: AVCaptureSession?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    // Enhanced pinch detection parameters
    private let pinchThreshold: Float = 0.12      // Distance for confirmed pinch
    private let nearPinchThreshold: Float = 0.25  // Distance for preparing to pinch
    private let releaseThreshold: Float = 0.20    // Distance to consider pinch released
    
    // For pinch detection stability
    private var lastPinchState = false
    private var pinchStartTime: Date?
    private let minPinchDuration = 0.03           // Duration for pinch confirmation (seconds)
    
    // For smoothing multiple pinch detections
    private var recentPinchDistances: [Float] = []
    private let distanceBufferSize = 3            // Number of frames to average
    
    // Debounce timer to prevent multiple clicks
    private var lastClickTime: Date?
    private let minClickInterval = 0.4            // Seconds between clicks
    
    // To detect when a pinch is released
    private var pinchReleased = true
    
    // MARK: - Initialization
    override init() {
        super.init()
        handPoseRequest.maximumHandCount = 2      // Detect both hands
    }
    
    // MARK: - Public Methods
    func setupCamera() {
        // Force camera permission prompt immediately
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.cameraPermissionGranted = granted
                
                if granted {
                    self.setupCaptureSession()
                    print("📷 Camera permission granted")
                } else {
                    print("❌ Camera permission denied")
                    // Show instructions for enabling camera permissions
                    self.showCameraPermissionSettings()
                }
            }
        }
    }
    
    func togglePinchDetection() {
        isPinchDetectionEnabled.toggle()
        
        if isPinchDetectionEnabled {
            startCaptureSession()
        } else {
            stopCaptureSession()
        }
    }
    
    // MARK: - Private Methods
    private func showCameraPermissionSettings() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Camera Access Required"
            alert.informativeText = "This app needs camera access for pinch detection. Please enable camera access in System Settings > Privacy & Security > Camera."
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func setupCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let captureSession = AVCaptureSession()
            captureSession.sessionPreset = .medium
            
            // Check for camera
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                DispatchQueue.main.async {
                    self.cameraStatus = "No front camera found"
                }
                print("❌ No front camera found")
                return
            }
            
            // Try to create input
            guard let input = try? AVCaptureDeviceInput(device: camera) else {
                DispatchQueue.main.async {
                    self.cameraStatus = "Failed to get camera input"
                }
                print("❌ Failed to get camera input")
                return
            }
            
            // Try to add input to session
            guard captureSession.canAddInput(input) else {
                DispatchQueue.main.async {
                    self.cameraStatus = "Cannot add camera input to session"
                }
                print("❌ Cannot add camera input to session")
                return
            }
            
            captureSession.addInput(input)
            
            let videoDataOutput = AVCaptureVideoDataOutput()
            videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.headmousecontrol.videodataoutput"))
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            guard captureSession.canAddOutput(videoDataOutput) else {
                DispatchQueue.main.async {
                    self.cameraStatus = "Cannot add video output to session"
                }
                print("❌ Cannot add video output to session")
                return
            }
            
            captureSession.addOutput(videoDataOutput)
            
            self.captureSession = captureSession
            self.videoDataOutput = videoDataOutput
            
            DispatchQueue.main.async {
                self.cameraStatus = "Camera initialized successfully"
            }
            print("✅ Camera setup completed")
        }
    }
    
    private func startCaptureSession() {
        guard let captureSession = captureSession, !captureSession.isRunning else { return }
        
        DispatchQueue.main.async {
            self.cameraStatus = "Starting camera..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
            print("📷 Camera session started")
            
            DispatchQueue.main.async {
                self.cameraStatus = "Camera started - waiting for hand detection"
            }
        }
    }
    
    private func stopCaptureSession() {
        guard let captureSession = captureSession, captureSession.isRunning else { return }
        
        DispatchQueue.main.async {
            self.cameraStatus = "Stopping camera..."
            self.handDetectionActive = false
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.stopRunning()
            print("📷 Camera session stopped")
            
            DispatchQueue.main.async {
                self.cameraStatus = "Camera stopped"
            }
        }
    }
    
    private func detectPinch(in imageBuffer: CVImageBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer, orientation: .up, options: [:])
        
        do {
            try handler.perform([handPoseRequest])
            
            guard let results = handPoseRequest.results else { 
                DispatchQueue.main.async {
                    self.handDetectionActive = false
                }
                return 
            }
            
            // Update handDetectionActive when receiving hand detection frames
            DispatchQueue.main.async {
                self.handDetectionActive = true
                
                // Update status message when camera is working
                if self.cameraStatus != "Camera is active and detecting hands" {
                    self.cameraStatus = "Camera is active and detecting hands"
                }
            }
            
            var bestPinchDistance: Float = 1.0
            var bestConfidence: Float = 0.0
            var handDetected = false
            
            // Find the best pinch candidate from available hands
            for observation in results {
                // Get all relevant landmarks with higher confidence threshold
                guard
                    let indexTip = try? observation.recognizedPoint(.indexTip),
                    let thumbTip = try? observation.recognizedPoint(.thumbTip),
                    let indexDIP = try? observation.recognizedPoint(.indexDIP),
                    let thumbIP = try? observation.recognizedPoint(.thumbIP),
                    let wrist = try? observation.recognizedPoint(.wrist),
                    indexTip.confidence > 0.5 && thumbTip.confidence > 0.5
                else { continue }
                
                handDetected = true
                
                // Get the full hand bounding box for normalization
                let handWidth = wrist.location.distance(to: indexTip.location)
                
                // Calculate distance between index tip and thumb tip
                let pinchDistance = thumbTip.location.distance(to: indexTip.location)
                
                // Normalize the distance relative to hand size for better consistency
                let normalizedDistance = Float(pinchDistance) / Float(handWidth) * 2.0
                
                // Calculate confidence based on clarity of detection
                let currentConfidence = min(indexTip.confidence, thumbTip.confidence)
                
                // Select the best pinch based on closest distance and highest confidence
                if normalizedDistance < bestPinchDistance && currentConfidence > bestConfidence {
                    bestPinchDistance = normalizedDistance
                    bestConfidence = currentConfidence
                }
            }
            
            // Update the recent distances buffer for smoothing
            recentPinchDistances.append(bestPinchDistance)
            if recentPinchDistances.count > distanceBufferSize {
                recentPinchDistances.removeFirst()
            }
            
            // Calculate a smoothed distance using a rolling average
            let smoothedDistance = recentPinchDistances.reduce(0, +) / Float(recentPinchDistances.count)
            
            // Provide visual feedback about hand position
            if handDetected {
                DispatchQueue.main.async {
                    // Update hand detection status
                    self.lastDetectedPinch = .detected
                    // Only update last time if more than 0.3 second has passed
                    if self.lastPinchTime == nil || 
                        Date().timeIntervalSince(self.lastPinchTime!) > 0.3 {
                        self.lastPinchTime = Date()
                    }
                }
                
                // State machine for pinch detection with hysteresis
                if smoothedDistance < pinchThreshold {
                    // Detect pinch - use the smoothed value
                    if pinchReleased {  // Only register if we've released the previous pinch
                        if !lastPinchState {
                            // Just started pinching
                            pinchStartTime = Date()
                            lastPinchState = true
                        } else if let startTime = pinchStartTime, 
                                Date().timeIntervalSince(startTime) >= minPinchDuration {
                            // Pinch has been held for the minimum duration
                            performLeftClick()
                            pinchReleased = false  // Prevent multiple clicks until released
                        }
                    }
                } else if smoothedDistance > releaseThreshold {
                    // Fingers are far enough apart to consider the pinch released
                    lastPinchState = false
                    pinchStartTime = nil
                    pinchReleased = true
                }
            }
            
            // If no hands detected, reset UI status after a delay
            if !handDetected && lastDetectedPinch != .none {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if self.lastPinchTime != nil && Date().timeIntervalSince(self.lastPinchTime!) > 1.9 {
                        self.lastDetectedPinch = .none
                    }
                }
            }
            
        } catch {
            print("❌ Hand pose detection error: \(error)")
        }
    }
    
    private func performLeftClick() {
        // Debounce to prevent rapid consecutive clicks
        if let lastTime = lastClickTime, Date().timeIntervalSince(lastTime) < minClickInterval {
            return
        }
        
        lastClickTime = Date()
        
        DispatchQueue.main.async {
            // Get current mouse position
            let mouseLocation = NSEvent.mouseLocation
            let point = CGPoint(x: mouseLocation.x, y: CGFloat(NSScreen.main?.frame.height ?? 0) - mouseLocation.y)
            
            // Update published properties for UI feedback
            self.lastDetectedPinch = .detected
            self.lastPinchTime = Date()
            
            // Perform click
            if let clickDownEvent = CGEvent(mouseEventSource: nil, 
                                          mouseType: .leftMouseDown, 
                                          mouseCursorPosition: point, 
                                          mouseButton: .left) {
                clickDownEvent.post(tap: .cghidEventTap)
                
                // For debugging
                print("👆 Left click at \(point)")
                
                // Release after a short delay (simulating click up)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if let clickUpEvent = CGEvent(mouseEventSource: nil, 
                                               mouseType: .leftMouseUp, 
                                               mouseCursorPosition: point, 
                                               mouseButton: .left) {
                        clickUpEvent.post(tap: .cghidEventTap)
                    }
                }
            }
        }
    }
}

// MARK: - Helper Extensions
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        return sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension PinchDetectionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isPinchDetectionEnabled, 
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        detectPinch(in: imageBuffer)
    }
} 