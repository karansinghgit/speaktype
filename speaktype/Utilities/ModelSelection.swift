//
//  ModelSelection.swift
//  speaktype
//
//  Single source of truth for the user's selected transcription model.
//
//  The selection is stored once, in UserDefaults under `selectedModelVariant`, and
//  read via @AppStorage from every screen. Previously an unused `AppSettings.selectedModel`
//  enum shadowed this, and the @AppStorage default diverged between screens (the
//  dashboard defaulted to a concrete variant while others defaulted to empty), so
//  "no model selected" meant different things in different places.
//

import Foundation

enum ModelSelection {
    /// UserDefaults key backing the user's chosen model variant.
    static let defaultsKey = "selectedModelVariant"

    /// Value meaning "no model selected yet" — the single shared default.
    static let none = ""
}
