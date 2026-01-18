//
//  LicenseManager.swift
//  speaktype
//
//  Created on 2026-01-19.
//  License management and validation for Polar.sh integration
//

import Foundation
import Combine

enum LicenseError: LocalizedError {
    case invalidKey
    case networkError
    case validationFailed(String)
    case keychainError
    case expiredKey
    case activationLimitReached
    
    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "The license key format is invalid."
        case .networkError:
            return "Unable to connect to the license server. Please check your internet connection."
        case .validationFailed(let message):
            return message
        case .keychainError:
            return "Failed to save license key securely."
        case .expiredKey:
            return "This license key has expired."
        case .activationLimitReached:
            return "This license key has reached its activation limit."
        }
    }
}

@MainActor
class LicenseManager: ObservableObject {
    
    static let shared = LicenseManager()
    
    @Published private(set) var isPro: Bool = false
    @Published private(set) var licenseKey: String?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var isValidating: Bool = false
    
    private let keychainHelper = KeychainHelper.shared
    private let polarOrganizationId: String
    
    init() {
        // Read Organization ID from environment variable or Info.plist
        if let orgId = ProcessInfo.processInfo.environment["POLAR_ORGANIZATION_ID"] {
            self.polarOrganizationId = orgId
            print("✅ Using Polar Organization ID from environment variable")
        } else if let orgId = Bundle.main.object(forInfoDictionaryKey: "PolarOrganizationID") as? String,
                  !orgId.isEmpty,
                  orgId != "$(POLAR_ORGANIZATION_ID)" {
            self.polarOrganizationId = orgId
            print("✅ Using Polar Organization ID from Info.plist")
        } else {
            self.polarOrganizationId = ""
            print("⚠️ Warning: POLAR_ORGANIZATION_ID not configured. License validation will fail.")
            print("   Set POLAR_ORGANIZATION_ID in Xcode scheme environment variables")
            print("   or add PolarOrganizationID to Info.plist")
        }
        
        checkExistingLicense()
    }
    
    // MARK: - Check Existing License
    
    private func checkExistingLicense() {
        do {
            let key = try keychainHelper.readLicenseKey()
            self.licenseKey = key
            self.isPro = true
            print("✅ Found existing license key in Keychain")
            
            // Optional: Validate the key on app launch to ensure it's still valid
            Task {
                await validateExistingKey(key)
            }
        } catch KeychainError.itemNotFound {
            print("ℹ️ No license key found in Keychain")
            self.isPro = false
        } catch {
            print("⚠️ Error reading Keychain: \(error.localizedDescription)")
            self.isPro = false
        }
    }
    
    // MARK: - Activate License
    
    func activateLicense(key: String) async throws {
        isValidating = true
        defer { isValidating = false }
        
        // Validate format (basic check)
        let cleanedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedKey.isEmpty else {
            throw LicenseError.invalidKey
        }
        
        do {
            // Call Polar.sh validation endpoint
            let validatedKey = try await validateLicenseWithPolar(key: cleanedKey)
            
            // Save to Keychain
            try keychainHelper.saveLicenseKey(cleanedKey)
            
            // Update state
            self.licenseKey = cleanedKey
            self.isPro = true
            self.expirationDate = validatedKey.expiresAt
            
            print("✅ License activated successfully")
            print("   • Customer ID: \(validatedKey.customerId)")
            print("   • Expires: \(validatedKey.expiresAt?.formatted() ?? "Never")")
        } catch let error as LicenseError {
            throw error
        } catch {
            throw LicenseError.keychainError
        }
    }
    
    // MARK: - Deactivate License
    
    func deactivateLicense() async throws {
        if let key = licenseKey {
            // Optional: Call Polar.sh deactivation endpoint
            try? await deactivateLicenseWithPolar(key: key)
        }
        
        // Remove from Keychain
        try keychainHelper.deleteLicenseKey()
        
        // Update state
        self.licenseKey = nil
        self.isPro = false
        self.expirationDate = nil
        
        print("✅ License deactivated")
    }
    
    // MARK: - Validate Existing Key (Silent Check)
    
    private func validateExistingKey(_ key: String) async {
        do {
            let validatedKey = try await validateLicenseWithPolar(key: key)
            self.expirationDate = validatedKey.expiresAt
            print("✅ Existing license validated successfully")
        } catch {
            // If validation fails, consider the license invalid
            print("⚠️ Existing license validation failed: \(error.localizedDescription)")
            try? await deactivateLicense()
        }
    }
    
    // MARK: - Polar.sh API Integration
    
    // Models matching Polar.sh API specification
    private struct LicenseKeyValidateRequest: Codable {
        let key: String
        let organizationId: String
        
        enum CodingKeys: String, CodingKey {
            case key
            case organizationId = "organization_id"
        }
    }
    
    private struct ValidatedLicenseKey: Codable {
        let id: String
        let organizationId: String
        let customerId: String
        let benefitId: String
        let key: String
        let displayKey: String
        let status: LicenseKeyStatus
        let limitActivations: Int?
        let usage: Int
        let limitUsage: Int?
        let validations: Int
        let lastValidatedAt: Date?
        let expiresAt: Date?
        
        enum CodingKeys: String, CodingKey {
            case id
            case organizationId = "organization_id"
            case customerId = "customer_id"
            case benefitId = "benefit_id"
            case key
            case displayKey = "display_key"
            case status
            case limitActivations = "limit_activations"
            case usage
            case limitUsage = "limit_usage"
            case validations
            case lastValidatedAt = "last_validated_at"
            case expiresAt = "expires_at"
        }
    }
    
    private enum LicenseKeyStatus: String, Codable {
        case granted
        case revoked
        case disabled
    }
    
    private struct PolarErrorResponse: Codable {
        let error: String
        let detail: String
    }
    
    private func validateLicenseWithPolar(key: String) async throws -> ValidatedLicenseKey {
        // Validate that Organization ID is configured
        guard !polarOrganizationId.isEmpty else {
            throw LicenseError.validationFailed("License validation not configured. Missing POLAR_ORGANIZATION_ID.")
        }
        
        let endpoint = "https://api.polar.sh/v1/customer-portal/license-keys/validate"
        
        guard let url = URL(string: endpoint) else {
            throw LicenseError.networkError
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0
        
        let requestBody = LicenseKeyValidateRequest(
            key: key,
            organizationId: polarOrganizationId
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(requestBody)
        
        // PRODUCTION API CALL
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LicenseError.networkError
            }
            
            // Handle different response codes
            switch httpResponse.statusCode {
            case 200:
                // Success - decode and validate
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                
                let validatedKey = try decoder.decode(ValidatedLicenseKey.self, from: data)
                
                // Validate status
                guard validatedKey.status == .granted else {
                    if validatedKey.status == .revoked {
                        throw LicenseError.validationFailed("This license key has been revoked.")
                    } else if validatedKey.status == .disabled {
                        throw LicenseError.validationFailed("This license key has been disabled.")
                    }
                    throw LicenseError.invalidKey
                }
                
                // Check expiration
                if let expiresAt = validatedKey.expiresAt, expiresAt < Date() {
                    throw LicenseError.expiredKey
                }
                
                // Check activation limit
                if let limitActivations = validatedKey.limitActivations,
                   validatedKey.usage >= limitActivations {
                    throw LicenseError.activationLimitReached
                }
                
                return validatedKey
                
            case 404:
                // License key not found
                throw LicenseError.invalidKey
                
            case 422:
                // Validation error (malformed request)
                throw LicenseError.invalidKey
                
            default:
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(PolarErrorResponse.self, from: data) {
                    throw LicenseError.validationFailed(errorResponse.detail)
                }
                throw LicenseError.validationFailed("Server returned status \(httpResponse.statusCode)")
            }
            
        } catch let error as LicenseError {
            throw error
        } catch {
            // Network errors or decoding errors
            if let urlError = error as? URLError {
                if urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                    throw LicenseError.networkError
                }
            }
            throw LicenseError.validationFailed("Failed to validate license: \(error.localizedDescription)")
        }
    }
    
    private func deactivateLicenseWithPolar(key: String) async throws {
        // Note: Polar.sh doesn't have a public deactivation endpoint
        // Deactivation is handled by simply removing the key from the device
        // If you're using device activations, you would call the activation deactivation endpoint
        print("ℹ️ License deactivated locally. Key removed from Keychain.")
    }
}

