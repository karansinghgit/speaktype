import { describe, expect, it } from "vitest";
import { llmUrlProblem } from "./llm";

describe("llmUrlProblem", () => {
  it("accepts local and cloud base URLs", () => {
    expect(llmUrlProblem("http://localhost:11434/v1")).toBeNull();
    expect(llmUrlProblem("  http://127.0.0.1:1234/v1/  ")).toBeNull();
    expect(llmUrlProblem("https://api.openai.com/v1")).toBeNull();
  });

  it("rejects empty and malformed addresses", () => {
    expect(llmUrlProblem("")).toMatch(/Enter/);
    expect(llmUrlProblem("   ")).toMatch(/Enter/);
    expect(llmUrlProblem("localhost:11434")).not.toBeNull();
    expect(llmUrlProblem("not a url")).toMatch(/valid/);
  });

  it("rejects other protocols", () => {
    expect(llmUrlProblem("ftp://example.com/v1")).toMatch(/http/);
  });

  it("catches the full endpoint pasted in by mistake", () => {
    expect(llmUrlProblem("http://localhost:11434/v1/chat/completions")).toMatch(/Leave off/);
  });
});
