# Release Process

This repository ships releases by pushing a Git tag that starts with `v` (e.g., `v1.0.6`).
The GitHub Actions workflow builds a DMG and attaches it to the GitHub Release.

## Release Criteria
Use your judgment, but a release is usually warranted when one or more are true:
- A user-visible feature or UX improvement lands
- A bugfix affects multiple users or a core flow
- Performance or stability improvements are measurable or noticeable

## Checklist (Manual)
1. Update `CHANGELOG.md`:
   - Move items from `Unreleased` into a new version section.
2. Bump versions in `speaktype.xcodeproj/project.pbxproj`:
   - `MARKETING_VERSION` (public version, e.g., `1.0.6`)
   - `CURRENT_PROJECT_VERSION` (build number, e.g., `2`)
3. Commit changes.
4. Tag and push the release tag:
   - `git tag v1.0.6`
   - `git push origin v1.0.6`
5. Confirm GitHub Actions completes and the DMG appears in the release.

## One-Command Release (script)
If you prefer automation, use the script below:

```bash
scripts/release.sh 1.0.6
```

This will:
- Update version numbers
- Update `CHANGELOG.md`
- Create a commit
- Create a tag

You still need to push the tag and commit:

```bash
git push origin HEAD
git push origin v1.0.6
```
