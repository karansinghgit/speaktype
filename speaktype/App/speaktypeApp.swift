//
//  speaktypeApp.swift
//  speaktype
//
//  Created by Karan Singh on 7/1/26.
//

import SwiftUI
import SwiftData
import KeyboardShortcuts

@main
struct speaktypeApp: App {
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // KeyboardShortcuts init moved to AppDelegate to ensure early binding?
        // Or keep here.
    }
    
    var body: some Scene {
        // Main Dashboard Window (Hidden by default, opened via Menu Bar or Dock)
        WindowGroup(id: "main-dashboard") {
            Group {
                if hasCompletedOnboarding {
                    MainView()
                } else {
                    OnboardingView()
                }
            }
            .preferredColorScheme(.dark)
            .tint(.appRed)
        }
        .defaultSize(width: 1200, height: 800)
        .handlesExternalEvents(matching: ["main-dashboard", "open"]) // Only open for matching IDs
        .commands {
             SidebarCommands()
        }
        
        // Note: Mini Recorder is now managed manually by AppDelegate -> MiniRecorderWindowController
        // to prevent SwiftUI from auto-opening the main dashboard on activation.
        
        // Menu Bar Extra (Always running listener)
        MenuBarExtra("SpeakType", systemImage: "mic.fill") {
            Button("Open Dashboard") {
                // Ensure we open the main dashboard via consistent ID or URL
                // Using URL forces the specific window group to handle it
                if let url = URL(string: "speaktype://open") {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
