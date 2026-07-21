# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Resume commands for sessions that `cd` mid-conversation. A transcript lives in the folder encoding the directory the session started in, and `claude -r <id>` only finds it from there, but recap reported the last `cwd` seen in the transcript, so those resume commands failed with "No conversation found with session ID". The path is now the first recorded `cwd` whose encoding matches the transcript's own folder.
- Sessions whose transcript records no `cwd` at all (title-only stubs) no longer show `(unknown path)`; the directory is recovered from a sibling transcript in the same folder.
- `--project` now filters on the same resolved path it displays, instead of matching a drifted directory the session cannot be resumed from.
- `--project` matching is one rule again, applied in the folder encoding, so every spelling of the same directory selects it: `--project my_app`, `--project my-app` (the form printed in `~/.claude/projects`) and `--project work/my_app` are equivalent.
- `--limit` is no longer starved by filtered-out sessions: the internal over-fetch counts the rows it keeps, not the candidates it inspected. Both filters are inside that budget now, so neither a wall of stale history entries (`--project`) nor a run of transcripts that were touched but not talked in (`--since`) can push real matches out of the result.

## [1.2.1] - 2026-07-13

### Changed

- Discovery metadata only, no behavior change: keyword-tuned npm description, expanded npm keywords, and a refined GitHub topic set (added session-resume, python-cli, iterm2). README badges restyled (for-the-badge) and expanded.

## [1.2.0] - 2026-07-13

First public release of the recap skill for Claude Code.

### Added

- `recap.py`, a zero-dependency Python 3 script (stdlib only) that lists recent Claude Code sessions across every project on the machine. The default run is instant and offline.
- Per session it reports last activity, the absolute project path, a short summary, an approximate turn count, the git branch, the model, the session id, and a ready-to-paste `cd <path> && claude -r <id>` resume command.
- Data comes from what Claude Code already writes to disk: `history.jsonl` as the fast index and `projects/<encoded>/<session>.jsonl` transcripts for the displayed rows only. `CLAUDE_CONFIG_DIR` is honored. Project paths are read from the `cwd` and `project` fields, never decoded from the lossy folder-name encoding.
- `--open`: opens every listed session in its own new terminal tab and resumes it there, restoring a whole working set at once. It skips the session recap itself is running in (matched on `CLAUDE_CODE_SESSION_ID`), skips and reports sessions whose project directory is gone, asks for confirmation unless `--yes` is passed, and refuses to run unconfirmed when stdin is not a TTY. Combine with `--dry-run` to preview the tabs without opening anything. Tab opening drives iTerm2 or Terminal through `osascript` and is macOS-only; `--dry-run` works everywhere.
- `--claude-flags "..."`: extra flags passed verbatim to every resumed `claude`, also shown in the printed resume lines and in `--json`. A warning is printed before opening tabs with `--dangerously-skip-permissions`.
- `--terminal auto|iTerm2|Terminal`: picks the app `--open` drives (default: iTerm2 when installed).
- `--pick`: choose a row interactively, then `cd` and `claude -r` straight into it.
- `--smart`: real one-sentence summaries from a single `claude -p` call. This is the only path that touches the network, and it is opt-in.
- Filters and output modes: `--since` (`30m`, `24h`, `7d`, `2w`), `--project` (substring of the absolute path), `--limit`, `--json`, `--color`, `--plain`. `NO_COLOR` and `FORCE_COLOR` are honored.
- Display: day-grouped timeline (Today in green, Yesterday in amber), a 14-day activity sparkline in the header, a stable per-project colored dot, a four-level gray hierarchy with one accent color, and resume lines indented with spaces only so they stay safe to copy.
- Distribution: the repo is at once the skill, a Claude Code plugin (`.claude-plugin/plugin.json`), and the marketplace that serves it (`.claude-plugin/marketplace.json`, entry source `./`).
- `install.sh`, a POSIX sh installer that works from a checkout and from a `curl | sh` pipe. It supports `--force` and `--uninstall`, records a sha256 manifest of what it wrote, and refuses to overwrite or delete locally modified files without `--force`.
- `bin/cli.mjs`, the same install semantics for `npx claude-code-recap`. No postinstall hook: the package writes to the Claude Code config directory only when the command is run.
- CI on every push and pull request: Python syntax check, `recap.py --help`, `shellcheck`, `node --check`, and a smoke test that builds a synthetic config directory and asserts the JSON output.

[Unreleased]: https://github.com/noluyorAbi/claude-code-recap/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/noluyorAbi/claude-code-recap/releases/tag/v1.2.0
