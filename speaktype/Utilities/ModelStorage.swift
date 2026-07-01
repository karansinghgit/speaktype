//
//  ModelStorage.swift
//  speaktype
//
//  Single source of truth for where SpeakType stores downloaded WhisperKit models.
//
//  Historically models were written into `~/Documents/huggingface`. That violates
//  Apple's file-system guidelines (Documents is the user's personal space, not app
//  storage) and, worse, relies on a Documents sandbox prompt that fails on some
//  macOS 15 setups — leaving users unable to load any model (#38). It also littered
//  `~/Documents` with a `huggingface/` folder on first launch, before any download.
//
//  Models now live under Application Support, which needs no special permission.
//

import Foundation

enum ModelStorage {
    /// WhisperKit `downloadBase`. WhisperKit stores CoreML models under
    /// `<base>/models/argmaxinc/whisperkit-coreml/<variant>` and any tokenizer configs
    /// it fetches under `<base>/models/openai/...`.
    static var whisperKitBase: URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("SpeakType", isDirectory: true)
    }

    /// Directory that holds the WhisperKit CoreML model variants.
    static var whisperKitModelsDir: URL {
        whisperKitBase.appendingPathComponent(
            "models/argmaxinc/whisperkit-coreml", isDirectory: true)
    }

    /// Pre-1.x location inside the user's Documents folder. Retained only so existing
    /// downloads can be migrated forward (or discovered) instead of re-downloaded.
    static var legacyBase: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("huggingface", isDirectory: true)
    }

    static var legacyModelsDir: URL? {
        legacyBase?.appendingPathComponent(
            "models/argmaxinc/whisperkit-coreml", isDirectory: true)
    }

    /// Create the models directory. Called lazily — only when a download actually
    /// begins — so a fresh install leaves no trace until the user downloads a model.
    @discardableResult
    static func ensureWhisperKitModelsDir() -> URL {
        let dir = whisperKitModelsDir
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Best-effort, one-time migration of any WhisperKit models sitting in the legacy
    /// Documents location into Application Support. Non-destructive on failure: if a
    /// move fails, the legacy copy is left in place and discovery still finds it.
    static func migrateLegacyModelsIfNeeded() {
        let fm = FileManager.default
        guard let legacyDir = legacyModelsDir,
            fm.fileExists(atPath: legacyDir.path),
            let variants = try? fm.contentsOfDirectory(
                at: legacyDir, includingPropertiesForKeys: [.isDirectoryKey])
        else { return }

        let newDir = whisperKitModelsDir
        try? fm.createDirectory(at: newDir, withIntermediateDirectories: true)

        for variantDir in variants {
            let isDir = (try? variantDir.resourceValues(forKeys: [.isDirectoryKey]))?
                .isDirectory ?? false
            guard isDir else { continue }

            let destination = newDir.appendingPathComponent(variantDir.lastPathComponent)
            guard !fm.fileExists(atPath: destination.path) else { continue }

            do {
                try fm.moveItem(at: variantDir, to: destination)
                print("📦 Migrated model \(variantDir.lastPathComponent) → Application Support")
            } catch {
                print("⚠️ Could not migrate \(variantDir.lastPathComponent): \(error)")
            }
        }
    }
}
