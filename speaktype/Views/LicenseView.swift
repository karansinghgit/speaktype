//
//  LicenseView.swift
//  speaktype
//
//  Created on 2026-01-19.
//  Professional license activation UI for macOS
//

import SwiftUI

struct LicenseView: View {
    @EnvironmentObject var licenseManager: LicenseManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var licenseKeyInput: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showSuccess: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue.gradient)
                    .padding(.top, 40)
                
                Text("Activate Pro License")
                    .font(.title)
                    .fontWeight(.semibold)
                
                Text("Enter your license key to unlock all Pro features")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 30)
            
            // License Key Input
            VStack(alignment: .leading, spacing: 8) {
                Text("License Key")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    showError ? Color.red.opacity(0.5) : Color.gray.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                        .onSubmit {
                            activateLicense()
                        }
                        .disabled(licenseManager.isValidating)
                    
                    Button {
                        pasteLicenseKey()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.borderless)
                    .help("Paste from clipboard")
                    .disabled(licenseManager.isValidating)
                }
            }
            .padding(.horizontal, 40)
            
            // Error Message
            if showError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Success Message
            if showSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    
                    Text("License activated successfully!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Activate Button
            Button {
                activateLicense()
            } label: {
                HStack {
                    if licenseManager.isValidating {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    
                    Text(licenseManager.isValidating ? "Verifying..." : "Activate License")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(licenseKeyInput.isEmpty || licenseManager.isValidating)
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
            
            // Footer
            VStack(spacing: 12) {
                Divider()
                
                VStack(spacing: 8) {
                    Text("Don't have a license key?")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Purchase a License") {
                        openPurchaseURL()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .padding(.vertical, 16)
                
                // Continue without activating (if already in app)
                if licenseManager.isPro == false {
                    Button("Continue with Free Version") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(width: 480, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func activateLicense() {
        showError = false
        showSuccess = false
        
        Task {
            do {
                try await licenseManager.activateLicense(key: licenseKeyInput)
                
                withAnimation {
                    showSuccess = true
                }
                
                // Auto-dismiss after success
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } catch let error as LicenseError {
                withAnimation {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            } catch {
                withAnimation {
                    errorMessage = "An unexpected error occurred. Please try again."
                    showError = true
                }
            }
        }
    }
    
    private func pasteLicenseKey() {
        let pasteboard = NSPasteboard.general
        if let clipboardString = pasteboard.string(forType: .string) {
            licenseKeyInput = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private func openPurchaseURL() {
        // Try to get purchase URL from environment or Info.plist
        var purchaseURLString: String?
        
        if let envURL = ProcessInfo.processInfo.environment["POLAR_PURCHASE_URL"] {
            purchaseURLString = envURL
        } else if let plistURL = Bundle.main.object(forInfoDictionaryKey: "PolarPurchaseURL") as? String,
                  !plistURL.isEmpty,
                  plistURL != "$(POLAR_PURCHASE_URL)" {
            purchaseURLString = plistURL
        } else {
            // Fallback: Open Polar.sh homepage if URL not configured
            purchaseURLString = "https://polar.sh"
            print("⚠️ POLAR_PURCHASE_URL not configured. Opening polar.sh homepage.")
        }
        
        if let urlString = purchaseURLString, let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview {
    LicenseView()
        .environmentObject(LicenseManager())
}

