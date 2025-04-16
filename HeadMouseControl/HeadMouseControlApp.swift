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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
