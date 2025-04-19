// ContentView.swift

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var isCalibrated = false
    @State private var yawRange: Double = 26   // in degrees
    @State private var pitchRange: Double = 28   // in degrees
    
    // Access to AppDelegate for pinch detection manager
    @EnvironmentObject private var appDelegate: AppDelegateObservable
    
    // Timer for animating the camera active indicator
    @State private var cameraActiveTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    @State private var indicatorPulse = false
    
    // Selected tab
    @State private var selectedTab: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Head Mouse Control")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Tab selector
            HStack(spacing: 0) {
                tabButton("Head Control", index: 0)
                tabButton("Pinch Detection", index: 1)
                tabButton("Settings", index: 2)
            }
            .padding(.horizontal)
            
            // Main content area
            ZStack {
                // Tab 1 - Head Control
                if selectedTab == 0 {
                    headControlView
                        .transition(.opacity)
                }
                
                // Tab 2 - Pinch Detection
                else if selectedTab == 1 {
                    pinchDetectionView
                        .transition(.opacity)
                }
                
                // Tab 3 - Settings
                else {
                    settingsView
                        .transition(.opacity)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .frame(width: 420, height: 360)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // Tab button
    private func tabButton(_ title: String, index: Int) -> some View {
        Button(action: {
            selectedTab = index
        }) {
            Text(title)
                .font(.subheadline)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            VStack(spacing: 0) {
                Spacer()
                Color.clear
                    .frame(height: selectedTab == index ? 2 : 0)
                Rectangle()
                    .fill(selectedTab == index ? Color.blue : Color.clear)
                    .frame(height: 2)
            }
        )
        .foregroundColor(selectedTab == index ? .primary : .secondary)
    }
    
    // MARK: - Head Control View
    private var headControlView: some View {
        VStack(spacing: 16) {
            // Status and calibration
            VStack(spacing: 8) {
                StatusBadgeView(
                    isActive: isCalibrated, 
                    activeText: "Calibrated", 
                    inactiveText: "Not Calibrated",
                    icon: "arrow.up.and.down.and.arrow.left.and.right"
                )
                
                Text(isCalibrated
                     ? "Head control is calibrated and ready"
                     : "Please align your head and tap Calibrate")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
                
                Button(isCalibrated ? "Re‑calibrate" : "Calibrate") {
                    NotificationCenter.default.post(name: .headMouseCalibrate, object: nil)
                    isCalibrated = true
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Sensitivity controls
            VStack(alignment: .leading, spacing: 12) {
                Text("Sensitivity")
                    .font(.headline)
                
                // Yaw slider (10°–90°)
                SliderWithLabel(
                    value: $yawRange, 
                    range: 10...90,
                    label: "Horizontal (Yaw): \(Int(yawRange))°",
                    onChanged: { newYaw in
                        NotificationCenter.default.post(name: .headMouseSensitivityChanged,
                                                        object: nil,
                                                        userInfo: [
                                                            "yawRange": newYaw,
                                                            "pitchRange": pitchRange
                                                        ])
                    }
                )
                
                // Pitch slider (10°–60°)
                SliderWithLabel(
                    value: $pitchRange, 
                    range: 10...60,
                    label: "Vertical (Pitch): \(Int(pitchRange))°",
                    onChanged: { newPitch in
                        NotificationCenter.default.post(name: .headMouseSensitivityChanged,
                                                        object: nil,
                                                        userInfo: [
                                                            "yawRange": yawRange,
                                                            "pitchRange": newPitch
                                                        ])
                    }
                )
            }
            
            Spacer()
        }
    }
    
    // MARK: - Pinch Detection View
    private var pinchDetectionView: some View {
        VStack(spacing: 16) {
            // Status indicator
            VStack(spacing: 8) {
                StatusBadgeView(
                    isActive: appDelegate.pinchManager.isPinchDetectionEnabled, 
                    activeText: "Enabled", 
                    inactiveText: "Disabled",
                    icon: "hand.point.up.fill"
                )
                
                Toggle("Enable Pinch Detection", isOn: Binding(
                    get: { appDelegate.pinchManager.isPinchDetectionEnabled },
                    set: { _ in togglePinchDetection() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .padding(.horizontal, 40)
            }
            
            // Camera status
            if appDelegate.pinchManager.isPinchDetectionEnabled {
                CameraStatusView(
                    isHandDetected: appDelegate.pinchManager.lastDetectedPinch == .detected,
                    lastPinchTime: appDelegate.pinchManager.lastPinchTime,
                    indicatorPulse: $indicatorPulse
                )
                .padding(.vertical, 8)
                .onReceive(cameraActiveTimer) { _ in
                    indicatorPulse.toggle()
                }
            }
            
            Divider()
            
            // Camera permission
            if !appDelegate.pinchManager.cameraPermissionGranted {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Camera permission required")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                    
                    Text("Camera access is needed for pinch detection to work")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Request Camera Permission") {
                        requestCameraPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 20)
            } else {
                // Instructions
                VStack(spacing: 8) {
                    Text("How to use pinch detection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 20) {
                        VStack {
                            Image(systemName: "hand.point.up.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text("Show hand")
                                .font(.caption)
                        }
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        
                        VStack {
                            Image(systemName: "hand.pinch")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text("Pinch")
                                .font(.caption)
                        }
                        
                        Image(systemName: "arrow.right")
                            .foregroundColor(.secondary)
                        
                        VStack {
                            Image(systemName: "mouse.fill")
                                .font(.title)
                                .foregroundColor(.blue)
                            Text("Click")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Settings View
    private var settingsView: some View {
        VStack(spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.headline)
                .padding(.bottom, 4)
            
            VStack(spacing: 12) {
                KeyboardShortcutView(
                    keys: "⌘⇧H",
                    description: "Toggle both head control and pinch detection"
                )
                
                KeyboardShortcutView(
                    keys: "⌘⇧P",
                    description: "Toggle only pinch detection"
                )
            }
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Camera Status: \(appDelegate.pinchManager.cameraStatus)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Any pinch gesture will perform a left click")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            
            Spacer()
            
            HStack {
                Spacer()
                Text("v1.0.0")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func togglePinchDetection() {
        NotificationCenter.default.post(name: .pinchDetectionToggle, object: nil)
    }
    
    private func requestCameraPermission() {
        // This will trigger the permission prompt
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    // Refresh the camera setup if permission was just granted
                    self.appDelegate.pinchManager.setupCamera()
                }
            }
        }
    }
}

// MARK: - Helper Views
struct StatusBadgeView: View {
    let isActive: Bool
    let activeText: String
    let inactiveText: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .symbolRenderingMode(.hierarchical)
            Text(isActive ? activeText : inactiveText)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.green.opacity(0.2) : Color.secondary.opacity(0.2))
        )
        .foregroundColor(isActive ? .green : .secondary)
    }
}

struct SliderWithLabel: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    let onChanged: (Double) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
            
            HStack {
                Text("\(Int(range.lowerBound))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: $value, in: range, step: 1) {
                    Text(label)
                }
                .onChange(of: value) { _, newValue in
                    onChanged(newValue)
                }
                
                Text("\(Int(range.upperBound))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct CameraStatusView: View {
    let isHandDetected: Bool
    let lastPinchTime: Date?
    @Binding var indicatorPulse: Bool
    
    private var isRecent: Bool {
        guard let time = lastPinchTime else { return false }
        return Date().timeIntervalSince(time) < 3.0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Hand detection indicator
            ZStack {
                Circle()
                    .stroke(
                        isHandDetected && isRecent ? Color.blue : Color.secondary.opacity(0.5),
                        lineWidth: 2
                    )
                    .frame(width: 60, height: 60)
                
                if isHandDetected && isRecent {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                }
                
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 26))
                    .foregroundColor(isHandDetected && isRecent ? .blue : .secondary.opacity(0.7))
            }
            
            // Status text
            Text(isHandDetected && isRecent ? "Hand Detected" : "Waiting for hand...")
                .font(.subheadline)
                .foregroundColor(isHandDetected && isRecent ? .primary : .secondary)
            
            // Camera active indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .opacity(indicatorPulse ? 0.5 : 1.0)
                    .animation(.easeInOut, value: indicatorPulse)
                
                Text("Camera active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct KeyboardShortcutView: View {
    let keys: String
    let description: String
    
    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.subheadline, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                )
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// ObservableObject wrapper for AppDelegate
class AppDelegateObservable: ObservableObject {
    let pinchManager: PinchDetectionManager
    
    init(pinchManager: PinchDetectionManager) {
        self.pinchManager = pinchManager
    }
}
