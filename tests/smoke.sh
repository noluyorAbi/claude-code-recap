#!/bin/sh
# tests/smoke.sh: end-to-end check of recap.py against a synthetic config dir.
#
# Builds a fake CLAUDE_CONFIG_DIR containing one history.jsonl entry plus the
# matching transcript, then asserts that `recap.py --json` reports exactly one
# session with the right project path, branch and model. Also asserts that a
# missing projects directory produces a clear message instead of a traceback.
#
# No network, no writes outside the temp dir, no dependency on a real ~/.claude.

set -eu

ROOT="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
RECAP="$ROOT/skills/recap/recap.py"

TMP="$(mktemp -d 2>/dev/null || mktemp -d -t recap-smoke)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT HUP INT TERM

fail() {
  printf 'smoke: FAIL: %s\n' "$1" >&2
  exit 1
}

# Claude Code names a project folder after its cwd with every non-alphanumeric
# character replaced by '-'. One helper, so no fixture invents its own rule.
enc_dir() {
  printf '%s' "-$(printf '%s' "${1#/}" | tr -c 'A-Za-z0-9\n' '-')"
}

SID="11111111-2222-3333-4444-555555555555"
PROJECT="$TMP/workspace/demo-project"
CONFIG="$TMP/claude"
ENC="$(enc_dir "$PROJECT")"

mkdir -p "$PROJECT" "$CONFIG/projects/$ENC"

# history.jsonl uses epoch milliseconds; keep it recent so no filter drops it.
NOW_MS="$(python3 -c 'import time; print(int(time.time() * 1000))')"
NOW_ISO="$(python3 -c 'import datetime; print(datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"))')"

python3 - "$CONFIG" "$ENC" "$SID" "$PROJECT" "$NOW_MS" "$NOW_ISO" <<'PY'
import json, os, sys

config, enc, sid, project, now_ms, now_iso = sys.argv[1:7]
now_ms = int(now_ms)

with open(os.path.join(config, "history.jsonl"), "w", encoding="utf-8") as fh:
    fh.write(json.dumps({
        "display": "wire up the parser and fix the failing test",
        "timestamp": now_ms,
        "project": project,
        "sessionId": sid,
    }) + "\n")
    fh.write("{ this line is broken json and must be skipped\n")

transcript = os.path.join(config, "projects", enc, sid + ".jsonl")
with open(transcript, "w", encoding="utf-8") as fh:
    for row in [
        {"type": "user", "cwd": project, "gitBranch": "feature/parser",
         "timestamp": now_iso, "sessionId": sid,
         "message": {"role": "user", "content": "wire up the parser and fix the failing test"}},
        {"type": "assistant", "cwd": project, "gitBranch": "feature/parser",
         "timestamp": now_iso, "sessionId": sid,
         "message": {"id": "msg_abc123", "role": "assistant",
                     "model": "claude-opus-4-8", "content": [{"type": "text", "text": "on it"}]}},
        {"type": "ai-title", "timestamp": now_iso, "aiTitle": "Parser wiring and test fix"},
    ]:
        fh.write(json.dumps(row) + "\n")
PY

# ---------- 1. one synthetic session is listed ----------
OUT="$TMP/out.json"
CLAUDE_CONFIG_DIR="$CONFIG" python3 "$RECAP" --json --limit 5 >"$OUT" ||
  fail "recap.py --json exited nonzero"

CLAUDE_CONFIG_DIR="$CONFIG" python3 - "$OUT" "$SID" "$PROJECT" <<'PY' || exit 1
import json, sys

out, sid, project = sys.argv[1:4]
data = json.load(open(out, encoding="utf-8"))

def check(cond, msg):
    if not cond:
        print(f"smoke: FAIL: {msg}", file=sys.stderr)
        print(json.dumps(data, indent=2), file=sys.stderr)
        raise SystemExit(1)

check(isinstance(data, list), "--json did not return a list")
check(len(data) == 1, f"expected 1 session, got {len(data)}")
s = data[0]
check(s["sessionId"] == sid, f"wrong sessionId: {s['sessionId']}")
check(s["projectPath"] == project, f"wrong projectPath: {s['projectPath']}")
check(s["summary"] == "Parser wiring and test fix", f"wrong summary: {s['summary']}")
check(s["branch"] == "feature/parser", f"wrong branch: {s['branch']}")
check(s["model"] == "opus-4.8", f"wrong model: {s['model']}")
check(s["turns"] == 2, f"wrong turn count: {s['turns']}")
check(s["resume"] == f"cd {project} && claude -r {sid}", f"wrong resume: {s['resume']}")
print("smoke: ok: one session listed with the expected fields")
PY

# ---------- 2. the human-readable table renders ----------
CLAUDE_CONFIG_DIR="$CONFIG" python3 "$RECAP" --plain --limit 5 >"$TMP/table.txt" ||
  fail "recap.py (table) exited nonzero"
grep -q "Parser wiring and test fix" "$TMP/table.txt" ||
  fail "table output is missing the session summary"
printf 'smoke: ok: table output renders\n'

# ---------- 3. a missing projects dir fails cleanly, without a traceback ----------
EMPTY="$TMP/empty"
mkdir -p "$EMPTY"
if CLAUDE_CONFIG_DIR="$EMPTY" python3 "$RECAP" --json >"$TMP/empty.out" 2>"$TMP/empty.err"; then
  fail "recap.py should exit nonzero when the projects dir is missing"
fi
grep -q "Traceback" "$TMP/empty.err" && fail "recap.py printed a traceback for a missing projects dir"
grep -q "not found" "$TMP/empty.err" ||
  fail "recap.py did not print a clear message for a missing projects dir"
printf 'smoke: ok: missing projects dir reports a clear error\n'

# ---------- 4. --open --dry-run opens nothing and prints the resume command ----------
CLAUDE_CONFIG_DIR="$CONFIG" python3 "$RECAP" --plain --open --dry-run --yes >"$TMP/dry.txt" ||
  fail "recap.py --open --dry-run exited nonzero"
grep -q "claude -r $SID" "$TMP/dry.txt" ||
  fail "--open --dry-run did not print the resume command"
printf 'smoke: ok: --open --dry-run is side-effect free\n'

# ---------- 5. a mid-conversation `cd` must not hijack the resume path ----------
# A transcript lives in the folder encoding the cwd the session STARTED in, and
# `claude -r` only finds it from there. If the conversation cd's into a subdir,
# the later `cwd` fields point at that subdir; resuming from it fails. A second
# session in the same folder is a title-only stub with no cwd at all, so its
# path has to be recovered from a sibling transcript.
SID2="66666666-7777-8888-9999-000000000000"
SID3="aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
CONFIG2="$TMP/claude2"
PROJECT2="$TMP/workspace/drift_project"
ENC2="$(enc_dir "$PROJECT2")"

mkdir -p "$PROJECT2/subdir" "$CONFIG2/projects/$ENC2"

python3 - "$CONFIG2" "$ENC2" "$SID2" "$SID3" "$PROJECT2" "$NOW_ISO" <<'PY'
import json, os, sys

config, enc, sid, sid_stub, project, now_iso = sys.argv[1:7]
drifted = os.path.join(project, "subdir")

with open(os.path.join(config, "history.jsonl"), "w", encoding="utf-8") as fh:
    pass  # no history entry: the path must come from the transcript alone

with open(os.path.join(config, "projects", enc, sid + ".jsonl"), "w",
          encoding="utf-8") as fh:
    for row in [
        {"type": "user", "cwd": project, "timestamp": now_iso, "sessionId": sid,
         "message": {"role": "user", "content": "start here"}},
        # the conversation cd's away halfway through
        {"type": "user", "cwd": drifted, "timestamp": now_iso, "sessionId": sid,
         "message": {"role": "user", "content": "now work in the subdir"}},
        {"type": "ai-title", "timestamp": now_iso, "aiTitle": "Drifted cwd session"},
    ]:
        fh.write(json.dumps(row) + "\n")

# title-only stub: no cwd anywhere in the file
with open(os.path.join(config, "projects", enc, sid_stub + ".jsonl"), "w",
          encoding="utf-8") as fh:
    fh.write(json.dumps({"type": "ai-title", "aiTitle": "Stub with no cwd",
                         "sessionId": sid_stub}) + "\n")
PY

CLAUDE_CONFIG_DIR="$CONFIG2" python3 "$RECAP" --json --limit 5 >"$TMP/drift.json" ||
  fail "recap.py --json exited nonzero on the drifted-cwd config"

python3 - "$TMP/drift.json" "$SID2" "$SID3" "$PROJECT2" <<'PY' || exit 1
import json, sys

out, sid, sid_stub, project = sys.argv[1:5]
data = json.load(open(out, encoding="utf-8"))
by_id = {s["sessionId"]: s for s in data}

def check(cond, msg):
    if not cond:
        print(f"smoke: FAIL: {msg}", file=sys.stderr)
        print(json.dumps(data, indent=2), file=sys.stderr)
        raise SystemExit(1)

check(sid in by_id, "drifted session missing from output")
check(by_id[sid]["projectPath"] == project,
      f"a mid-conversation cd hijacked the path: {by_id[sid]['projectPath']}")
check(by_id[sid]["resume"] == f"cd {project} && claude -r {sid}",
      f"wrong resume command: {by_id[sid]['resume']}")
check(sid_stub in by_id, "cwd-less stub session missing from output")
check(by_id[sid_stub]["projectPath"] == project,
      f"stub path not recovered from a sibling: {by_id[sid_stub]['projectPath']}")
print("smoke: ok: resume path survives a mid-conversation cd")
PY

# the drifted subdir must not match --project either: no session started there
CLAUDE_CONFIG_DIR="$CONFIG2" python3 "$RECAP" --json --project subdir >"$TMP/subdir.json" ||
  fail "recap.py --project exited nonzero"
python3 - "$TMP/subdir.json" <<'PY' || exit 1
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if data:
    print("smoke: FAIL: --project matched a directory no session started in",
          file=sys.stderr)
    raise SystemExit(1)
print("smoke: ok: --project filters on the resolved path")
PY

# every spelling of the same directory selects it: the real path, and the
# dashed form users read off the ~/.claude/projects folder name
for NEEDLE in drift_project drift-project workspace/drift_project; do
  CLAUDE_CONFIG_DIR="$CONFIG2" python3 "$RECAP" --json --project "$NEEDLE" >"$TMP/spelling.json" ||
    fail "recap.py --project $NEEDLE exited nonzero"
  python3 - "$TMP/spelling.json" "$NEEDLE" <<'PY' || exit 1
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if len(data) != 2:
    print(f"smoke: FAIL: --project {sys.argv[2]} matched {len(data)} sessions, expected 2",
          file=sys.stderr)
    raise SystemExit(1)
PY
done
printf 'smoke: ok: --project matches the project directory in every spelling\n'

# ---------- 6. a rejected candidate must not eat the row budget ----------
# recap over-fetches `limit * 2 + 5` candidates. Sessions whose history entry
# points at a stale directory pass the cheap pre-filter and are dropped once
# the real path is resolved, so the budget has to count kept rows, not
# candidates: otherwise a wall of stale entries starves --limit.
CONFIG3="$TMP/claude3"
TARGET="$TMP/workspace/target_project"
ENC3="$(enc_dir "$TARGET")"
mkdir -p "$TARGET" "$CONFIG3/projects/$ENC3"

python3 - "$CONFIG3" "$ENC3" "$TARGET" "$TMP/workspace" "$NOW_ISO" <<'PY'
import json, os, re, sys, time

config, enc, target, workspace, now_iso = sys.argv[1:6]
BASE = time.time() - 3600

def encode(path):
    return re.sub(r"[^A-Za-z0-9]", "-", path)

def write(path, rows, mtime):
    with open(path, "w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row) + "\n")
    # recap inspects candidates newest mtime first. Stamp them explicitly: on a
    # filesystem with 1-second timestamps every file written by this script
    # would otherwise tie, and directory order, not age, would decide.
    os.utime(path, (mtime, mtime))

hist = []
# the genuine matches are the OLDEST files, so every decoy is inspected first
for i in range(3):
    sid = f"cccccccc-0000-0000-0000-00000000000{i}"
    write(os.path.join(config, "projects", enc, sid + ".jsonl"), [
        {"type": "user", "cwd": target, "timestamp": now_iso, "sessionId": sid,
         "message": {"role": "user", "content": f"real session {i}"}},
        {"type": "ai-title", "aiTitle": f"Target session {i}"},
    ], BASE + i)

# 12 decoys: their history entry still claims the target directory (a stale
# path, e.g. after the folder was renamed), their transcript says otherwise
for i in range(12):
    sid = f"dddddddd-0000-0000-0000-0000000000{i:02d}"
    decoy = os.path.join(workspace, f"decoy{i}")
    os.makedirs(os.path.join(config, "projects", encode(decoy)), exist_ok=True)
    write(os.path.join(config, "projects", encode(decoy), sid + ".jsonl"), [
        {"type": "user", "cwd": decoy, "timestamp": now_iso, "sessionId": sid,
         "message": {"role": "user", "content": f"decoy {i}"}},
        {"type": "ai-title", "aiTitle": f"Decoy session {i}"},
    ], BASE + 100 + i)
    hist.append({"display": f"decoy {i}", "timestamp": 0,
                 "project": target, "sessionId": sid})

with open(os.path.join(config, "history.jsonl"), "w", encoding="utf-8") as fh:
    for row in hist:
        fh.write(json.dumps(row) + "\n")
PY

CLAUDE_CONFIG_DIR="$CONFIG3" python3 "$RECAP" --json --project target_project --limit 3 \
  >"$TMP/budget.json" || fail "recap.py --project (budget case) exited nonzero"
python3 - "$TMP/budget.json" "$TARGET" <<'PY' || exit 1
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
target = sys.argv[2]
if len(data) != 3:
    print(f"smoke: FAIL: expected 3 matching sessions, got {len(data)}: "
          "rejected candidates ate the over-fetch budget", file=sys.stderr)
    raise SystemExit(1)
wrong = [s["projectPath"] for s in data if s["projectPath"] != target]
if wrong:
    print(f"smoke: FAIL: stale history paths leaked into the result: {wrong}",
          file=sys.stderr)
    raise SystemExit(1)
print("smoke: ok: filtered-out candidates do not starve --limit")
PY

# ---------- 7. --since is inside the same row budget ----------
# Claude Code touches transcripts on compaction and title writes, so a file
# can be fresh while its last real message is weeks old. Those sessions are
# inspected first (newest mtime) and dropped by --since, so the drop has to
# happen before the budget is spent, exactly like the --project one.
CONFIG4="$TMP/claude4"
RECENT="$TMP/workspace/recent_project"
ENC4="$(enc_dir "$RECENT")"
mkdir -p "$RECENT" "$CONFIG4/projects/$ENC4"

python3 - "$CONFIG4" "$ENC4" "$RECENT" "$NOW_ISO" <<'PY'
import datetime, json, os, sys, time

config, enc, project, now_iso = sys.argv[1:5]
stale_iso = (datetime.datetime.now(datetime.timezone.utc)
             - datetime.timedelta(days=10)).isoformat().replace("+00:00", "Z")
BASE = time.time()

def write(sid, iso, mtime):
    path = os.path.join(config, "projects", enc, sid + ".jsonl")
    with open(path, "w", encoding="utf-8") as fh:
        for row in [
            {"type": "user", "cwd": project, "timestamp": iso, "sessionId": sid,
             "message": {"role": "user", "content": "hello"}},
            {"type": "ai-title", "aiTitle": f"Session {sid[:8]}"},
        ]:
            fh.write(json.dumps(row) + "\n")
    os.utime(path, (mtime, mtime))

# 12 sessions with a fresh file but a 10-day-old conversation, newest first
for i in range(12):
    write(f"eeeeeeee-0000-0000-0000-0000000000{i:02d}", stale_iso, BASE - i)
# 3 genuinely recent sessions, older files, still inside a 24h window
for i in range(3):
    write(f"ffffffff-0000-0000-0000-00000000000{i}", now_iso, BASE - 3600 - i)
PY

CLAUDE_CONFIG_DIR="$CONFIG4" python3 "$RECAP" --json --since 24h --limit 3 \
  >"$TMP/since.json" || fail "recap.py --since (budget case) exited nonzero"
python3 - "$TMP/since.json" <<'PY' || exit 1
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if len(data) != 3:
    print(f"smoke: FAIL: expected 3 in-window sessions, got {len(data)}: "
          "touched-but-stale transcripts ate the over-fetch budget", file=sys.stderr)
    raise SystemExit(1)
if any(not s["sessionId"].startswith("ffffffff") for s in data):
    print("smoke: FAIL: out-of-window sessions leaked past --since", file=sys.stderr)
    raise SystemExit(1)
print("smoke: ok: --since drops sessions before they spend the row budget")
PY

# ---------- 8. history is the last resort, and never hides the real path -----
# When nothing in the transcript (and no sibling) encodes to the containing
# folder, the history entry is all that is left, so it wins over the recorded
# cwd. It must not win anywhere else: a session whose history entry points at
# an unrelated directory still has to be found by --project on its own path,
# which is what makes the cheap pre-filter safe.
CONFIG5="$TMP/claude5"
MOVED="$TMP/workspace/moved_project"
HINTED="$TMP/workspace/hinted_project"
OWN="$TMP/workspace/own_project"
ENC_MOVED="$(enc_dir "$MOVED")"
ENC_OWN="$(enc_dir "$OWN")"
mkdir -p "$CONFIG5/projects/$ENC_MOVED" "$CONFIG5/projects/$ENC_OWN"

SID_MOVED="88888888-0000-0000-0000-000000000001"
SID_OWN="99999999-0000-0000-0000-000000000002"

python3 - "$CONFIG5" "$ENC_MOVED" "$ENC_OWN" "$SID_MOVED" "$SID_OWN" \
  "$HINTED" "$OWN" "$TMP/workspace/elsewhere" "$NOW_ISO" <<'PY'
import json, os, sys

(config, enc_moved, enc_own, sid_moved, sid_own,
 hinted, own, elsewhere, now_iso) = sys.argv[1:10]

def write(enc, sid, cwd, title):
    with open(os.path.join(config, "projects", enc, sid + ".jsonl"), "w",
              encoding="utf-8") as fh:
        for row in [
            {"type": "user", "cwd": cwd, "timestamp": now_iso, "sessionId": sid,
             "message": {"role": "user", "content": "hello"}},
            {"type": "ai-title", "aiTitle": title},
        ]:
            fh.write(json.dumps(row) + "\n")

# its own folder encodes neither cwd, and it is alone in that folder, so the
# sibling recovery finds nothing either: only history is left
write(enc_moved, sid_moved, elsewhere, "Moved session")
# this one's folder does encode its cwd; its history entry is stale
write(enc_own, sid_own, own, "Own session")

with open(os.path.join(config, "history.jsonl"), "w", encoding="utf-8") as fh:
    for sid in (sid_moved, sid_own):
        fh.write(json.dumps({"display": "hello", "timestamp": 0,
                             "project": hinted, "sessionId": sid}) + "\n")
PY

CLAUDE_CONFIG_DIR="$CONFIG5" python3 "$RECAP" --json --limit 5 >"$TMP/hint.json" ||
  fail "recap.py --json (hint fallback case) exited nonzero"
python3 - "$TMP/hint.json" "$SID_MOVED" "$SID_OWN" "$HINTED" "$OWN" <<'PY' || exit 1
import json, sys

out, sid_moved, sid_own, hinted, own = sys.argv[1:6]
data = json.load(open(out, encoding="utf-8"))
by_id = {s["sessionId"]: s for s in data}

def check(cond, msg):
    if not cond:
        print(f"smoke: FAIL: {msg}", file=sys.stderr)
        print(json.dumps(data, indent=2), file=sys.stderr)
        raise SystemExit(1)

check(len(data) == 2, f"expected 2 sessions, got {len(data)}")
check(by_id[sid_moved]["projectPath"] == hinted,
      f"history was not the last resort: {by_id[sid_moved]['projectPath']}")
check(by_id[sid_moved]["resume"] == f"cd {hinted} && claude -r {sid_moved}",
      f"wrong resume command: {by_id[sid_moved]['resume']}")
check(by_id[sid_own]["projectPath"] == own,
      f"a stale history entry outranked the transcript: {by_id[sid_own]['projectPath']}")
print("smoke: ok: history resolves a session only when nothing else can")
PY

# the stale-history session must still be reachable by its own directory
CLAUDE_CONFIG_DIR="$CONFIG5" python3 "$RECAP" --json --project own_project \
  >"$TMP/own.json" || fail "recap.py --project own_project exited nonzero"
python3 - "$TMP/own.json" "$SID_OWN" <<'PY' || exit 1
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
ids = [s["sessionId"] for s in data]
if ids != [sys.argv[2]]:
    print(f"smoke: FAIL: --project own_project returned {ids}: the cheap "
          "pre-filter dropped a session the exact check keeps", file=sys.stderr)
    raise SystemExit(1)
print("smoke: ok: --project reaches a session whose history entry points elsewhere")
PY

# ---------- 9. the same invariant, over every fixture in this file ----------
# recap rejects most candidates before parsing them, using only the folder name
# and the history entry. That shortcut is safe exactly while it cannot hide a
# session the full check would keep, so assert it directly: whatever path a
# session is listed with, --project on that path has to find it again. Any new
# way of resolving a path has to survive this, not just the shapes above.
for CFG in "$CONFIG" "$CONFIG2" "$CONFIG3" "$CONFIG4" "$CONFIG5"; do
  CLAUDE_CONFIG_DIR="$CFG" python3 "$RECAP" --json --limit 40 >"$TMP/listed.json" ||
    fail "recap.py --json exited nonzero for $CFG"
  python3 - "$TMP/listed.json" >"$TMP/listed.tsv" <<'PY'
import json, sys
for s in json.load(open(sys.argv[1], encoding="utf-8")):
    print(f"{s['sessionId']}\t{s['projectPath']}")
PY
  while IFS="$(printf '\t')" read -r LISTED_SID LISTED_PATH; do
    [ -n "$LISTED_SID" ] || continue
    CLAUDE_CONFIG_DIR="$CFG" python3 "$RECAP" --json --project "$LISTED_PATH" \
      --limit 40 >"$TMP/found.json" ||
      fail "recap.py --project '$LISTED_PATH' exited nonzero"
    grep -q "$LISTED_SID" "$TMP/found.json" ||
      fail "session $LISTED_SID is listed under $LISTED_PATH but --project on that path drops it"
  done <"$TMP/listed.tsv"
done
printf 'smoke: ok: every listed session is reachable by its own project path\n'

printf '\nsmoke: PASS\n'
