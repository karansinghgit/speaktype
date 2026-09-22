/**
 * The default system prompt for LLM cleanup. Must match `DEFAULT_LLM_PROMPT` in
 * `src-tauri/src/settings.rs`; a Rust test checks that it does.
 */
export const DEFAULT_LLM_PROMPT =
  "You are a post-processor for voice dictation. Fix typos, remove filler words, correct grammar, and clean up the text while preserving the original meaning. Output ONLY the corrected text with no explanation.";

/** Why `url` can't be used as an API base URL, or null if it looks fine. */
export function llmUrlProblem(url: string): string | null {
  const trimmed = url.trim();
  if (!trimmed) return "Enter the server's address.";
  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return "That isn't a valid address. It should look like http://localhost:11434/v1.";
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return "The address must start with http:// or https://.";
  if (/\/chat\/completions\/?$/.test(parsed.pathname)) return "Leave off /chat/completions. SpeakType adds it.";
  return null;
}
