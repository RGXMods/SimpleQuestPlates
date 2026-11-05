# /.github

Repository automation and platform metadata.

## Contents

- `workflows/` - GitHub Actions workflows used for packaging and release

## Notes

- Release automation is tag-driven (`v*`).
- Packaging uses our own `tools/release/packager.mjs`; CurseForge, Wago and WoWInterface publishing use tokens from repository secrets.
