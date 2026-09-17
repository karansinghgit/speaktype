#!/usr/bin/env node
// Tags the next SpeakType 2 pre-release and pushes the tag. CI then builds
// installers for macOS, Windows and Linux and publishes a GitHub pre-release.
//
//   npm run release            next alpha, e.g. v2.0.0-alpha.5
//   npm run release -- beta    next beta, e.g. v2.0.0-beta.1
//   npm run release -- --dry   show the tag without creating it

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const NOTES = `An early build of SpeakType 2 for macOS, Windows and Linux. Expect rough edges.
SpeakType 1 remains the stable release. See desktop/ROADMAP.md for what's left.

These builds aren't signed by Apple or Microsoft yet, so the first launch needs one extra step:
- macOS: if it says Apple couldn't check the app, open System Settings → Privacy & Security and click Open Anyway.
- Windows: on the SmartScreen prompt, click More info, then Run anyway.`;

const git = (...args) => execFileSync("git", args, { encoding: "utf8" }).trim();
const fail = (message) => {
  console.error(`release: ${message}`);
  process.exit(1);
};

const args = process.argv.slice(2);
const dryRun = args.includes("--dry");
const channel = args.find((a) => !a.startsWith("--")) ?? "alpha";
if (!["alpha", "beta", "rc"].includes(channel)) fail(`unknown channel "${channel}" (use alpha, beta or rc)`);

const { version } = JSON.parse(readFileSync(new URL("../src-tauri/tauri.conf.json", import.meta.url)));
const base = `v${version}-${channel}.`;

if (!dryRun) {
  try {
    execFileSync("gh", ["auth", "status"], { stdio: "ignore" });
  } catch {
    fail("install the GitHub CLI and run `gh auth login` first");
  }
  if (git("status", "--porcelain")) fail("commit or stash your changes first");
  git("fetch", "--tags", "--quiet");
  const branch = git("rev-parse", "--abbrev-ref", "HEAD");
  const upstream = git("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}");
  if (git("rev-list", "--count", `${upstream}..HEAD`) !== "0") fail(`push ${branch} before tagging a release`);
}

const numbers = git("tag", "--list", `${base}*`)
  .split("\n")
  .map((tag) => Number(tag.slice(base.length)))
  .filter(Number.isInteger);
const tag = `${base}${Math.max(0, ...numbers) + 1}`;

if (dryRun) {
  console.log(`Next release: ${tag}`);
  process.exit(0);
}

git("tag", "-a", tag, "-m", `SpeakType ${tag}`);
git("push", "origin", tag);

// Create the release here, with your GitHub login, and let CI attach the
// installers. Since v2.0.0-alpha.7, GitHub refuses to let the build's own token
// create a release, though it can still upload to an existing one.
execFileSync(
  "gh",
  ["release", "create", tag, "--verify-tag", "--prerelease", "--title", `SpeakType ${tag}`, "--notes", NOTES],
  { stdio: "inherit" },
);
console.log(`Pushed ${tag}. CI is building the installers:`);
console.log(`https://github.com/karansinghgit/speaktype/actions/workflows/desktop.yml`);
