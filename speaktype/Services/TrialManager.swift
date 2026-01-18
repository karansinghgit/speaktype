//
//  TrialManager.swift
//  speaktype
//
//  Created on 2026-01-19.
//  Manages trial period and post-trial restrictions
//

import Foundation
import Combine

class TrialManager: ObservableObject {
    static let shared = TrialManager()
    
    @Published private(set) var trialStatus: TrialStatus = .loading
    @Published private(set) var daysRemaining: Int = 0
    @Published private(set) var trialEndDate: Date?
    
    private let trialDurationDays = 14
    private let firstLaunchKey = "app_first_launch_date"
    
    private init() {
        checkTrialStatus()
    }
    
    func checkTrialStatus() {
        let firstLaunchDate = getFirstLaunchDate()
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate trial end date (14 days from first launch)
        if let endDate = calendar.date(byAdding: .day, value: trialDurationDays, to: firstLaunchDate) {
            trialEndDate = endDate
            
            // Calculate days remaining
            let components = calendar.dateComponents([.day], from: now, to: endDate)
            daysRemaining = max(0, components.day ?? 0)
            
            // Determine status
            if now < endDate {
                if daysRemaining <= 3 {
                    trialStatus = .expiringSoon(daysRemaining)
                } else {
                    trialStatus = .active(daysRemaining)
                }
            } else {
                trialStatus = .expired
            }
        }
    }
    
    private func getFirstLaunchDate() -> Date {
        if let savedDate = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date {
            return savedDate
        } else {
            // First time launching - save current date
            let now = Date()
            UserDefaults.standard.set(now, forKey: firstLaunchKey)
            return now
        }
    }
    
    // MARK: - Friction Checks
    
    /// Check if user can perform an action based on trial status
    func canPerformAction(_ action: TrialAction) -> Bool {
        switch trialStatus {
        case .active, .expiringSoon, .loading:
            return true
        case .expired:
            return action.isAllowedAfterTrial
        }
    }
    
    /// Get the limit for a specific action (returns nil if unlimited)
    func getLimit(for action: TrialAction) -> Int? {
        switch trialStatus {
        case .active, .expiringSoon, .loading:
            return nil // Unlimited during trial
        case .expired:
            return action.postTrialLimit
        }
    }
}

// MARK: - Supporting Types

enum TrialStatus {
    case loading
    case active(Int) // days remaining
    case expiringSoon(Int) // days remaining (3 or less)
    case expired
    
    var isExpired: Bool {
        if case .expired = self {
            return true
        }
        return false
    }
    
    var isExpiringSoon: Bool {
        if case .expiringSoon = self {
            return true
        }
        return false
    }
}

enum TrialAction {
    case transcribe
    case viewHistory
    case exportTranscription
    case useAdvancedModels
    case cloudSync
    case customDictionary
    
    /// Whether this action is allowed after trial expires
    var isAllowedAfterTrial: Bool {
        switch self {
        case .transcribe:
            return true // Basic transcription always allowed
        case .viewHistory:
            return true // Can view history, but limited
        case .exportTranscription:
            return false // Pro only
        case .useAdvancedModels:
            return false // Pro only
        case .cloudSync:
            return false // Pro only
        case .customDictionary:
            return false // Pro only
        }
    }
    
    /// Limit after trial expires (nil = unlimited, 0 = blocked)
    var postTrialLimit: Int? {
        switch self {
        case .transcribe:
            return 10 // 10 transcriptions per day
        case .viewHistory:
            return 5 // Last 5 items only
        case .exportTranscription:
            return 0 // Blocked
        case .useAdvancedModels:
            return 0 // Blocked
        case .cloudSync:
            return 0 // Blocked
        case .customDictionary:
            return 0 // Blocked
        }
    }
}

