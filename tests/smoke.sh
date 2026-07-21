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

SID="11111111-2222-3333-4444-555555555555"
PROJECT="$TMP/workspace/demo-project"
CONFIG="$TMP/claude"
ENC="-$(printf '%s' "${PROJECT#/}" | tr '/.' '--')"

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
ENC2="-$(printf '%s' "${PROJECT2#/}" | tr -c 'A-Za-z0-9\n' '-')"

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

# --project must still match a path whose separators the folder name collapsed
CLAUDE_CONFIG_DIR="$CONFIG2" python3 "$RECAP" --json --project drift_project >"$TMP/named.json" ||
  fail "recap.py --project exited nonzero"
python3 - "$TMP/named.json" <<'PY' || exit 1
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
if len(data) != 2:
    print(f"smoke: FAIL: --project drift_project matched {len(data)} sessions, expected 2",
          file=sys.stderr)
    raise SystemExit(1)
print("smoke: ok: --project matches the real project directory")
PY

printf '\nsmoke: PASS\n'
