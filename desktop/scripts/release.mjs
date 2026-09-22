#!/usr/bin/env node
// Tags a SpeakType 2 release and pushes the tag. CI then builds installers for
// macOS, Windows and Linux and attaches them to the release.
//
//   npm run release            next alpha, e.g. v2.0.0-alpha.5
//   npm run release -- beta    next beta, e.g. v2.0.0-beta.1
//   npm run release -- stable  the version in tauri.conf.json, e.g. v2.0.0, as the
//                              "Latest" release, which SpeakType 1 offers as an update
//   npm run release -- --dry   show the tag without creating it

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";

const PRE_RELEASE_NOTES = `An early build of SpeakType 2 for macOS, Windows and Linux. Expect rough edges.
See desktop/ROADMAP.md for what's left.

The Windows installer isn't signed yet: on the SmartScreen prompt, click More info, then Run anyway.`;

const STABLE_NOTES = `SpeakType 2 is here, for macOS, Windows and Linux.

- One app on every system, with the same models running on your own computer.
- A new design, a menu bar panel, and a smaller, lighter app.
- Upgrading from SpeakType 1 on a Mac brings your history, dictionary and settings with you. Models need downloading again, since SpeakType 2 uses a different format.

The Windows installer isn't signed yet: on the SmartScreen prompt, click More info, then Run anyway.`;

const git = (...args) => execFileSync("git", args, { encoding: "utf8" }).trim();
const fail = (message) => {
  console.error(`release: ${message}`);
  process.exit(1);
};

const args = process.argv.slice(2);
const dryRun = args.includes("--dry");
const channel = args.find((a) => !a.startsWith("--")) ?? "alpha";
if (!["alpha", "beta", "rc", "stable"].includes(channel)) {
  fail(`unknown channel "${channel}" (use alpha, beta, rc or stable)`);
}
const stable = channel === "stable";

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
const tag = stable ? `v${version}` : `${base}${Math.max(0, ...numbers) + 1}`;

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
  [
    "release",
    "create",
    tag,
    "--verify-tag",
    // Even a stable release starts as a pre-release: SpeakType 1 offers whatever is
    // "Latest" as an update, and it must not see a release before its installers exist.
    "--prerelease",
    "--title",
    `SpeakType ${tag}`,
    "--notes",
    stable ? STABLE_NOTES : PRE_RELEASE_NOTES,
  ],
  { stdio: "inherit" },
);
console.log(`Pushed ${tag}. CI is building the installers:`);
console.log(`https://github.com/karansinghgit/speaktype/actions/workflows/desktop.yml`);
if (stable) {
  console.log(`\nOnce the installers are attached, make it the Latest release:`);
  console.log(`  gh release edit ${tag} --prerelease=false --latest`);
}
