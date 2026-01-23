//
//  ProFeatureGate.swift
//  speaktype
//
//  Created on 2026-01-19.
//  SwiftUI view modifier for feature gating
//

import SwiftUI

/// View modifier that conditionally shows content based on Pro status
struct ProFeatureGate: ViewModifier {
    @EnvironmentObject var licenseManager: LicenseManager
    let feature: ProFeature
    let showUpgradePrompt: Bool
    
    func body(content: Content) -> some View {
        if licenseManager.isPro {
            content
        } else if showUpgradePrompt {
            UpgradePromptView(feature: feature)
        } else {
            EmptyView()
        }
    }
}

extension View {
    /// Gate this view behind Pro licensing
    /// - Parameters:
    ///   - feature: The Pro feature this view represents
    ///   - showUpgradePrompt: If true, shows upgrade prompt instead of hiding content
    /// - Returns: Modified view
    func requiresPro(
        feature: ProFeature,
        showUpgradePrompt: Bool = false
    ) -> some View {
        modifier(ProFeatureGate(
            feature: feature,
            showUpgradePrompt: showUpgradePrompt
        ))
    }
}

// MARK: - Upgrade Prompt View

struct UpgradePromptView: View {
    let feature: ProFeature
    @State private var showLicenseSheet = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: feature.icon)
                .font(.system(size: 40))
                .foregroundStyle(.blue.gradient)
            
            Text(feature.displayName)
                .font(Typography.headlineLarge)
            
            Text(feature.description)
                .font(Typography.bodyMedium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showLicenseSheet = true
            } label: {
                Label("Upgrade to Pro", systemImage: "star.fill")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .sheet(isPresented: $showLicenseSheet) {
            LicenseView()
        }
    }
}

// MARK: - Pro Badge

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(Typography.badge)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Feature Lock Overlay

struct FeatureLockOverlay: View {
    let feature: ProFeature
    @State private var showLicenseSheet = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .blur(radius: 2)
            
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                
                Text("Pro Feature")
                    .font(Typography.labelMedium)
                    .foregroundColor(.white)
                
                Button("Unlock Now") {
                    showLicenseSheet = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(isPresented: $showLicenseSheet) {
            LicenseView()
        }
    }
}

// MARK: - Usage Examples

/*
 
 // Example 1: Simple feature gating (hide if not Pro)
 Text("Advanced content")
     .requiresPro(feature: .advancedAIModels)
 
 // Example 2: Show upgrade prompt instead of hiding
 AdvancedSettingsView()
     .requiresPro(feature: .advancedAIModels, showUpgradePrompt: true)
 
 // Example 3: Add Pro badge to menu items
 HStack {
     Text("Cloud Sync")
     if !licenseManager.isPro {
         ProBadge()
     }
 }
 
 // Example 4: Disable button for non-Pro users
 Button("Export as PDF") {
     exportPDF()
 }
 .disabled(!licenseManager.isPro)
 
 // Example 5: Overlay lock on content
 ZStack {
     PremiumContentView()
         .blur(radius: licenseManager.isPro ? 0 : 5)
     
     if !licenseManager.isPro {
         FeatureLockOverlay(feature: .advancedAIModels)
     }
 }
 
 // Example 6: Manual check in code
 func handleExport() {
     guard licenseManager.hasAccess(to: .exportFormats) else {
         showUpgradeAlert = true
         return
     }
     // Perform export...
 }
 
 */

