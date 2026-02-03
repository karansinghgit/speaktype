#!/usr/bin/env bash
set -euo pipefail

if [[ ${#} -ne 1 ]]; then
  echo "Usage: scripts/release.sh <version>" >&2
  echo "Example: scripts/release.sh 1.0.6" >&2
  exit 1
fi

version="$1"

if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be semver like 1.2.3" >&2
  exit 1
fi

project_file="speaktype.xcodeproj/project.pbxproj"
changelog="CHANGELOG.md"

if [[ ! -f "$project_file" ]]; then
  echo "Missing $project_file" >&2
  exit 1
fi

if [[ ! -f "$changelog" ]]; then
  echo "Missing $changelog" >&2
  exit 1
fi

# Bump MARKETING_VERSION
perl -0pi -e "s/(MARKETING_VERSION = )[^;]+;/\${1}${version};/g" "$project_file"

# Bump CURRENT_PROJECT_VERSION (auto-increment)
current_build=$(perl -ne 'print $1 and exit if /CURRENT_PROJECT_VERSION = (\d+);/' "$project_file")
if [[ -z "${current_build}" ]]; then
  echo "Could not read CURRENT_PROJECT_VERSION" >&2
  exit 1
fi
next_build=$((current_build + 1))
perl -0pi -e "s/(CURRENT_PROJECT_VERSION = )\d+;/\${1}${next_build};/g" "$project_file"

# Update CHANGELOG: move Unreleased to new version section with today's date
release_date=$(date +%Y-%m-%d)
perl -0pi -e "s/## \[Unreleased\]\n- \n/## [Unreleased]\n- \n\n## [${version}] - ${release_date}\n- \n/" "$changelog"

# Commit and tag

git add "$project_file" "$changelog"

git commit -m "release: v${version}"

git tag "v${version}"

echo "Release prepared: v${version} (build ${next_build})"

echo "Next: git push origin HEAD && git push origin v${version}"
