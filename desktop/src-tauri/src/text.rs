//! Post-processing applied to raw transcripts before they are pasted.
//!
//! Ported from the macOS app so both produce the same text:
//! `WhisperService.normalizedTranscription`, `DictionaryService.apply` and
//! `SmartTrailingPunctuation`. The tests at the bottom mirror the Swift tests.

use std::sync::LazyLock;

use regex::{NoExpand, Regex};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DictionaryEntry {
    pub id: String,
    pub trigger: String,
    pub replacement: String,
    #[serde(default = "yes")]
    pub is_enabled: bool,
    #[serde(default = "yes")]
    pub match_whole_word: bool,
}

fn yes() -> bool {
    true
}

pub struct Options<'a> {
    pub smart_trailing_punctuation: bool,
    pub dictionary: &'a [DictionaryEntry],
}

/// The steps after [`normalize_transcription`]: dictionary, then trailing
/// punctuation. LLM post-processing runs between the two, so the dictionary
/// has the last word.
pub fn finish(text: &str, options: &Options) -> String {
    let text = apply_dictionary(text, options.dictionary);
    if options.smart_trailing_punctuation {
        strip_trailing_period(&text)
    } else {
        text
    }
}

/// The patterns below are fixed at compile time and exercised by the tests, so
/// failing to compile one is a programming error.
const STATIC_PATTERN: &str = "static regex pattern is valid";

static PLACEHOLDERS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    [
        r"\[(?:BLANK_AUDIO|SILENCE)\]",
        r"<\|nospeech\|>",
        r"\[\s*S\s*\]",
    ]
    .iter()
    .map(|p| Regex::new(p).expect(STATIC_PATTERN))
    .collect()
});

const NOISE_TERMS: &[&str] = &[
    "applause",
    "background noise",
    "blank audio",
    "breathing",
    "cough",
    "coughing",
    "exhale",
    "heartbeat",
    "indistinct",
    "inaudible",
    "inhale",
    "laughing",
    "laughter",
    "loud noise",
    "muffled speech",
    "music",
    "noise",
    "silence",
    "sigh",
    "sighs",
    "sniffing",
    "static",
    "unclear speech",
    "unintelligible",
    "wind",
    "wind blowing",
    "wind noise",
];

static NOISE_LABEL: LazyLock<Regex> = LazyLock::new(|| {
    let terms: Vec<String> = NOISE_TERMS.iter().map(|t| regex::escape(t)).collect();
    Regex::new(&format!(r"(?i)[\[(]\s*(?:{})\s*[\])]", terms.join("|"))).expect(STATIC_PATTERN)
});

static WHITESPACE: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"\s+").expect(STATIC_PATTERN));

// The Swift pattern ends in a lookahead, `(?=$|[\s,.;:!?])`, which the regex crate
// doesn't support. `remove_fillers` checks that boundary by hand instead.
static FILLER: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?i)(^|[\s,.;:!?])(?:uh+|um+|umm+|uhm+|erm+|hmm+)").expect(STATIC_PATTERN)
});

static SPACE_BEFORE_PUNCTUATION: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\s+([,.;:!?])").expect(STATIC_PATTERN));

/// Removes Whisper's placeholder tokens and bracketed noise labels, and
/// optionally filler words ("Auto Edit").
pub fn normalize_transcription(text: &str, auto_edit: bool) -> String {
    let mut out = text.to_string();
    for re in PLACEHOLDERS.iter() {
        out = re.replace_all(&out, " ").into_owned();
    }
    out = NOISE_LABEL.replace_all(&out, " ").into_owned();
    out = WHITESPACE.replace_all(&out, " ").into_owned();

    if auto_edit {
        out = remove_fillers(&out);
        out = SPACE_BEFORE_PUNCTUATION
            .replace_all(&out, "$1")
            .into_owned();
        out = WHITESPACE.replace_all(&out, " ").into_owned();
    }
    out.trim().to_string()
}

fn is_filler_boundary(c: char) -> bool {
    c.is_whitespace() || ",.;:!?".contains(c)
}

fn remove_fillers(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    let mut copied_to = 0;
    let mut search_from = 0;

    while let Some(caps) = FILLER.captures_at(text, search_from) {
        // Group 0 is the whole match and group 1 always participates (it can
        // match the empty `^`), so both are present on every match.
        let (Some(whole), Some(boundary)) = (caps.get(0), caps.get(1)) else {
            break;
        };
        let rest = &text[whole.end()..];
        let mut after = rest.chars();
        let boundary_ok = match after.next() {
            None => true,
            Some(c) => is_filler_boundary(c),
        };

        if !boundary_ok {
            // Retry one character further on, as a backtracking engine would.
            match text[whole.start()..].chars().next() {
                Some(c) => search_from = whole.start() + c.len_utf8(),
                None => break,
            }
            continue;
        }

        // Keep the boundary character before the filler, drop the filler and at
        // most one punctuation mark straight after it.
        let mut end = whole.end();
        if let Some(c) = rest.chars().next()
            && ",.;:!?".contains(c)
        {
            end += c.len_utf8();
        }
        out.push_str(&text[copied_to..whole.start()]);
        out.push_str(boundary.as_str());
        copied_to = end;
        search_from = end;
        if search_from >= text.len() {
            break;
        }
    }
    out.push_str(&text[copied_to..]);
    out
}

/// Applies enabled dictionary entries in order. Each entry sees the output of
/// the ones before it.
pub fn apply_dictionary(text: &str, entries: &[DictionaryEntry]) -> String {
    if text.is_empty() || entries.is_empty() {
        return text.to_string();
    }
    let mut out = text.to_string();
    for entry in entries.iter().filter(|e| e.is_enabled) {
        let trigger = entry.trigger.trim();
        if trigger.is_empty() {
            continue;
        }
        let Some(re) = dictionary_regex(trigger, entry.match_whole_word) else {
            continue;
        };
        out = re
            .replace_all(&out, NoExpand(&entry.replacement))
            .into_owned();
    }
    out
}

fn dictionary_regex(trigger: &str, whole_word: bool) -> Option<Regex> {
    let mut pattern = regex::escape(trigger).replace(' ', r"\s+");
    let is_word_char = |c: Option<char>| c.is_some_and(char::is_alphanumeric);
    if whole_word && is_word_char(trigger.chars().next()) {
        pattern = format!(r"\b{pattern}");
    }
    if whole_word && is_word_char(trigger.chars().last()) {
        pattern = format!(r"{pattern}\b");
    }
    Regex::new(&format!("(?i){pattern}")).ok()
}

static NUMBER: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)^\+?\(?\d(?:[\d\s.,\-()/:]*\d)?$").expect(STATIC_PATTERN));
static EMAIL: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?i)^[^\s@]+@[^\s@]+\.[^\s@]+$").expect(STATIC_PATTERN));
static URL: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r"(?i)^(?:[a-z][a-z0-9+.\-]*://\S+|www\.\S+\.\S+|[a-z0-9\-]+(?:\.[a-z0-9\-]+)*\.[a-z]{2,}(?:[/:?#]\S*)?)$",
    )
    .expect(STATIC_PATTERN)
});

/// Drops the period Whisper adds after short non-prose dictations such as an
/// email address, URL, number or single word. Sentences keep their period.
pub fn strip_trailing_period(text: &str) -> String {
    let Some(candidate) = text.trim().strip_suffix('.') else {
        return text.to_string();
    };
    if candidate.is_empty() || candidate.ends_with('.') {
        return text.to_string();
    }
    let is_plain_token = !candidate.chars().any(|c| c.is_whitespace() || c == '.');
    if NUMBER.is_match(candidate)
        || EMAIL.is_match(candidate)
        || URL.is_match(candidate)
        || is_plain_token
    {
        candidate.to_string()
    } else {
        text.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(trigger: &str, replacement: &str, whole_word: bool) -> DictionaryEntry {
        DictionaryEntry {
            id: trigger.to_string(),
            trigger: trigger.to_string(),
            replacement: replacement.to_string(),
            is_enabled: true,
            match_whole_word: whole_word,
        }
    }

    #[test]
    fn normalization_removes_whisper_placeholders() {
        assert_eq!(
            normalize_transcription(" [BLANK_AUDIO]  hello   <|nospeech|> [SILENCE] ", false),
            "hello"
        );
        assert_eq!(
            normalize_transcription("[wind blowing] (heartbeat) answer [S]", false),
            "answer"
        );
        assert_eq!(
            normalize_transcription("[wind] (Loud noise) (indistinct)", false),
            ""
        );
    }

    #[test]
    fn placeholders_are_case_sensitive_but_noise_labels_are_not() {
        assert_eq!(
            normalize_transcription("[blank_audio] hi", false),
            "[blank_audio] hi"
        );
        assert_eq!(normalize_transcription("[MUSIC] hi (wind)", false), "hi");
    }

    #[test]
    fn auto_edit_removes_fillers() {
        assert_eq!(normalize_transcription("um um", true), "");
        assert_eq!(
            normalize_transcription("So, um, I think uhh we should go.", true),
            "So, I think we should go."
        );
        assert_eq!(normalize_transcription("Hmm. Okay", true), "Okay");
        // Words that merely start with a filler are left alone.
        assert_eq!(
            normalize_transcription("umbrella hummus", true),
            "umbrella hummus"
        );
        assert_eq!(normalize_transcription("um, hm er", true), "hm er");
        // Auto Edit off keeps fillers.
        assert_eq!(normalize_transcription("um hello", false), "um hello");
    }

    #[test]
    fn dictionary_matches_whole_words_case_insensitively() {
        let entries = [entry("speak type", "SpeakType", true)];
        assert_eq!(
            apply_dictionary("I use Speak   Type daily", &entries),
            "I use SpeakType daily"
        );
        let entries = [entry("cat", "dog", true)];
        assert_eq!(
            apply_dictionary("cat concatenate", &entries),
            "dog concatenate"
        );
        let entries = [entry("cat", "dog", false)];
        assert_eq!(
            apply_dictionary("cat concatenate", &entries),
            "dog condogenate"
        );
    }

    #[test]
    fn dictionary_skips_boundaries_for_symbols_and_inserts_literally() {
        let entries = [entry("@home", "$1 home", true)];
        assert_eq!(
            apply_dictionary("at x@home now", &entries),
            "at x$1 home now"
        );
    }

    #[test]
    fn dictionary_rules_chain_and_skip_disabled() {
        let mut disabled = entry("b", "z", true);
        disabled.is_enabled = false;
        let entries = [entry("a", "b", true), disabled, entry("b", "c", true)];
        assert_eq!(apply_dictionary("a", &entries), "c");
    }

    #[test]
    fn smart_trailing_punctuation_strips_non_prose() {
        let cases = [
            ("roy.sanhik@gmail.com.", "roy.sanhik@gmail.com"),
            (
                "https://example.com/pricing.",
                "https://example.com/pricing",
            ),
            ("www.example.com.", "www.example.com"),
            ("example.com.", "example.com"),
            ("example.com/docs/setup.", "example.com/docs/setup"),
            ("3.14.", "3.14"),
            ("1,000.", "1,000"),
            ("1.2.3.", "1.2.3"),
            ("+49 170 1234567.", "+49 170 1234567"),
            ("(555) 123-4567.", "(555) 123-4567"),
            ("5.", "5"),
            ("Hello.", "Hello"),
            ("ABC123.", "ABC123"),
            ("€1,000.", "€1,000"),
            (" roy.sanhik@gmail.com. ", "roy.sanhik@gmail.com"),
        ];
        for (input, expected) in cases {
            assert_eq!(strip_trailing_period(input), expected, "input: {input:?}");
        }
    }

    #[test]
    fn smart_trailing_punctuation_keeps_prose() {
        for input in [
            "This is a normal sentence.",
            "Email me at roy@gmail.com.",
            "Wait...",
            "Wait…",
            "U.S.",
            "Really?",
            "Stop!",
            ".",
            "",
            "roy@gmail.com",
        ] {
            assert_eq!(strip_trailing_period(input), input, "input: {input:?}");
        }
    }

    #[test]
    fn filler_removal_handles_unicode_neighbours() {
        // Accented letters after a filler make it part of a word.
        assert_eq!(normalize_transcription("umé ummé", true), "umé ummé");
        // Multi-byte text around a removed filler survives intact.
        assert_eq!(
            normalize_transcription("café, um, naïve 日本語 uh", true),
            "café, naïve 日本語"
        );
        // An ellipsis character isn't a boundary, so the filler stays.
        assert_eq!(normalize_transcription("um… right", true), "um… right");
        assert_eq!(normalize_transcription("", true), "");
        assert_eq!(normalize_transcription("   ", true), "");
    }

    #[test]
    fn dictionary_handles_unicode_and_empty_input() {
        let entries = [entry("café", "coffee shop", true)];
        assert_eq!(
            apply_dictionary("Meet at the CAFÉ, not cafés", &entries),
            "Meet at the coffee shop, not cafés"
        );
        let entries = [entry("  ", "x", true), entry("ß", "ss", false)];
        assert_eq!(apply_dictionary("Straße", &entries), "Strasse");
        assert_eq!(apply_dictionary("", &entries), "");
    }

    #[test]
    fn smart_trailing_punctuation_handles_unicode() {
        assert_eq!(strip_trailing_period("東京."), "東京");
        assert_eq!(strip_trailing_period("naïve café."), "naïve café.");
        assert_eq!(strip_trailing_period("é"), "é");
    }

    #[test]
    fn finish_respects_the_punctuation_toggle() {
        let on = Options {
            smart_trailing_punctuation: true,
            dictionary: &[],
        };
        let off = Options {
            smart_trailing_punctuation: false,
            dictionary: &[],
        };
        assert_eq!(finish("Hello.", &on), "Hello");
        assert_eq!(finish("Hello.", &off), "Hello.");
        assert_eq!(finish("example.com.", &on), "example.com");
    }
}
