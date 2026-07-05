//
//  speaktypeApp.swift
//  speaktype
//
//  Created by Karan Singh on 7/1/26.
//

import SwiftData
import SwiftUI

@main
struct speaktypeApp: App {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // License Manager
    @StateObject private var licenseManager = LicenseManager.shared

    // Trial Manager
    @StateObject private var trialManager = TrialManager.shared

    init() {
        // Register bundled fonts (Satoshi, Source Sans 3) so Font.custom resolves
        // them regardless of what's installed on the machine.
        AppFonts.registerBundledFonts()

        // For UI testing: bypass onboarding automatically
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            hasCompletedOnboarding = true
        }
    }

    var body: some Scene {
        // Main Dashboard Window (Hidden by default, opened via Menu Bar or Dock)
        WindowGroup(id: "main-dashboard") {
            ThemeProvider {
                Group {
                    if hasCompletedOnboarding {
                        MainView()
                    } else {
                        OnboardingView()
                    }
                }
            }
            .environmentObject(licenseManager)
            .environmentObject(trialManager)
            .preferredColorScheme(appTheme.colorScheme)
            .tint(Color.navyInk)
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.hiddenTitleBar)
        .handlesExternalEvents(matching: ["main-dashboard", "open"])  // Only open for matching IDs
        .commands {
            SidebarCommands()
        }

        // Note: Mini Recorder is now managed manually by AppDelegate -> MiniRecorderWindowController
        // to prevent SwiftUI from auto-opening the main dashboard on activation.

        // Menu Bar Extra (Always running listener)
        MenuBarExtra("SpeakType", systemImage: "waveform", isInserted: $showMenuBarIcon) {
            ThemeProvider {
                MenuBarDashboardView(
                    openDashboard: openDashboard,
                    quit: { NSApplication.shared.terminate(nil) }
                )
            }
            .preferredColorScheme(appTheme.colorScheme)
        }
        .menuBarExtraStyle(.window)
    }

    private func openDashboard() {
        // Using URL forces the specific window group to handle the request consistently.
        if let url = URL(string: "speaktype://open") {
            NSWorkspace.shared.open(url)
        }
    }
}
