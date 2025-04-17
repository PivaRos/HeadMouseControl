// ContentView.swift

import SwiftUI

struct ContentView: View {
    @State private var isCalibrated = false
    @State private var yawRange:   Double = 40   // in degrees
    @State private var pitchRange: Double = 30   // in degrees

    var body: some View {
        VStack(spacing: 20) {
            Text(isCalibrated
                 ? "✅ Calibrated"
                 : "Please align your head and tap Calibrate")
                .multilineTextAlignment(.center)
                .padding()

            // Yaw slider (10°–90°)
            HStack {
                Text("Yaw Range: \(Int(yawRange))°")
                Slider(value: $yawRange, in: 10...90, step: 1) {
                    Text("Yaw Range")
                }
                .onChange(of: yawRange) { _, newYaw in
                    NotificationCenter.default.post(name: .headMouseSensitivityChanged,
                                                    object: nil,
                                                    userInfo: [
                                                        "yawRange":   newYaw,
                                                        "pitchRange": pitchRange
                                                    ])
                }
            }
            .padding(.horizontal)

            // Pitch slider (10°–60°)
            HStack {
                Text("Pitch Range: \(Int(pitchRange))°")
                Slider(value: $pitchRange, in: 10...60, step: 1) {
                    Text("Pitch Range")
                }
                .onChange(of: pitchRange) { _, newPitch in
                    NotificationCenter.default.post(name: .headMouseSensitivityChanged,
                                                    object: nil,
                                                    userInfo: [
                                                        "yawRange":   yawRange,
                                                        "pitchRange": newPitch
                                                    ])
                }
            }
            .padding(.horizontal)

            Button(isCalibrated ? "Re‑calibrate" : "Calibrate") {
                NotificationCenter.default.post(name: .headMouseCalibrate, object: nil)
                isCalibrated = true
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 400, height: 250)
        .padding()
    }
}
