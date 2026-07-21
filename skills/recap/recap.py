#!/usr/bin/env python3
"""recap: list recent Claude Code sessions across all projects.

Shows, per session: last activity, absolute project path, short summary,
turn count, git branch, model, session id, and a ready-to-paste resume
command. Reads only what Claude Code already writes to disk:

  ~/.claude/history.jsonl              fast global index (prompt, ts, path, id)
  ~/.claude/projects/<enc>/<id>.jsonl  full transcript (title, branch, model)

Zero dependencies (Python stdlib). Default run is instant and offline.
--smart makes ONE network call via the `claude` CLI to generate real
one-sentence summaries.
"""

import argparse
import glob
import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime, timedelta, timezone

CLAUDE_DIR = os.path.expanduser(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude"))
HISTORY = os.path.join(CLAUDE_DIR, "history.jsonl")
PROJECTS = os.path.join(CLAUDE_DIR, "projects")

# Sentinel used when a session has no recoverable project path. resume_cmd
# turns this into a clear note instead of an unrunnable `cd (unknown path)`.
UNKNOWN_PATH = "(unknown path)"

# ---------- ANSI ----------
def _tty() -> bool:
    if os.environ.get("NO_COLOR") is not None:
        return False
    if os.environ.get("FORCE_COLOR") or os.environ.get("CLICOLOR_FORCE"):
        return True
    return sys.stdout.isatty()

USE_COLOR = _tty()

def c(code: str, s: str) -> str:
    return f"\033[{code}m{s}\033[0m" if USE_COLOR else s

DIM = "2"
BOLD = "1"
GREEN = "32"
YELLOW = "33"
CYAN = "36"

def c256(n: int, s: str, bold: bool = False) -> str:
    if not USE_COLOR:
        return s
    b = "1;" if bold else ""
    return f"\033[{b}38;5;{n}m{s}\033[0m"

# four-level contrast hierarchy (256-color grays)
FG = 253      # primary
SEC = 248     # secondary
MUT = 242     # muted
FNT = 238     # faint
ACCENT = 74   # one accent: desaturated cyan-blue (ids, marks)
TODAY_C = 114     # soft green
YESTERDAY_C = 179 # soft amber
STAR_C = 179      # soft amber (star CTA)
HEART_C = 210     # soft coral (credit)

# Display the bare domain, but point the OSC 8 hyperlink at a UTM-tagged URL
# (terminal clicks send no HTTP Referer, so query params are the only way to
# see where visitors come from). Terminals without OSC 8 fall back to the
# clean visible URL, losing only attribution.
AUTHOR_URL_DISPLAY = "https://adatepe.dev"
AUTHOR_URL = AUTHOR_URL_DISPLAY + "/?utm_source=recap&utm_medium=cli"
REPO_URL = "https://github.com/noluyorAbi/claude-code-recap"

def link(url: str, s: str) -> str:
    """OSC 8 clickable hyperlink. Only on a real TTY: piped output (Claude
    Code's Bash tool, files) keeps plain text so nothing leaks as junk; the
    visible text already carries the domain, so no information is lost."""
    if not (USE_COLOR and sys.stdout.isatty()):
        return s
    return f"\033]8;;{url}\033\\{s}\033]8;;\033\\"

# muted, distinct per-project palette (256-color)
PROJ_PALETTE = [110, 150, 180, 176, 116, 222, 146, 210, 108, 139]

def proj_color(path: str) -> int:
    return PROJ_PALETTE[sum(path.encode()) % len(PROJ_PALETTE)]

SPARK = "▁▂▃▄▅▆▇█"

def sparkline(counts):
    mx = max(counts) if any(counts) else 1
    return "".join(SPARK[min(7, int(v / mx * 7 + 0.5))] if v else " " for v in counts)

# ---------- helpers ----------
def parse_since(spec: str) -> datetime:
    """'7d', '24h', '30m', '2w' -> aware UTC datetime cutoff."""
    m = re.fullmatch(r"(\d+)([mhdw])", spec.strip())
    if not m:
        sys.exit(f"recap: invalid --since value '{spec}' (use e.g. 30m, 24h, 7d, 2w)")
    n, unit = int(m.group(1)), m.group(2)
    delta = {"m": timedelta(minutes=n), "h": timedelta(hours=n),
             "d": timedelta(days=n), "w": timedelta(weeks=n)}[unit]
    return datetime.now(timezone.utc) - delta

def iso_to_dt(s: str):
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None

def rel_time(dt: datetime) -> str:
    secs = (datetime.now(timezone.utc) - dt).total_seconds()
    if secs < 0:
        secs = 0
    if secs < 60:
        return "now"
    if secs < 3600:
        return f"{int(secs // 60)}m ago"
    if secs < 86400:
        return f"{int(secs // 3600)}h ago"
    return f"{int(secs // 86400)}d ago"

def truncate(s: str, n: int) -> str:
    s = re.sub(r"\s+", " ", s).strip()
    return s if len(s) <= n else s[: n - 1] + "…"

def short_path(path: str, maxlen: int = 34) -> str:
    home = os.path.expanduser("~")
    if path.startswith(home):
        path = "~" + path[len(home):]
    if len(path) <= maxlen:
        return path
    parts = path.split("/")
    # keep last two components, prefix with ellipsis
    tail = "/".join(parts[-2:])
    return truncate("…/" + tail, maxlen)

def pretty_model(model: str) -> str:
    if not model:
        return ""
    m = re.match(r"claude-([a-z]+)-(\d+)(?:-(\d+))?", model)
    if m:
        name, major, minor = m.group(1), m.group(2), m.group(3)
        return f"{name}-{major}.{minor}" if minor else f"{name}-{major}"
    return model

META_PREFIXES = ("<command-name>", "<local-command", "<system-reminder", "Caveat:")

def is_real_prompt(text: str) -> bool:
    t = text.lstrip()
    return bool(t) and not t.startswith(META_PREFIXES)

# ---------- data loading ----------
def load_history():
    """sessionId -> {project, first_prompt, first_ts, last_ts}"""
    idx = {}
    if not os.path.isfile(HISTORY):
        return idx
    with open(HISTORY, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue
            if not isinstance(o, dict):
                continue  # valid JSON but not an object (array, number, ...): skip
            sid = o.get("sessionId")
            ts = o.get("timestamp")
            if not sid or not isinstance(ts, (int, float)):
                continue
            dt = datetime.fromtimestamp(ts / 1000, tz=timezone.utc)
            e = idx.setdefault(sid, {"project": o.get("project"), "first_prompt": None,
                                     "first_ts": dt, "last_ts": dt})
            disp = (o.get("display") or "").strip()
            if dt <= e["first_ts"]:
                e["first_ts"] = dt
                if is_real_prompt(disp) and not disp.startswith("/"):
                    e["first_prompt"] = disp
            if e["first_prompt"] is None and is_real_prompt(disp) and not disp.startswith("/"):
                e["first_prompt"] = disp
            if dt > e["last_ts"]:
                e["last_ts"] = dt
            if o.get("project"):
                e["project"] = o.get("project")
    return idx

def encode_project_dir(path: str) -> str:
    """Claude Code's ~/.claude/projects folder name for a given cwd.

    Every non-alphanumeric character becomes '-' (so '/', '.', '_' and spaces
    all collapse to dashes). Lossy, which is why we never decode it: we encode
    candidate cwds and compare against the folder instead.
    """
    return re.sub(r"[^A-Za-z0-9]", "-", path)

def resolve_project_path(transcript_file: str, candidates):
    """Pick the cwd a session can actually be resumed from.

    A session's transcript lives in the folder encoding the cwd it STARTED in.
    If the conversation later `cd`s elsewhere, later `cwd` fields point at the
    new directory and `claude -r <id>` run there finds no conversation. So the
    first candidate whose encoding matches the containing folder wins.
    """
    folder = os.path.basename(os.path.dirname(transcript_file))
    for cand in candidates:
        if cand and encode_project_dir(cand) == folder:
            return cand
    sibling = _folder_cwd(os.path.dirname(transcript_file))
    if sibling:
        return sibling
    for cand in candidates:
        if cand:
            return cand
    return None

_FOLDER_CWD = {}

def _folder_cwd(folder_dir: str, max_files: int = 5):
    """Recover a folder's real cwd from a sibling transcript.

    Some transcripts (title-only stubs) carry no cwd at all. Siblings in the
    same folder started in the same directory, so borrow theirs.
    """
    if folder_dir in _FOLDER_CWD:
        return _FOLDER_CWD[folder_dir]
    folder = os.path.basename(folder_dir)
    found = None
    try:
        names = sorted(os.listdir(folder_dir))
    except OSError:
        names = []
    checked = 0
    for name in names:
        if not name.endswith(".jsonl") or checked >= max_files:
            continue
        checked += 1
        cand = peek_cwd(os.path.join(folder_dir, name))
        if cand and encode_project_dir(cand) == folder:
            found = cand
            break
    _FOLDER_CWD[folder_dir] = found
    return found

def peek_cwd(path: str, max_lines: int = 80):
    """Cheaply pull cwd from the first lines of a transcript."""
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for i, line in enumerate(fh):
                if i >= max_lines:
                    break
                if '"cwd"' not in line:
                    continue
                try:
                    o = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if isinstance(o, dict) and o.get("cwd"):
                    return o["cwd"]
    except OSError:
        pass
    return None

def parse_session(path: str):
    """Full parse of one transcript. Returns dict or None if unusable."""
    d = {
        "cwd": None, "cwds": [], "ai_title": None, "first_prompt": None,
        "git_branch": None, "model": None, "last_ts": None,
        "user_turns": 0, "assistant_ids": set(),
    }
    any_line = False
    try:
        fh = open(path, encoding="utf-8", errors="replace")
    except OSError:
        return None
    with fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError:
                continue  # broken / partial line: skip
            if not isinstance(o, dict):
                continue  # valid JSON but not an object (array, number, ...): skip
            any_line = True
            t = o.get("type")
            if o.get("cwd"):
                if d["cwd"] is None:
                    d["cwd"] = o["cwd"]  # first cwd = where the session started
                if o["cwd"] not in d["cwds"]:
                    d["cwds"].append(o["cwd"])
            if o.get("gitBranch"):
                d["git_branch"] = o["gitBranch"]
            ts = iso_to_dt(o.get("timestamp")) if isinstance(o.get("timestamp"), str) else None
            if ts and (d["last_ts"] is None or ts > d["last_ts"]):
                d["last_ts"] = ts
            if t == "ai-title" and o.get("aiTitle"):
                d["ai_title"] = o["aiTitle"]
            elif t == "summary" and o.get("summary"):  # older transcript versions
                d["ai_title"] = d["ai_title"] or o["summary"]
            elif t == "user" and not o.get("isSidechain"):
                msg = o.get("message") or {}
                content = msg.get("content")
                text = None
                if isinstance(content, str):
                    text = content
                elif isinstance(content, list):
                    for block in content:
                        if isinstance(block, dict) and block.get("type") == "text":
                            text = block.get("text")
                            break
                        if isinstance(block, dict) and block.get("type") == "tool_result":
                            text = None
                            break
                if text and is_real_prompt(text):
                    d["user_turns"] += 1
                    if d["first_prompt"] is None and not text.lstrip().startswith("/"):
                        d["first_prompt"] = text
            elif t == "assistant" and not o.get("isSidechain"):
                msg = o.get("message") or {}
                if msg.get("model"):
                    d["model"] = msg["model"]
                mid = msg.get("id")
                if mid:
                    d["assistant_ids"].add(mid)  # streaming chunks share message id
    if not any_line:
        return None
    # turns = user prompts + distinct assistant messages (grouped by message id)
    d["turns"] = d["user_turns"] + len(d["assistant_ids"])
    del d["assistant_ids"]
    return d

# ---------- smart summaries ----------
def smart_summaries(sessions):
    """One `claude -p` call for all rows. Returns {sid: summary} or {}."""
    items = []
    for s in sessions:
        ctx = s.get("ai_title") or ""
        fp = s.get("first_prompt") or ""
        items.append({"id": s["sid"][:8], "title": ctx[:150], "first_prompt": fp[:300]})
    prompt = (
        "For each session below, write ONE short sentence (max 12 words) saying what "
        "the session was about. Reply with ONLY a JSON object mapping id to sentence, "
        "no markdown fence.\n\n" + json.dumps(items, ensure_ascii=False)
    )
    try:
        r = subprocess.run(
            ["claude", "-p", "--model", "claude-haiku-4-5-20251001"],
            input=prompt, capture_output=True, text=True, timeout=120,
        )
        if r.returncode != 0:
            raise RuntimeError(r.stderr.strip()[:200])
        raw = r.stdout.strip()
        raw = re.sub(r"^```(?:json)?|```$", "", raw, flags=re.M).strip()
        mapping = json.loads(raw)
        return {s["sid"]: mapping.get(s["sid"][:8]) for s in sessions if mapping.get(s["sid"][:8])}
    except FileNotFoundError:
        print(c(YELLOW, "recap: `claude` CLI not found, --smart skipped"), file=sys.stderr)
    except Exception as e:
        reason = str(e).strip() or type(e).__name__
        print(c(YELLOW, f"recap: --smart failed ({reason}), using default summaries"), file=sys.stderr)
    return {}

# ---------- main ----------
def collect(args):
    hist = load_history()
    files = glob.glob(os.path.join(PROJECTS, "*", "*.jsonl"))
    cand = []
    for f in files:
        sid = os.path.splitext(os.path.basename(f))[0]
        try:
            mtime = datetime.fromtimestamp(os.path.getmtime(f), tz=timezone.utc)
        except OSError:
            continue
        cand.append((mtime, sid, f))
    cand.sort(key=lambda x: x[0], reverse=True)

    # 14-day activity histogram (by file mtime, local dates; cheap, already stat'ed)
    today_local = datetime.now().astimezone().date()
    day_counts = [0] * 14
    for mtime, _sid, _f in cand:
        age = (today_local - mtime.astimezone().date()).days
        if 0 <= age < 14:
            day_counts[13 - age] += 1

    cutoff = parse_since(args.since) if args.since else None
    needle = args.project.lower() if args.project else None
    # over-fetch: file mtime can be newer than the last real message (Claude Code
    # touches transcripts on compaction/title writes), so the mtime order is only
    # approximate. Parse extra candidates, then sort by true internal timestamp.
    fetch = args.limit * 2 + 5
    rows = []
    for mtime, sid, f in cand:
        if cutoff and mtime < cutoff:
            break  # mtime >= internal ts, so sorted-desc break is safe
        h = hist.get(sid)
        path = (h and h.get("project")) or peek_cwd(f)
        if needle:
            # loose pre-filter: the real project dir is whatever the containing
            # folder encodes, so match the needle against that too (normalized,
            # since the folder has every separator collapsed to '-').
            folder = os.path.basename(os.path.dirname(f)).lower()
            if (needle not in (path or "").lower()
                    and encode_project_dir(needle).lower() not in folder):
                continue
        rows.append({"sid": sid, "file": f, "mtime": mtime, "path": path, "hist": h})
        if len(rows) >= fetch:
            break

    out = []
    for r in rows:
        try:
            d = parse_session(r["file"])
        except Exception:
            # A single corrupt transcript must never abort the whole run.
            continue
        if d is None:
            continue
        h = r["hist"] or {}
        # resume dir, not last-seen dir: a mid-conversation `cd` must not win
        path = (resolve_project_path(r["file"], d["cwds"] + [r["path"]])
                or UNKNOWN_PATH)
        if needle and needle not in path.lower():
            continue  # exact filter on the resolved path
        last = d["last_ts"] or h.get("last_ts") or r["mtime"]
        summary = (d["ai_title"] or h.get("first_prompt") or d["first_prompt"]
                   or "(no prompt)")
        out.append({
            "sid": r["sid"], "path": path, "last": last,
            "summary": summary, "turns": d["turns"],
            "branch": d["git_branch"] or "", "model": pretty_model(d["model"] or ""),
            "ai_title": d["ai_title"], "first_prompt": d["first_prompt"] or h.get("first_prompt"),
        })
    if cutoff:
        out = [s for s in out if s["last"] >= cutoff]
    out.sort(key=lambda s: s["last"], reverse=True)
    return out[: args.limit], day_counts

def day_label(d, today):
    if d == today:
        return "Today", TODAY_C
    if d == today - timedelta(days=1):
        return "Yesterday", YESTERDAY_C
    return d.strftime("%a %d.%m"), MUT

def render(sessions, args, day_counts):
    if args.json:
        payload = [{
            "sessionId": s["sid"], "projectPath": s["path"],
            "lastActive": s["last"].astimezone().isoformat(),
            "summary": s["summary"], "turns": s["turns"],
            "branch": s["branch"] or None, "model": s["model"] or None,
            "resume": resume_cmd(s["path"], s["sid"], args.claude_flags),
        } for s in sessions]
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return

    if not sessions:
        print("No sessions found (check --since / --project filters).")
        return

    import shutil
    term_w = min(shutil.get_terminal_size((110, 24)).columns, 130)
    today = datetime.now().astimezone().date()
    n_proj = len({s["path"] for s in sessions})

    # ── header ────────────────────────────────────────────────────────────
    left = c256(ACCENT, "◆", bold=True) + " " + c256(FG, "recap", bold=True)
    meta = f"{len(sessions)} sessions · {n_proj} projects"
    spark = sparkline(day_counts)
    right = c256(MUT, meta) + "   " + c256(FNT, "14d ") + c256(ACCENT, spark)
    pad = term_w - 8 - len(meta) - 4 - len(day_counts) - 3
    print()
    print(left + " " * max(2, pad) + right)
    print()

    # ── day-grouped timeline ─────────────────────────────────────────────
    prev_day = None
    for i, s in enumerate(sessions, 1):
        local = s["last"].astimezone()
        d = local.date()
        if d != prev_day:
            label, col = day_label(d, today)
            rule = "─" * (term_w - len(label) - 6)
            print(c256(col, f"── {label} ", bold=(col != MUT)) + c256(FNT, rule))
            print()
            prev_day = d

        dot = c256(proj_color(s["path"]), "●")
        idx = c256(FNT, f"{i:>2}")
        _, day_c = day_label(d, today)
        tcol = day_c if day_c != MUT else SEC
        time_s = c256(tcol, local.strftime("%H:%M"), bold=(day_c != MUT)) \
            + c256(FNT, f" {rel_time(s['last']):>7}")
        sid8 = c256(ACCENT, s["sid"][:8])

        # line 1: index · dot · time · summary · id
        summ_w = term_w - 2 - 2 - 2 - 14 - 2 - 8 - 4
        summary = truncate(s["summary"], summ_w)
        gap = term_w - 2 - 2 - 2 - 14 - 2 - len(summary) - 8 - 2
        print(f" {idx} {dot} {time_s}  {c256(FG, summary, bold=True)}"
              + " " * max(2, gap) + sid8)

        # line 2: project path · branch · model · turns
        bits = [short_path(s["path"], 44)]
        if s["branch"]:
            bits.append("⎇ " + truncate(s["branch"], 18))
        if s["model"]:
            bits.append(s["model"])
        if s["turns"] == 1:
            bits.append("1 turn")
        else:
            bits.append(f"{s['turns']} turns" if s["turns"] else "? turns")
        print(" " * 13 + c256(MUT, "  ·  ".join(bits)))

        # line 3: resume command (spaces-only indent, ~ shortened, safe to copy)
        home = os.path.expanduser("~")
        rp = s["path"]
        if rp == home or rp.startswith(home + "/"):
            rp = "~" + rp[len(home):]
        print(" " * 13 + c256(FNT, resume_cmd(rp, s["sid"], args.claude_flags)))
        if i < len(sessions):
            print()

    # ── footer ───────────────────────────────────────────────────────────
    print()
    print(c256(FNT, " turns ≈ user + assistant messages"
                    "   ·   --pick jump in   ·   --open all in tabs   ·   --smart 1-line summaries"))
    print()
    print(" " + c256(STAR_C, "*", bold=True) + " " + c256(MUT, "enjoying recap?")
          + " " + c256(SEC, "a star on GitHub makes my day", bold=True)
          + c256(FNT, ": ") + link(REPO_URL, c256(ACCENT, REPO_URL)))
    print(" " + c256(HEART_C, "@", bold=True) + " " + c256(MUT, "made with care by")
          + " " + c256(SEC, "Alperen", bold=True)
          + c256(FNT, " · come say hi: ") + link(AUTHOR_URL, c256(ACCENT, AUTHOR_URL_DISPLAY)))

def _shquote_path(path: str) -> str:
    """Shell-quote a path so metacharacters or spaces in a directory name cannot
    break out of (or break) the resume command. A leading ~ / ~/ is kept
    unquoted so the copyable line still expands to the home directory when
    pasted; only the remainder is quoted."""
    if path == "~":
        return "~"
    if path.startswith("~/"):
        rest = path[2:]
        return "~/" + shlex.quote(rest) if rest else "~/"
    return shlex.quote(path)

def resume_cmd(path: str, sid: str, extra: str = "") -> str:
    # No usable path: emit a clear, inert note instead of `cd (unknown path)`,
    # which would neither run nor be safe to paste.
    if not path or path == UNKNOWN_PATH:
        return f"# recap: no project path recorded for session {sid}"
    flags = f"{extra} " if extra else ""
    # `extra` is the user's own --claude-flags, passed through verbatim (it may
    # legitimately hold several space-separated flags). `path` and `sid` come
    # from disk, so they are shell-quoted to prevent injection.
    return f"cd {_shquote_path(path)} && claude {flags}-r {shlex.quote(sid)}"

# ---------- open in terminal tabs ----------
def _osa_str(s: str) -> str:
    """Quote a Python string as an AppleScript string literal."""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

def open_tabs(sessions, args):
    """Open one new terminal tab per session and resume it there."""
    # osascript drives iTerm2/Terminal, so real tab opening is macOS-only.
    # --dry-run stays available everywhere (it prints, it does not open).
    if sys.platform != "darwin" and not args.dry_run:
        sys.exit("recap: --open drives iTerm2/Terminal via osascript and only works on macOS. "
                 "Use --dry-run to print the resume commands instead.")
    current = os.environ.get("CLAUDE_CODE_SESSION_ID")
    targets, skipped = [], []
    for s in sessions:
        if s["sid"] == current:
            continue  # never re-open the session running recap
        if not os.path.isdir(s["path"]):
            skipped.append(s)
            continue
        targets.append(s)

    if not targets:
        print(c(YELLOW, "recap: nothing to open"), file=sys.stderr)
        return

    extra = (args.claude_flags or "").strip()
    cmds = [resume_cmd(s["path"], s["sid"], extra) for s in targets]

    print()
    print(c256(FG, f"Opening {len(targets)} tab(s):", bold=True))
    for s, cmd in zip(targets, cmds):
        print("  " + c256(MUT, truncate(s["summary"], 46).ljust(48)) + c256(FNT, cmd))
    for s in skipped:
        print(c(YELLOW, f"  skipped (path gone): {s['path']}"))

    if "--dangerously-skip-permissions" in extra:
        print()
        print(c(YELLOW, "  WARNING: --dangerously-skip-permissions disables all permission "
                        "checks in every tab opened."))

    if args.dry_run:
        return

    if not args.yes:
        if not sys.stdin.isatty():
            sys.exit("recap: --open needs confirmation; re-run with --yes (non-interactive stdin)")
        try:
            if input("\nProceed? [y/N] ").strip().lower() not in ("y", "yes"):
                print("aborted")
                return
        except (EOFError, KeyboardInterrupt):
            print("\naborted")
            return

    app = args.terminal
    if app == "auto":
        app = "iTerm2" if os.path.isdir("/Applications/iTerm.app") else "Terminal"

    lines = [f'tell application "{app}" to activate']
    for cmd in cmds:
        if app == "iTerm2":
            lines += [
                'tell application "iTerm2"',
                "  tell current window",
                "    create tab with default profile",
                f"    tell current session to write text {_osa_str(cmd)}",
                "  end tell",
                "end tell",
                "delay 0.4",
            ]
        else:
            lines += [
                'tell application "Terminal"',
                f"  do script {_osa_str(cmd)}",
                "end tell",
                "delay 0.4",
            ]
    script = "\n".join(lines)

    r = subprocess.run(["osascript", "-"], input=script, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"recap: osascript failed: {r.stderr.strip()[:300]}")
    print(c256(TODAY_C, f"\nOpened {len(targets)} tab(s) in {app}"))

def pick(sessions):
    try:
        choice = input("\nJump to session # (empty to quit): ").strip()
    except (EOFError, KeyboardInterrupt):
        return
    if not choice:
        return
    try:
        s = sessions[int(choice) - 1]
    except (ValueError, IndexError):
        sys.exit("recap: invalid selection")
    path = s["path"]
    if not os.path.isdir(path):
        sys.exit(f"recap: project path no longer exists: {path}")
    os.chdir(path)
    os.execvp("claude", ["claude", "-r", s["sid"]])

def main():
    ap = argparse.ArgumentParser(prog="recap",
                                 description="List recent Claude Code sessions across all projects.")
    ap.add_argument("--since", metavar="SPEC", help="only sessions active within SPEC (30m, 24h, 7d, 2w)")
    ap.add_argument("--project", metavar="SUBSTR", help="filter by project path substring")
    ap.add_argument("--limit", type=int, default=15, metavar="N", help="max sessions (default 15)")
    ap.add_argument("--json", action="store_true", help="machine-readable output (full session ids)")
    ap.add_argument("--smart", action="store_true",
                    help="generate 1-sentence summaries via one `claude -p` call (network)")
    ap.add_argument("--pick", action="store_true", help="interactively pick a session and resume it")
    ap.add_argument("--open", dest="open_tabs", action="store_true",
                    help="open every listed session in its own terminal tab and resume it")
    ap.add_argument("--claude-flags", metavar="FLAGS", default="",
                    help='extra flags for the resumed `claude` (e.g. "--chrome --dangerously-skip-permissions")')
    ap.add_argument("--terminal", choices=["auto", "iTerm2", "Terminal"], default="auto",
                    help="terminal app used by --open (default: auto)")
    ap.add_argument("--yes", "-y", action="store_true", help="skip the --open confirmation prompt")
    ap.add_argument("--dry-run", action="store_true", help="with --open: print what would run, open nothing")
    ap.add_argument("--color", action="store_true", help="force ANSI colors even when piped")
    ap.add_argument("--plain", action="store_true", help="disable all ANSI colors")
    args = ap.parse_args()

    global USE_COLOR
    if args.plain:
        USE_COLOR = False
    elif args.color:
        USE_COLOR = True

    if not os.path.isdir(PROJECTS):
        sys.exit(f"recap: {PROJECTS} not found. Is Claude Code installed on this machine? "
                 "Set CLAUDE_CONFIG_DIR if your config lives somewhere other than ~/.claude.")

    sessions, day_counts = collect(args)
    if args.smart and sessions:
        for sid, summ in smart_summaries(sessions).items():
            for s in sessions:
                if s["sid"] == sid:
                    s["summary"] = summ
    render(sessions, args, day_counts)
    if args.open_tabs and sessions and not args.json:
        open_tabs(sessions, args)
    elif args.pick and sessions and not args.json:
        pick(sessions)

if __name__ == "__main__":
    main()
