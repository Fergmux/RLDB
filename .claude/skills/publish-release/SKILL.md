---
name: publish-release
description: "Upload RLDB to GitHub (github.com/Fergmux/RLDB, public): sync the source, then release the latest exported playtest and dev builds as v<version>. Use when the owner asks to upload, publish or release a build."
argument-hint: "[sync | release | release --clobber] [--notes \"text\"]"
user-invocable: true
allowed-tools: Read, Bash, PowerShell
---

# Publish to GitHub

The owner authorised (2026-11-04) uploading the project and its builds to
**github.com/Fergmux/RLDB**. That repo is **PUBLIC**: anyone can read the source and download the
releases. All the work is in `tools/publish_github.py`; this skill only adds the checks around it.

## 1. Before anything goes up

1. `gh` must be logged in: `"C:\Program Files\GitHub CLI\gh.exe" auth status`. If not, ask the owner to
   run `gh auth login -h github.com -p https -w` in their own terminal. Never ask for or store a token.
2. Commit what should be public first. `sync` uploads only **committed** history of `main` and
   `build/rldb-game`; it never pushes the working tree or the `worktree-agent-*` branches.
3. Scan the commits being added for secrets (service-account JSON, private keys, refresh tokens, API keys
   other than the Firebase web key in `rldb/data/telemetry_config.json`, which ships in every build).
   On any hit: stop and tell the owner. Standing rule: no credentials in checked-in files.
4. For `release`, the builds must already be exported (`build/windows`, `build/windows-dev`), and
   `config/version` in `rldb/project.godot` bumped if this is a new release. The script never exports.
   If an export is needed, follow the normal procedure (check `Get-Process RLDB*` first).

## 2. Run it

From the repo root:

```
python -I -X utf8 tools/publish_github.py sync                # source only
python -I -X utf8 tools/publish_github.py release             # sync + new release v<version>
python -I -X utf8 tools/publish_github.py release --clobber   # same version: replace its zips and notes
python -I -X utf8 tools/publish_github.py release --notes "What changed for testers"
```

Run it in the background (the filter and upload take a few minutes). What it does:
- `sync`:
  - takes a throwaway hardlinked clone in `..\.rldb-github-mirror`;
  - strips `production/qa/evidence/` from all history (5.9 GB of screenshots that would break GitHub's
    limits) and pushes `main` + `build/rldb-game`;
  - never force-pushes. A refused push means GitHub has commits this PC lacks: stop and ask.
  - Hashes on GitHub differ from the local ones.
- `release`:
  - zips `build/windows` -> `build/RLDB-friends.zip` (playtest) and `build/windows-dev` ->
    `build/RLDB-dev.zip` (dev);
  - warns if a build is older than the last commit to `rldb/`;
  - syncs, then creates release `v<version>` at the tip of `build/rldb-game`, marked latest.

## 3. Report

Give the owner the release URL from the last line, the two asset sizes, and any WARNING lines (stale
build, uncommitted changes). Mention that the release is public.
