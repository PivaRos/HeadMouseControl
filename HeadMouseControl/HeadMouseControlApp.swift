//
//  HeadMouseControlApp.swift
//  HeadMouseControl
//
//  Created by Daniel Gurbin on 16/04/2025.
//

import SwiftUI

@main
struct HeadMouseControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Create the environment object
    private let appDelegateObservable: AppDelegateObservable
    
    init() {
        // The appDelegate property is not yet initialized at this point,
        // so we'll create a temporary one that will be replaced once the app launches
        self.appDelegateObservable = AppDelegateObservable(pinchManager: PinchDetectionManager())
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppDelegateObservable(pinchManager: appDelegate.pinchDetectionManager))
                .onAppear {
                    // Ensure the window is properly sized and non-resizable
                    if let window = NSApplication.shared.windows.first {
                        window.styleMask.remove(.resizable)
                        window.title = "Head Mouse Control"
                    }
                }
        }
    }
}
