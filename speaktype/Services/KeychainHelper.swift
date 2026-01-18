//
//  KeychainHelper.swift
//  speaktype
//
//  Created on 2026-01-19.
//  Secure Keychain wrapper for license key storage
//

import Foundation
import Security

enum KeychainError: Error {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case unableToConvertToData
    case unableToConvertToString
}

class KeychainHelper {
    
    static let shared = KeychainHelper()
    private init() {}
    
    private let service = "sh.polar.speaktype.license"
    private let account = "license_key"
    
    // MARK: - Save License Key
    
    func saveLicenseKey(_ key: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.unableToConvertToData
        }
        
        // First, try to delete any existing item
        try? deleteLicenseKey()
        
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: - Read License Key
    
    func readLicenseKey() throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.unableToConvertToString
        }
        
        return key
    }
    
    // MARK: - Delete License Key
    
    func deleteLicenseKey() throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: - Check if License Key Exists
    
    func hasLicenseKey() -> Bool {
        do {
            _ = try readLicenseKey()
            return true
        } catch {
            return false
        }
    }
}

