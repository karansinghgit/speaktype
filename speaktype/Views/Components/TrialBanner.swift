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
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.red)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("Trial Expired")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("Your trial has expired. Upgrade to continue using all features")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                if !licenseManager.isPro {
                    Button(action: {
                        showLicenseSheet = true
                    }) {
                        Text("Enter License")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    openPurchaseURL()
                }) {
                    Text("Buy License")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showLicenseSheet) {
            LicenseView()
                .environmentObject(licenseManager)
        }
    }
    
    private func expiringSoonBanner(days: Int) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("Trial Ending Soon")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("\(days) day\(days == 1 ? "" : "s") remaining in your trial")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    openPurchaseURL()
                }) {
                    Text("Get Pro")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func activeTrialBanner(days: Int) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "clock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text("Free Trial Active")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                
                Text("\(days) day\(days == 1 ? "" : "s") remaining • Full access to all features")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button(action: {
                    openPurchaseURL()
                }) {
                    Text("Upgrade Now")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "A62D35"), Color(hex: "2D5DA6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
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
    .background(Color.black)
}

