# recap

**See every recent Claude Code session across every project on your machine, and get the exact command to jump back into any of them.**

Claude Code's built-in `/resume` only lists sessions for the directory you are standing in. After a reboot, a crash, or a week of jumping between five repos, there is no way to answer "what was I working on, and where did I leave off". `recap` answers that in one command, and can re-open a whole working set in terminal tabs.

[![npm version](https://img.shields.io/npm/v/claude-code-recap?style=for-the-badge&logo=npm&logoColor=white&label=npm&labelColor=0b0b0b&color=d97757)](https://www.npmjs.com/package/claude-code-recap)
[![npm downloads](https://img.shields.io/npm/dm/claude-code-recap?style=for-the-badge&logo=npm&logoColor=white&label=downloads&labelColor=0b0b0b&color=3a3a3a)](https://www.npmjs.com/package/claude-code-recap)
[![ci](https://img.shields.io/github/actions/workflow/status/noluyorAbi/claude-code-recap/ci.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=ci&labelColor=0b0b0b)](https://github.com/noluyorAbi/claude-code-recap/actions/workflows/ci.yml)
[![license](https://img.shields.io/github/license/noluyorAbi/claude-code-recap?style=for-the-badge&label=license&labelColor=0b0b0b&color=3a3a3a)](LICENSE)

[![Claude Code](https://img.shields.io/badge/Claude_Code-skill_%2B_plugin-d97757?style=for-the-badge&logo=claude&logoColor=white&labelColor=0b0b0b)](https://code.claude.com/docs/en/skills)
[![python](https://img.shields.io/badge/python-3_stdlib-3a3a3a?style=for-the-badge&logo=python&logoColor=white&labelColor=0b0b0b)](https://www.python.org/)
[![dependencies](https://img.shields.io/badge/dependencies-zero-3a3a3a?style=for-the-badge&labelColor=0b0b0b)](package.json)
[![platform](https://img.shields.io/badge/platform-macOS_%7C_Linux-3a3a3a?style=for-the-badge&logo=apple&logoColor=white&labelColor=0b0b0b)](#requirements)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-d97757?style=for-the-badge&labelColor=0b0b0b)](#contributing)

<a href="assets/demo.mp4"><img src="assets/demo.gif" alt="recap listing recent Claude Code sessions across several projects, then re-opening them in terminal tabs" width="100%"></a>

The GIF above is a downsampled loop. The full-quality recording is [`assets/demo.mp4`](assets/demo.mp4).

---

## <img src="assets/icons/clock.svg" width="16" align="center"> What it does

`recap` reads the session logs Claude Code already writes to disk and prints a day-grouped timeline of your recent sessions. Per session: last activity, the absolute project path, a short summary, an approximate turn count, the git branch, the model, the session id, and a ready-to-paste `cd <path> && claude -r <id>` resume command.

- Every project on the machine, not just the current directory.
- `--pick` jumps straight into one session.
- `--open` re-opens all of them, each in its own terminal tab, already resumed.
- Pure Python 3 standard library. No dependencies, no build step.
- Offline and read-only by default. The only network path is the opt-in `--smart` flag.

## <img src="assets/icons/download.svg" width="16" align="center"> Install

Three ways in, all live. The plugin marketplace is the native path; `npx` and `curl | sh` install the same skill into `~/.claude/skills/recap`.

### 1. Plugin marketplace (recommended)

The repo is its own Claude Code marketplace. Two lines inside any Claude Code session:

```
/plugin marketplace add noluyorAbi/claude-code-recap
/plugin install claude-code-recap@noluyorabi-plugins
```

Then `/reload-plugins`, and invoke it as:

```
/claude-code-recap:recap
```

Plugin skills are namespaced `plugin-name:skill-name`, so this cannot collide with anything else you have installed. Add the marketplace by repo (`owner/repo`), not by a direct URL to `marketplace.json`: a URL-added marketplace downloads only that one file, and the entry's relative source (`./`) would not resolve.

### 2. npx

Installs the skill into your Claude Code skills directory (`~/.claude/skills/recap`, or `$CLAUDE_CONFIG_DIR/skills/recap`):

```bash
npx claude-code-recap
```

Then invoke it as `/recap`. The package has no postinstall hook; it writes only when you run the command. It records a sha256 manifest of the files it wrote and refuses to clobber a directory it did not install or files you have edited, unless you pass `--force`.

```bash
npx claude-code-recap --force      # overwrite local edits
npx claude-code-recap --uninstall  # remove what it installed
```

### 3. curl

Same install, no Node:

```bash
curl -fsSL https://raw.githubusercontent.com/noluyorAbi/claude-code-recap/main/install.sh | sh
```

Same guarantees as the npx path: sha256 manifest, no silent overwrite, `--force` and `--uninstall` supported.

```bash
curl -fsSL https://raw.githubusercontent.com/noluyorAbi/claude-code-recap/main/install.sh | sh -s -- --uninstall
```

### 4. skills CLI

If you use the [`skills`](https://skills.sh) directory CLI, recap resolves straight from this repo and installs across every agent it manages:

```bash
npx skills add noluyorAbi/claude-code-recap
```

Claude Code picks up `~/.claude/skills` without a restart. Restart only if that directory did not exist when the session started.

Pick one path. Installing the skill *and* the plugin gives you `/recap` and `/claude-code-recap:recap` side by side; they will not conflict, but you carry two copies of the description in the skill listing.

## <img src="assets/icons/terminal.svg" width="16" align="center"> What you see

```
◆ recap                                         6 sessions · 5 projects   14d ▂▁▄▃▅▂▆█▃▅▇▄▆█

── Today ─────────────────────────────────────────────────────────────────────────────────

  1 ● 14:22 12m ago  Fix the flaky auth test in the checkout flow                a3f91c02
             ~/repos/shop-web  ·  ⎇ fix/flaky-auth  ·  opus-4.8  ·  46 turns
             cd ~/repos/shop-web && claude -r a3f91c02-7b4e-4d19-9c2a-5f83e6d1b704

  2 ● 11:05  3h ago  Rewrite the ingest worker to stream instead of buffer       6d20be14
             ~/repos/pipeline  ·  ⎇ main  ·  sonnet-4.5  ·  18 turns
             cd ~/repos/pipeline && claude -r 6d20be14-0a8f-49c7-8b31-1e4d90c7aa52

  3 ● 09:41  5h ago  Draft the migration plan for the billing schema             c17ff5a9
             ~/repos/billing-svc  ·  ⎇ chore/migrate  ·  opus-4.8  ·  7 turns
             cd ~/repos/billing-svc && claude -r c17ff5a9-2e6b-4f10-9d55-b0c3e7182f44

── Yesterday ─────────────────────────────────────────────────────────────────────────────

  4 ● 22:58  1d ago  Debug the flexbox overflow in the sidebar                   9b3c0d67
             ~/repos/shop-web  ·  ⎇ fix/flaky-auth  ·  sonnet-4.5  ·  31 turns
             cd ~/repos/shop-web && claude -r 9b3c0d67-58a1-4c02-91ff-6ea27d3b8c19

  5 ● 17:12  1d ago  Set up the release workflow and the version check           40ea8b25
             ~/.claude  ·  opus-4.8  ·  12 turns
             cd ~/.claude && claude -r 40ea8b25-c934-4d7e-a06b-72f1958e3dd0

── Fri 10.07 ─────────────────────────────────────────────────────────────────────────────

  6 ● 16:30  3d ago  Port the CLI to the new argparse layout                     e58a1c93
             ~/work/internal-tools/cli  ·  ⎇ main  ·  haiku-4.5  ·  4 turns
             cd ~/work/internal-tools/cli && claude -r e58a1c93-6f22-4bb8-83e0-9c17d4a52b61

 turns ≈ user + assistant messages   ·   --pick jump in   ·   --open all in tabs   ·   --smart 1-line summaries
```

In a real terminal this is colored: a day-grouped timeline (Today green, Yesterday amber), a 14-day activity sparkline in the header, and a stable per-project colored dot so the same repo keeps the same color across runs. Color is disabled automatically when the output is piped, and by `NO_COLOR`. The resume line is indented with spaces only, so a triple-click copies a command that actually runs.

## Flags

| Flag | Default | What it does |
|------|---------|--------------|
| `--since SPEC` | off | only sessions active within the window: `30m`, `24h`, `7d`, `2w` |
| `--project SUBSTR` | off | only sessions whose absolute project path contains `SUBSTR` |
| `--limit N` | `15` | maximum number of sessions listed |
| `--json` | off | machine-readable output with full session ids and resume commands |
| `--smart` | off | replace summaries with real one-sentence descriptions, via ONE `claude -p` call (network) |
| `--pick` | off | pick a row interactively, then `cd` and `claude -r` straight into it |
| `--open` | off | open every listed session in its own new terminal tab and resume it there (macOS) |
| `--claude-flags "FLAGS"` | `""` | extra flags for each resumed `claude`, passed through verbatim |
| `--terminal auto\|iTerm2\|Terminal` | `auto` | which app `--open` drives; `auto` picks iTerm2 when it is installed |
| `--yes`, `-y` | off | skip the `--open` confirmation prompt; required when stdin is not a TTY |
| `--dry-run` | off | with `--open`: print the tabs and commands, open nothing |
| `--color` | auto | force ANSI colors even when the output is piped |
| `--plain` | off | disable all ANSI colors |

Environment: `CLAUDE_CONFIG_DIR` overrides `~/.claude`. `NO_COLOR`, `FORCE_COLOR` and `CLICOLOR_FORCE` are honored. `CLAUDE_CODE_SESSION_ID` is read by `--open` so it never re-opens the session it is running in.

Run it directly, without the skill layer:

```bash
python3 ~/.claude/skills/recap/recap.py --since 7d --project shop-web
python3 ~/.claude/skills/recap/recap.py --json --limit 50 | jq '.[].projectPath'
```

An alias, if you want it outside Claude Code:

```bash
alias recap='python3 ~/.claude/skills/recap/recap.py'
```

## <img src="assets/icons/git-branch.svg" width="16" align="center"> Restoring a whole working set with `--open`

`--open` takes the sessions currently listed and opens one new terminal tab per session, typing the resume command into each. It is the fastest way back to a five-repo working set after a reboot.

```bash
# preview first: prints the tabs, opens nothing
python3 ~/.claude/skills/recap/recap.py --since 24h --limit 8 --open --dry-run

# then actually do it
python3 ~/.claude/skills/recap/recap.py --since 24h --limit 8 --open
```

Rules it follows:

- Scope comes from the normal filters. `--limit`, `--since` and `--project` decide exactly which tabs appear. Preview with `--dry-run` before you commit.
- The session `recap` itself runs in is skipped automatically, matched on `CLAUDE_CODE_SESSION_ID`. It never re-opens itself.
- Sessions whose project directory no longer exists are skipped and reported, never opened.
- Without `--yes` it asks for confirmation. When stdin is not a TTY (which is the case for Claude Code's Bash tool) it refuses to open anything unless `--yes` is passed explicitly.
- Tab opening drives iTerm2 or Terminal through `osascript`, so it is macOS-only. On other platforms `--open` exits with a clear message, and `--open --dry-run` still prints the commands so you can paste them anywhere.

### The security note on `--claude-flags`

`--claude-flags` is passed through verbatim to every resumed `claude`. That includes `--dangerously-skip-permissions`:

```bash
python3 ~/.claude/skills/recap/recap.py --since 24h --limit 8 \
  --open --yes --claude-flags "--chrome --dangerously-skip-permissions"
```

Read that command for what it is. It launches N Claude Code sessions, in N different repos, each with **every permission check disabled**, each resuming a conversation you may not remember the contents of. A resumed session carries its old context with it, so whatever it was in the middle of, it can now finish without asking you. That is a real blast radius, multiplied by the number of tabs.

`recap` does not stop you. It prints an explicit warning before opening the tabs:

```
Opening 3 tab(s):
  Fix the flaky auth test in the checkout flow    cd /Users/you/repos/shop-web && claude --dangerously-skip-permissions -r a3f91c02-7b4e-4d19-9c2a-5f83e6d1b704
  Rewrite the ingest worker to stream instead o…  cd /Users/you/repos/pipeline && claude --dangerously-skip-permissions -r 6d20be14-0a8f-49c7-8b31-1e4d90c7aa52
  Draft the migration plan for the billing sche…  cd /Users/you/repos/billing-svc && claude --dangerously-skip-permissions -r c17ff5a9-2e6b-4f10-9d55-b0c3e7182f44
  skipped (path gone): /Users/you/repos/old-spike

  WARNING: --dangerously-skip-permissions disables all permission checks in every tab opened.
```

Use it only on repos you fully control, and only when you have looked at the `--dry-run` list first. If you are not sure what a session was doing, resume it without the flag and let it ask.

## <img src="assets/icons/folder.svg" width="16" align="center"> How it works

Claude Code already logs your sessions to disk. `recap` is a reader for those logs, nothing more.

**Data sources.** Exactly two, both local:

| Path | What is read from it |
|------|----------------------|
| `~/.claude/history.jsonl` | fast global index: prompt text, timestamp, project path, session id |
| `~/.claude/projects/<encoded>/<session>.jsonl` | the transcript, parsed only for the sessions about to be displayed: title, git branch, model, turn count, `cwd` |

`CLAUDE_CONFIG_DIR` is honored, so a non-standard config directory works.

**Ordering.** Candidate transcripts are ranked by file mtime, then re-sorted by the true last timestamp inside the file. Claude Code touches transcripts on compaction and title writes, so mtime alone is only an approximation.

**Summaries.** Preference order: Claude Code's own `ai-title` line, then the first real user prompt of the session, then `(no prompt)`. Slash commands, system reminders and tool results are not treated as prompts. `--smart` replaces this with a real one-sentence summary.

**Project paths** always come from the `cwd` and `project` fields in the logs, never decoded back from the directory-name encoding, which is lossy.

**Turn count** is user prompts plus distinct assistant messages, grouped by message id so streaming chunks are not counted twice. It is labeled approximate because it is.

**Robustness.** Broken or partial JSONL lines are skipped, never fatal. `recap` sees only sessions still on disk; Claude Code prunes old ones on its own schedule.

## <img src="assets/icons/shield.svg" width="16" align="center"> Privacy

This tool reads your conversation transcripts, so here is the precise claim.

- **Reads.** Only `$CLAUDE_CONFIG_DIR/history.jsonl` and `$CLAUDE_CONFIG_DIR/projects/*/*.jsonl` (default `~/.claude`). Nothing else on your filesystem is opened.
- **Writes.** Nothing. A `recap` run creates, modifies and deletes zero files. It never touches your session data. (The installers are the exception, and they only write into `~/.claude/skills/recap`, tracked by a sha256 manifest.)
- **Network.** None by default. The default run is fully offline.
- **The one exception is `--smart`,** which is opt-in and off by default. It shells out to your local `claude` CLI once and sends, for the listed sessions only: the 8-character session id prefix, the session title (first 150 characters), and the first user prompt (first 300 characters). No file contents, no transcript bodies, no other session. If the `claude` CLI is not on your PATH, `--smart` is skipped with a warning and the offline summaries are used.
- **Telemetry.** None. There is no analytics, no phone-home, no counter, no crash reporter.
- **Side effects.** `--open` and `--pick` are the only paths that do anything outside stdout. `--open` drives iTerm2 or Terminal via `osascript`; `--pick` `exec`s `claude -r` in the chosen directory. Neither writes to session data.

The whole tool is one auditable file: [`skills/recap/recap.py`](skills/recap/recap.py), Python standard library only.

## Requirements

- **Claude Code**, with a config directory on disk. `recap` exits with a clear message if `~/.claude/projects` does not exist.
- **Python 3**, standard library only. No pip packages. CI exercises Python 3.11.
- **Node 18.17+**, only if you install via `npx`. Not needed at runtime.
- **macOS**, only for `--open` tab opening (iTerm2 or Terminal, driven by `osascript`). Everything else, including `--open --dry-run`, works on Linux and Windows.

## Uninstall

```bash
# npx install
npx claude-code-recap --uninstall

# curl install
curl -fsSL https://raw.githubusercontent.com/noluyorAbi/claude-code-recap/main/install.sh | sh -s -- --uninstall
```

Both refuse to delete files you have edited since installing, unless you pass `--force`.

If you installed it as a plugin instead, open the plugin manager with `/plugin` inside Claude Code and disable or remove `claude-code-recap@noluyorabi-plugins` there.

## Contributing

Issues and pull requests are welcome. The local loop:

```bash
git clone https://github.com/noluyorAbi/claude-code-recap
cd claude-code-recap

sh tests/smoke.sh              # end-to-end test against a synthetic config dir, no network
node scripts/check-version.mjs # package.json, plugin.json and SKILL.md must agree
claude plugin validate . --strict
claude --plugin-dir .          # load this checkout as a plugin for one session
```

`tests/smoke.sh` builds a fake `CLAUDE_CONFIG_DIR` and asserts the `--json` output, so it never reads your real sessions. CI runs it on every push, together with a Python syntax check, `shellcheck`, `node --check`, and a full install-update-uninstall cycle for both installers in a scratch directory.

Version numbers live in three places (`package.json`, `.claude-plugin/plugin.json`, `skills/recap/SKILL.md` under `metadata.version`) and CI fails if they disagree. Bump them together.

Two house rules for anything you submit: no emoji, and no em dashes or en dashes as punctuation.

## License

MIT. See [LICENSE](LICENSE).
