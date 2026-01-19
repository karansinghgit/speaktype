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
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // License Manager
    @StateObject private var licenseManager = LicenseManager.shared
    
    // Trial Manager
    @StateObject private var trialManager = TrialManager.shared
    
    init() {
        // For UI testing: bypass onboarding automatically
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            hasCompletedOnboarding = true
        }
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
            .environmentObject(licenseManager)
            .environmentObject(trialManager)
            .preferredColorScheme(appTheme.colorScheme)
            .tint(.appRed)
        }
        .defaultSize(width: 1200, height: 800)
        .handlesExternalEvents(matching: ["main-dashboard", "open"]) // Only open for matching IDs
        .commands {
             SidebarCommands()
             CommandGroup(after: .appInfo) {
                 Button("Manage License...") {
                     openWindow(id: "license-window")
                 }
                 .keyboardShortcut("L", modifiers: [.command, .shift])
             }
        }
        
        // License Window
        Window("License", id: "license-window") {
            LicenseView()
                .environmentObject(licenseManager)
                .frame(width: 480, height: 520)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        
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
