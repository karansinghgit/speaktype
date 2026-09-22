//! Optional clean-up of finished transcripts by an LLM, through any
//! OpenAI-compatible chat completions API (Ollama, LM Studio, OpenAI, ...).
//!
//! Every failure is returned as an error so the caller can fall back to the
//! untouched transcript.

use std::time::Duration;

use serde::Deserialize;
use serde_json::json;

use crate::settings::Settings;

/// The user is waiting for the paste, so give up quickly and use the original text.
const TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Debug, Clone, Copy)]
pub struct Config<'a> {
    pub base_url: &'a str,
    pub model: &'a str,
    pub prompt: &'a str,
    pub api_key: &'a str,
}

impl<'a> Config<'a> {
    pub fn from_settings(settings: &'a Settings) -> Self {
        Self {
            base_url: &settings.llm_base_url,
            model: &settings.llm_model,
            prompt: &settings.llm_prompt,
            api_key: &settings.llm_api_key,
        }
    }
}

/// Sends `text` to the LLM and returns its reply. Blocks, so call it from a worker thread.
pub fn polish(text: &str, config: &Config<'_>) -> Result<String, String> {
    tauri::async_runtime::block_on(request(text, config, TIMEOUT))
}

async fn request(text: &str, config: &Config<'_>, timeout: Duration) -> Result<String, String> {
    #[derive(Deserialize)]
    struct Response {
        choices: Vec<Choice>,
    }
    #[derive(Deserialize)]
    struct Choice {
        message: Message,
    }
    #[derive(Deserialize)]
    struct Message {
        content: String,
    }

    let body = json!({
        "model": config.model,
        "messages": [
            {"role": "system", "content": config.prompt},
            {"role": "user", "content": text},
        ],
        "temperature": 0.3,
        "stream": false,
    });
    let client = reqwest::Client::builder()
        .timeout(timeout)
        .build()
        .map_err(|e| format!("couldn't set up the request: {e}"))?;
    let mut request = client.post(endpoint(config.base_url)).json(&body);
    if !config.api_key.is_empty() {
        request = request.bearer_auth(config.api_key);
    }
    let response: Response = request
        .send()
        .await
        .and_then(|r| r.error_for_status())
        .map_err(|e| format!("request failed: {}", with_causes(&e)))?
        .json()
        .await
        .map_err(|e| format!("couldn't read the reply: {}", with_causes(&e)))?;

    let reply = response
        .choices
        .into_iter()
        .next()
        .map(|choice| choice.message.content.trim().to_string())
        .unwrap_or_default();
    if reply.is_empty() {
        return Err("the reply was empty".into());
    }
    Ok(reply)
}

fn endpoint(base_url: &str) -> String {
    format!("{}/chat/completions", base_url.trim().trim_end_matches('/'))
}

/// reqwest's message alone ("error sending request for url ...") hides why, so
/// append each underlying cause, e.g. "... : Connection refused (os error 61)".
fn with_causes(error: &dyn std::error::Error) -> String {
    let mut message = error.to_string();
    let mut source = error.source();
    while let Some(cause) = source {
        message.push_str(": ");
        message.push_str(&cause.to_string());
        source = cause.source();
    }
    message
}
#[cfg(test)]
mod tests {
    use std::{
        io::{Read, Write},
        net::TcpListener,
        thread::{self, JoinHandle},
        time::Instant,
    };

    use super::*;

    const CONFIG: Config<'static> = Config {
        base_url: "",
        model: "qwen2.5:0.5b",
        prompt: "Fix the text.",
        api_key: "",
    };

    /// Serves one request with `status` and `body`, returning the base URL and
    /// a handle that yields the raw request.
    fn serve_once(status: &str, body: &str) -> (String, JoinHandle<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}/v1", listener.local_addr().unwrap());
        let response = format!(
            "HTTP/1.1 {status}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
            body.len()
        );
        let handle = thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let request = read_request(&mut stream);
            stream.write_all(response.as_bytes()).unwrap();
            request
        });
        (url, handle)
    }

    /// Reads the headers, then as many body bytes as Content-Length says.
    fn read_request(stream: &mut impl Read) -> String {
        let mut bytes = Vec::new();
        let mut buf = [0; 4096];
        loop {
            let n = stream.read(&mut buf).unwrap();
            bytes.extend_from_slice(&buf[..n]);
            let text = String::from_utf8_lossy(&bytes);
            if let Some(end) = text.find("\r\n\r\n") {
                let length = text[..end]
                    .lines()
                    .find_map(|line| {
                        let (name, value) = line.split_once(':')?;
                        name.eq_ignore_ascii_case("content-length")
                            .then(|| value.trim().parse::<usize>().ok())?
                    })
                    .unwrap_or(0);
                if bytes.len() >= end + 4 + length || n == 0 {
                    return String::from_utf8_lossy(&bytes).into_owned();
                }
            }
            if n == 0 {
                return String::from_utf8_lossy(&bytes).into_owned();
            }
        }
    }

    fn reply(content: &str) -> String {
        json!({"choices": [{"message": {"role": "assistant", "content": content}}]}).to_string()
    }

    fn polish_at(url: &str, config: Config<'_>) -> Result<String, String> {
        let config = Config {
            base_url: url,
            ..config
        };
        tauri::async_runtime::block_on(request("um so hello world", &config, TIMEOUT))
    }

    #[test]
    fn returns_the_trimmed_reply() {
        let (url, server) = serve_once("200 OK", &reply("  Hello, world.\n"));
        assert_eq!(polish_at(&url, CONFIG).unwrap(), "Hello, world.");
        server.join().unwrap();
    }

    #[test]
    fn sends_the_model_prompt_and_transcript_to_chat_completions() {
        let (url, server) = serve_once("200 OK", &reply("ok"));
        polish_at(&url, CONFIG).unwrap();
        let request = server.join().unwrap();

        assert!(
            request.starts_with("POST /v1/chat/completions "),
            "{request}"
        );
        let body: serde_json::Value =
            serde_json::from_str(request.split_once("\r\n\r\n").unwrap().1).unwrap();
        assert_eq!(body["model"], "qwen2.5:0.5b");
        assert_eq!(body["messages"][0]["role"], "system");
        assert_eq!(body["messages"][0]["content"], "Fix the text.");
        assert_eq!(body["messages"][1]["role"], "user");
        assert_eq!(body["messages"][1]["content"], "um so hello world");
        assert!(!request.to_ascii_lowercase().contains("authorization:"));
    }

    #[test]
    fn sends_the_api_key_only_when_there_is_one() {
        let (url, server) = serve_once("200 OK", &reply("ok"));
        let config = Config {
            api_key: "sk-test",
            ..CONFIG
        };
        polish_at(&url, config).unwrap();
        let request = server.join().unwrap().to_ascii_lowercase();
        assert!(
            request.contains("authorization: bearer sk-test"),
            "{request}"
        );
    }

    #[test]
    fn server_errors_bad_json_and_empty_replies_fail() {
        for (status, body) in [
            ("500 Internal Server Error", reply("ignored")),
            (
                "404 Not Found",
                r#"{"error": "model not found"}"#.to_string(),
            ),
            ("200 OK", "not json".to_string()),
            ("200 OK", r#"{"choices": []}"#.to_string()),
            ("200 OK", reply("   ")),
        ] {
            let (url, server) = serve_once(status, &body);
            assert!(polish_at(&url, CONFIG).is_err(), "{status} {body}");
            server.join().unwrap();
        }
    }

    #[test]
    fn gives_up_when_the_server_does_not_answer() {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let config = Config {
            base_url: &format!("http://{}/v1", listener.local_addr().unwrap()),
            ..CONFIG
        };
        let started = Instant::now();
        let result =
            tauri::async_runtime::block_on(request("hello", &config, Duration::from_millis(300)));
        assert!(result.is_err());
        assert!(started.elapsed() < Duration::from_secs(5));
        drop(listener);
    }

    #[test]
    fn fails_when_nothing_is_listening() {
        let port = TcpListener::bind("127.0.0.1:0")
            .unwrap()
            .local_addr()
            .unwrap()
            .port();
        assert!(polish_at(&format!("http://127.0.0.1:{port}/v1"), CONFIG).is_err());
    }

    #[test]
    fn endpoint_ignores_trailing_slashes_and_whitespace() {
        let expected = "http://localhost:11434/v1/chat/completions";
        assert_eq!(endpoint("http://localhost:11434/v1"), expected);
        assert_eq!(endpoint("http://localhost:11434/v1/"), expected);
        assert_eq!(endpoint(" http://localhost:11434/v1// "), expected);
    }
}
