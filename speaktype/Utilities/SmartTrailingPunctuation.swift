import Foundation

/// Removes the sentence-final period speech models append when the dictated
/// content isn't prose — an email address, URL, number, or lone token.
///
/// Whisper (and Parakeet) punctuate everything as a sentence, so dictating an
/// email into a login field yields `roy@example.com.` and the trailing dot
/// breaks the address. This pass runs on the final transcript, after
/// dictionary replacements, so spoken snippets that expand to an address
/// benefit too.
///
/// The heuristic is deliberately conservative: it only ever touches a
/// transcript that ends in exactly one `.` and is, in its entirety, one of
/// the recognized shapes. Multi-word dictation, ellipses, `?`/`!`, and
/// dotted abbreviations like `U.S.` are never modified.
enum SmartTrailingPunctuation {
    static let defaultsKey = "smartTrailingPunctuation"

    /// Default-on: an absent key counts as enabled.
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: defaultsKey) as? Bool ?? true
    }

    /// Apply the heuristic if the user hasn't turned the toggle off.
    static func apply(to text: String) -> String {
        isEnabled ? strip(text) : text
    }

    /// The toggle-independent heuristic. Returns `text` unchanged unless the
    /// whole (trimmed) transcript is an email/URL/number/single token with a
    /// single trailing period.
    static func strip(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Only a lone trailing period qualifies — "..", "…", "?", "!" are
        // deliberate punctuation and stay.
        guard trimmed.hasSuffix("."), !trimmed.hasSuffix("..") else { return text }

        let candidate = String(trimmed.dropLast())
        guard !candidate.isEmpty else { return text }

        if isNumber(candidate) || isEmail(candidate) || isURL(candidate)
            || isPlainToken(candidate) {
            return candidate
        }
        return text
    }

    // MARK: - Content shapes

    /// Digits with common separators: "3.14", "1,000", "1.2.3",
    /// "+49 170 1234567", "(555) 123-4567", "12:30", "01/02/2026".
    private static func isNumber(_ text: String) -> Bool {
        matches(text, #"^\+?\(?\d(?:[\d\s.,\-()/:]*\d)?$"#)
    }

    private static func isEmail(_ text: String) -> Bool {
        matches(text, #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#)
    }

    /// Explicit scheme, www-prefixed, or bare domain with a plausible TLD
    /// (final label ≥ 2 letters, so "U.S" doesn't read as a domain).
    private static func isURL(_ text: String) -> Bool {
        matches(
            text,
            #"^(?:[a-z][a-z0-9+.\-]*://\S+|www\.\S+\.\S+|[a-z0-9\-]+(?:\.[a-z0-9\-]+)*\.[a-z]{2,}(?:[/:?#]\S*)?)$"#
        )
    }

    /// A lone token with no internal dots — "Hello", "ok", "ABC123", "€1,000".
    /// Tokens with internal dots must qualify as email/URL/number instead, so
    /// dotted abbreviations keep their final period.
    private static func isPlainToken(_ text: String) -> Bool {
        !text.contains(where: \.isWhitespace) && !text.contains(".")
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
