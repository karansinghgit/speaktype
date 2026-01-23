//
//  TrialBanner.swift
//  speaktype
//
//  Created on 2026-01-19.
//  Banner component for trial status warnings
//

import SwiftUI

struct TrialBanner: View {
    let status: TrialStatus
    @EnvironmentObject var licenseManager: LicenseManager
    @State private var showLicenseSheet = false
    
    var body: some View {
        Group {
            switch status {
            case .expired:
                expiredBanner
            case .expiringSoon(let days):
                expiringSoonBanner(days: days)
            case .active(let days):
                activeTrialBanner(days: days)
            case .loading:
                EmptyView()
            }
        }
    }
    
    private var expiredBanner: some View {
        BannerContainer(
            icon: "xmark.circle",
            iconColor: .accentError,
            title: "Trial Expired",
            subtitle: "Upgrade to continue using all features",
            backgroundColor: Color.accentError.opacity(0.05),
            borderColor: Color.accentError.opacity(0.2)
        ) {
            HStack(spacing: 8) {
                if !licenseManager.isPro {
                    Button(action: { showLicenseSheet = true }) {
                        Text("Enter License")
                    }
                    .buttonStyle(.stSecondary)
                }
                
                Button(action: { openPurchaseURL() }) {
                    Text("Buy License")
                }
                .buttonStyle(.stPrimary)
            }
        }
        .sheet(isPresented: $showLicenseSheet) {
            LicenseView()
                .environmentObject(licenseManager)
        }
    }
    
    private func expiringSoonBanner(days: Int) -> some View {
        BannerContainer(
            icon: "exclamationmark.triangle",
            iconColor: .accentWarning,
            title: "Trial Ending Soon",
            subtitle: "\(days) day\(days == 1 ? "" : "s") remaining",
            backgroundColor: Color.accentWarning.opacity(0.05),
            borderColor: Color.accentWarning.opacity(0.2)
        ) {
            Button(action: { openPurchaseURL() }) {
                Text("Upgrade")
            }
            .buttonStyle(.stPrimary)
        }
    }
    
    private func activeTrialBanner(days: Int) -> some View {
        BannerContainer(
            icon: "clock",
            iconColor: .accentPrimary,
            title: "Free Trial Active",
            subtitle: "\(days) day\(days == 1 ? "" : "s") remaining · Full access",
            backgroundColor: Color.bgHover,
            borderColor: Color.border
        ) {
            Button(action: { openPurchaseURL() }) {
                Text("Upgrade")
            }
            .buttonStyle(.stPrimary)
        }
    }
    
    private func openPurchaseURL() {
        if let urlString = ProcessInfo.processInfo.environment["POLAR_PURCHASE_URL"],
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback
            if let url = URL(string: "https://polar.sh") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Banner Container Component

private struct BannerContainer<Actions: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let backgroundColor: Color
    let borderColor: Color
    @ViewBuilder let actions: () -> Actions
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.labelMedium)
                    .foregroundStyle(Color.textPrimary)
                
                Text(subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            actions()
        }
        .padding(16)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        TrialBanner(status: .expired)
            .environmentObject(LicenseManager())
        
        TrialBanner(status: .expiringSoon(3))
            .environmentObject(LicenseManager())
        
        TrialBanner(status: .active(10))
            .environmentObject(LicenseManager())
    }
    .padding()
    .background(Color.bgApp)
}
