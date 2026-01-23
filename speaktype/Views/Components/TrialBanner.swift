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
        HStack(spacing: 12) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentError)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Trial Expired")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                
                Text("Upgrade to continue using all features")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if !licenseManager.isPro {
                    Button(action: { showLicenseSheet = true }) {
                        Text("Enter License")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.bgHover)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: { openPurchaseURL() }) {
                    Text("Buy License")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.accentError.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentError.opacity(0.2), lineWidth: 1)
        )
        .sheet(isPresented: $showLicenseSheet) {
            LicenseView()
                .environmentObject(licenseManager)
        }
    }
    
    private func expiringSoonBanner(days: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentWarning)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Trial Ending Soon")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                
                Text("\(days) day\(days == 1 ? "" : "s") remaining")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Button(action: { openPurchaseURL() }) {
                Text("Upgrade")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.accentWarning.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentWarning.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func activeTrialBanner(days: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 18))
                .foregroundStyle(Color.accentPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Free Trial Active")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.textPrimary)
                
                Text("\(days) day\(days == 1 ? "" : "s") remaining · Full access")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Button(action: { openPurchaseURL() }) {
                Text("Upgrade")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.bgSelected.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.border, lineWidth: 1)
        )
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

