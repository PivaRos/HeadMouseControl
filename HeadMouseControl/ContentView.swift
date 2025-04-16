import SwiftUI

struct ContentView: View {
  @State private var isCalibrated = false

  var body: some View {
    VStack(spacing: 20) {
      Text(isCalibrated ? "✅ Calibrated" : "Please align your head and tap Calibrate")
        .multilineTextAlignment(.center)
        .padding()

        Button(isCalibrated ? "Re‑calibrate" : "Calibrate") {
            NotificationCenter.default.post(name: .headMouseCalibrate, object: nil)
            isCalibrated = true
        }
      .keyboardShortcut(.defaultAction) // Enter to fire
    }
    .frame(width: 300, height: 150)
    .padding()
  }
}
