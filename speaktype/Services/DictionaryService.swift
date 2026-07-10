import Combine
import Foundation
import SwiftUI  // for RangeReplaceableCollection.remove(atOffsets:)

/// A single dictionary rule.
///
/// A rule maps a spoken `trigger` (what the recognizer hears) to the
/// `replacement` text that gets inserted instead. It powers two use cases:
///
/// 1. **Snippets / text expansion** — say "my email" and get
///    `roy.sanhik@gmail.com` inserted. The trigger is a phrase, the
///    replacement is arbitrary text.
/// 2. **Spelling / vocabulary fixes** — the model consistently mishears a
///    name or term (e.g. "figjam" → "FigJam"); the rule rewrites it after
///    transcription.
///
/// Replacements run fully offline as a post-processing pass on the final
/// transcript, so they work identically for every engine (Whisper, Parakeet).
struct DictionaryEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// What you say / what the model transcribes.
    var trigger: String
    /// The text inserted in place of the trigger. Leave empty to delete the trigger.
    var replacement: String
    /// When false the rule is kept but not applied.
    var isEnabled: Bool = true
    /// Only match when the trigger stands alone as whole words (recommended).
    var matchWholeWord: Bool = true

    var trimmedTrigger: String {
        trigger.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Stores the user's dictionary rules and applies them to transcripts.
///
/// Rules are persisted as JSON in `UserDefaults` (mirroring `HistoryService`).
/// The transcription path reads the rules through the thread-safe static
/// `apply(to:)`, which decodes straight from `UserDefaults` so it never
/// touches the `@Published` state across threads.
final class DictionaryService: ObservableObject {
    static let shared = DictionaryService()

    @Published private(set) var entries: [DictionaryEntry] = []

    private static let saveKey = "dictionary_entries"
    private static let migrationFlagKey = "dictionaryDidMigrateAutoEditRules"
    private static let legacyRulesKey = "customReplacementRules"

    private init() {
        migrateLegacyRulesIfNeeded()
        loadEntries()
    }

    // MARK: - CRUD

    func addEntry(trigger: String, replacement: String, matchWholeWord: Bool = true) {
        let entry = DictionaryEntry(
            trigger: trigger,
            replacement: replacement,
            matchWholeWord: matchWholeWord
        )
        entries.insert(entry, at: 0)
        save()
    }

    func update(_ entry: DictionaryEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        save()
    }

    func setEnabled(_ isEnabled: Bool, for id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].isEnabled = isEnabled
        save()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: Self.saveKey)
        }
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: Self.saveKey),
              let decoded = try? JSONDecoder().decode([DictionaryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    /// One-time import of the old freeform `customReplacementRules` string
    /// (one `from => to` rule per line) into structured entries so existing
    /// users keep their replacements.
    private func migrateLegacyRulesIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.migrationFlagKey) else { return }
        defer { defaults.set(true, forKey: Self.migrationFlagKey) }

        // Nothing already stored under the new key and there are legacy rules.
        guard defaults.data(forKey: Self.saveKey) == nil else { return }
        let raw = defaults.string(forKey: Self.legacyRulesKey) ?? ""
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let migrated: [DictionaryEntry] = raw
            .split(whereSeparator: \.isNewline)
            .compactMap { rawLine in
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !line.isEmpty else { return nil }

                for separator in ["=>", "->", "="] {
                    let parts = line.components(separatedBy: separator)
                    guard parts.count >= 2 else { continue }
                    let source = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let replacement = parts[1...].joined(separator: separator)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !source.isEmpty else { return nil }
                    return DictionaryEntry(trigger: source, replacement: replacement)
                }
                return nil
            }

        guard !migrated.isEmpty else { return }
        if let encoded = try? JSONEncoder().encode(migrated) {
            defaults.set(encoded, forKey: Self.saveKey)
        }
    }

    // MARK: - Applying rules to a transcript

    /// Apply every enabled rule to `text`. Safe to call from any thread —
    /// it reads the rules straight from `UserDefaults`.
    static func apply(to text: String) -> String {
        guard !text.isEmpty,
              let data = UserDefaults.standard.data(forKey: saveKey),
              let entries = try? JSONDecoder().decode([DictionaryEntry].self, from: data),
              !entries.isEmpty
        else { return text }

        var result = text
        for entry in entries where entry.isEnabled {
            let trigger = entry.trimmedTrigger
            guard !trigger.isEmpty else { continue }
            result = replace(
                trigger,
                with: entry.replacement,
                in: result,
                matchWholeWord: entry.matchWholeWord
            )
        }
        return result
    }

    /// Word-boundary-aware, case-insensitive replacement. Spaces in the trigger
    /// match any run of whitespace, so multi-word phrases survive minor spacing
    /// differences. Matching is always case-insensitive because the recognizer,
    /// not the user, decides how a spoken phrase is capitalized.
    private static func replace(_ source: String, with replacement: String, in text: String,
                                matchWholeWord: Bool) -> String {
        let escapedSource = NSRegularExpression.escapedPattern(for: source)
            .replacingOccurrences(of: " ", with: #"\s+"#)

        let needsLeadingBoundary = matchWholeWord
            && (source.first?.isLetter == true || source.first?.isNumber == true)
        let needsTrailingBoundary = matchWholeWord
            && (source.last?.isLetter == true || source.last?.isNumber == true)
        let pattern =
            "\(needsLeadingBoundary ? #"\b"# : "")\(escapedSource)\(needsTrailingBoundary ? #"\b"# : "")"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else {
            return text
        }

        let range = NSRange(text.startIndex..., in: text)
        // Escape the user-supplied replacement so `$` / `\` stay literal.
        let template = NSRegularExpression.escapedTemplate(for: replacement)
        return regex.stringByReplacingMatches(
            in: text, options: [], range: range, withTemplate: template)
    }
}
