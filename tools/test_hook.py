import json, os, shutil, subprocess, sys, tempfile
HOOK = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "toragents_hook.py")
PY = sys.executable
PASS = FAIL = 0

def mkstate(n=1, body="hello", size=None):
    d = tempfile.mkdtemp()
    os.makedirs(os.path.join(d, "state", "inbox"))
    for i in range(n):
        b = (body * (size // len(body) + 1))[:size] if size else body + str(i)
        json.dump({"id": f"m{i}", "body": b, "from_label": "maestro-pc", "received": i},
                  open(os.path.join(d, "state", "inbox", f"{i}-m{i}.json"), "w"))
    return d

def ann(d):
    p = os.path.join(d, "state", "announced.json")
    try: return json.load(open(p))
    except Exception: return None

def run(d, payload, *args, env_extra=None):
    e = dict(os.environ, TORAGENTS_HOME=d)
    e.pop("TORAGENTS_STATE", None)
    # The runner may itself be a pi session; identity must come from the payload,
    # not from whichever harness happens to be executing the tests.
    e.pop("PI_SESSION_ID", None); e.pop("PI_SESSION_FILE", None)
    e.pop("CLAUDE_CODE_ENTRYPOINT", None); e.pop("CODEX_HOME", None)
    if env_extra: e.update(env_extra)
    p = subprocess.run([PY, HOOK, *args], input=json.dumps(payload).encode(),
                       capture_output=True, env=e)
    return p.returncode, p.stdout.decode("utf-8", "replace"), p.stderr.decode()

def check(name, cond, detail=""):
    global PASS, FAIL
    if cond: PASS += 1; print(f"  PASS  {name}")
    else: FAIL += 1; print(f"  FAIL  {name}  {detail}")

# ---- gale #1: closed stdout must not mark -----------------------------------
d = mkstate(1)
r, w = os.pipe(); os.close(r)                       # harness gave up reading
e = dict(os.environ, TORAGENTS_HOME=d); e.pop("TORAGENTS_STATE", None)
p = subprocess.Popen([PY, HOOK], stdin=subprocess.PIPE, stdout=w,
                     stderr=subprocess.PIPE, env=e)
p.stdin.write(b'{"hook_event_name":"UserPromptSubmit"}'); p.stdin.close()
p.wait(); os.close(w)
check("EPIPE: message NOT marked when stdout is closed", ann(d) in (None, []), f"announced={ann(d)}")

# ---- gale #2: the mass-loss regression --------------------------------------
d = mkstate(40, size=3000)
rc, out, _ = run(d, {"hook_event_name": "SessionStart"})
shown = out.count("BEGIN PEER MESSAGE")
marked = len(ann(d) or [])
check("40-message burst: marks only what it showed", marked == shown and shown < 40,
      f"shown={shown} marked={marked}")
rc, out2, _ = run(d, {}, "--peek")
check("remaining messages still recoverable", out2.count("BEGIN PEER MESSAGE") > 0,
      "peek found nothing")
check("banner says how many are waiting", "more message(s) waiting" in out, out[-200:])
# drain everything, nothing lost
total = 0
for _ in range(60):
    rc, o, _ = run(d, {"hook_event_name": "SessionStart"})
    if "BEGIN PEER MESSAGE" not in o: break
    total += o.count("BEGIN PEER MESSAGE")
check("draining in slices loses no message", total + len(ann(d) or []) >= 40, f"total={total}")

# ---- gale #3: unwritable memo must not loop Stop ----------------------------
d = mkstate(1)
os.makedirs(os.path.join(d, "state", "announced.json"))   # a DIRECTORY
blocks = sum(1 for _ in range(5)
             if '"decision": "block"' in run(d, {"hook_event_name": "Stop", "stop_hook_active": False})[1])
check("unwritable memo: Stop does not block (no token-burning loop)", blocks == 0, f"blocked {blocks}x")

# ---- gale #4: cp1252 console must still print -------------------------------
d = mkstate(1, body="hej \U0001F600 klart")
rc, out, err = run(d, {}, "--peek", env_extra={"PYTHONIOENCODING": "cp1252"})
check("cp1252 console: non-Latin1 body still prints", "hej" in out, f"rc={rc} err={err[:80]}")

# ---- gale #5: corrupt memo is quarantined, not replayed forever -------------
d = mkstate(2)
open(os.path.join(d, "state", "announced.json"), "w").write('{"not":"a list"}')
rc, out, _ = run(d, {"hook_event_name": "SessionStart"})
check("corrupt memo: quarantined", os.path.exists(os.path.join(d, "state", "announced.json.corrupt")))
check("corrupt memo: recovers and delivers", "BEGIN PEER MESSAGE" in out)
rc, out, _ = run(d, {"hook_event_name": "SessionStart"})
check("corrupt memo: no repeat afterwards", "BEGIN PEER MESSAGE" not in out)

# ---- regressions: the original contract ------------------------------------
d = mkstate(2)
rc, out, _ = run(d, {"hook_event_name": "SessionStart"})
check("SessionStart injects both", "m0" in out and "m1" in out)
rc, out, _ = run(d, {"hook_event_name": "SessionStart"})
check("no duplicate second time", out.strip() == "")
d2 = mkstate(1)
check("Stop guards stop_hook_active",
      run(d2, {"hook_event_name": "Stop", "stop_hook_active": True})[1] == "")
check("Stop blocks when safe", '"decision": "block"' in run(d2, {"hook_event_name": "Stop", "stop_hook_active": False})[1])
d3 = mkstate(1)
check("unknown event: silent, unmarked",
      run(d3, {"hook_event_name": "PreToolUse"})[1] == "" and ann(d3) is None)
check("garbage stdin: exit 0, unmarked",
      run(d3, {})[0] == 0 and ann(d3) is None)
# ---- the reply line is a control surface, not prose ------------------------
# An agent copies this line instead of composing one. It once read
#   reply: ... send --to box \u00b7 session pi-01a14a4c --body "..."
# which is not a valid --to value and carried no --to-session, so every copy
# answered untargeted and fanned out to every session on the peer's machine.
# Nothing caught it because the sentence only ever reaches a model. So assert on
# the RENDERED TEXT the model will actually read.
d4 = tempfile.mkdtemp()
os.makedirs(os.path.join(d4, "state", "inbox"))
json.dump({"id": "rl1", "body": "do a thing", "from_label": "maestro-pc",
           "from_session": "claude-9e83f4aa", "received": 1},
          open(os.path.join(d4, "state", "inbox", "1-rl1.json"), "w"))
def context_text(out: str) -> str:
    """The prose the MODEL reads, with JSON escaping undone.

    Checking the raw stdout is wrong: json.dumps escapes non-ASCII, so a literal
    '\u00b7' in the rendered text appears as backslash-u-0-0-b-7 and a naive
    substring test sails past the very defect it was written to catch. Decode
    first, then assert.
    """
    try:
        return json.loads(out)["hookSpecificOutput"]["additionalContext"]
    except Exception:
        return out

_, line_out, _ = run(d4, {"hook_event_name": "SessionStart", "session_id": "aaaa1111"})
text = context_text(line_out)
reply = next((l for l in text.splitlines() if "reply:" in l), "")
check("reply line names the sender's session", "--to-session claude-9e83f4aa" in reply, reply)
check("reply line --to is the bare label, not 'label · session x'",
      # the header legitimately says "maestro-pc · session x"; only the REPLY
      # line is executed, so only it must be a clean --to value
      "--to maestro-pc --to-session" in reply and "·" not in reply, reply)
check("reply line warns that --to-session is load-bearing",
      "reaches every session" in text, reply)

# and when the peer named no session, say so instead of implying it is handled
d5 = tempfile.mkdtemp()
os.makedirs(os.path.join(d5, "state", "inbox"))
json.dump({"id": "rl2", "body": "anon", "from_label": "maestro-pc", "received": 2},
          open(os.path.join(d5, "state", "inbox", "1-rl2.json"), "w"))
_, anon_out, _ = run(d5, {"hook_event_name": "SessionStart", "session_id": "bbbb2222"})
check("unnamed peer: reply line admits it cannot be targeted",
      "cannot be targeted" in context_text(anon_out), anon_out[-200:])

# ---- the payload encoding Windows actually hands us ------------------------
# Silence is the correct answer to unparseable input, which makes an encoding
# mismatch indistinguishable from "nothing to say". Both cases below were
# reported from a real Windows box as "the hook prints nothing", and both were
# the harness's encoding, not the hook: Set-Content -Encoding utf8 writes a BOM,
# and `echo '...' | python` pipes UTF-16LE.
def run_raw(d, data: bytes):
    e = dict(os.environ, TORAGENTS_HOME=d); e.pop("TORAGENTS_STATE", None)
    # NOT --peek: peek bypasses payload parsing entirely (it renders whatever is
    # waiting, whatever the event), so it cannot see an encoding failure. The
    # first version of these tests used it and passed against the broken hook --
    # a test that could not fail.
    p = subprocess.run([PY, HOOK], input=data, capture_output=True, env=e)
    return p.stdout.decode("utf-8", "replace")

payload = b'{"hook_event_name": "SessionStart"}'
for name, data in [
    ("utf-8 with BOM (Set-Content -Encoding utf8)", b"\xef\xbb\xbf" + payload),
    ("utf-16LE no BOM (echo | python)", payload.decode().encode("utf-16-le")),
    ("utf-16LE with BOM", b"\xff\xfe" + payload.decode().encode("utf-16-le")),
]:
    dd = mkstate(1)
    check(f"payload encoding: {name}", "BEGIN PEER MESSAGE" in run_raw(dd, data))

# ---- the human has to see it too -------------------------------------------
# Context injection is invisible in the UI: Claude Code gives additionalContext
# to the model and shows the person nothing, so their chat looks like a turn
# where an agent mysteriously started talking about a message nobody saw.
# systemMessage is the documented user-visible field ("Display a message to the
# user (all hooks)"), so both parties get told.
d6 = mkstate(1, body="private content that must not be on screen")
_, vis, _ = run(d6, {"hook_event_name": "SessionStart", "session_id": "cccc3333"})
try:
    j = json.loads(vis)
except Exception:
    j = {}
sm = j.get("systemMessage", "")
check("systemMessage present for the human", bool(sm), vis[:200])
check("systemMessage names the sender", "maestro-pc" in sm, sm)
check("systemMessage does NOT leak the body", "private content" not in sm, sm)
check("additionalContext still delivered to the agent",
      "private content" in j.get("hookSpecificOutput", {}).get("additionalContext", ""))

# ---- the status line: the only surface a human actually sees ----------------
# additionalContext is invisible, systemMessage is accepted-and-not-rendered in
# 2.1.302, so this line is the feature. It must never crash, never mark, and it
# must not eat a status line the user already had.
def run_arg(d, flag):
    e = dict(os.environ, TORAGENTS_HOME=d); e.pop("TORAGENTS_STATE", None)
    p = subprocess.run([PY, HOOK, flag], capture_output=True, env=e)
    return p.returncode, p.stdout.decode("utf-8", "replace").strip()

d7 = mkstate(0)
rc, out = run_arg(d7, "--badge")
check("badge: empty inbox says so", rc == 0 and "0 unread" in out, out)

d8 = mkstate(2)
rc, out = run_arg(d8, "--badge")
check("badge: counts unread", "2 new" in out, out)

rc, out = run_arg(d8, "--badge")
check("badge: does not mark (still 2 after reading)", "2 new" in out, out)
check("badge: nothing was marked", ann(d8) in (None, []), str(ann(d8)))

# their status line is preserved and ours is appended
d9 = mkstate(1)
with open(os.path.join(d9, "state", "statusline.original.json"), "w") as f:
    json.dump({"command": "echo THEIRS"}, f)
rc, out = run_arg(d9, "--statusline")
check("status line: keeps the user's own", "THEIRS" in out, out)
check("status line: appends the badge", "new" in out, out)

# a broken or missing original must never take the badge down with it
d10 = mkstate(1)
with open(os.path.join(d10, "state", "statusline.original.json"), "w") as f:
    json.dump({"command": "exit 3"}, f)
rc, out = run_arg(d10, "--statusline")
check("status line: survives a failing original", rc == 0 and "new" in out, out)

rc, out = run_arg(mkstate(1), "--statusline")
check("status line: works with no saved original", rc == 0 and "new" in out, out)

# ---- "0 unread" must not mean "nothing ever happened" ------------------------
# The hook marks a message read when it hands it over, which happens before the
# status line is drawn. A human then sees "0 unread" seconds after being told a
# message arrived, which looks exactly like a quiet machine.
d11 = mkstate(1)
e11 = dict(os.environ, TORAGENTS_HOME=d11); e11.pop("TORAGENTS_STATE", None)
subprocess.run([PY, HOOK], input=b'{"hook_event_name":"SessionStart","session_id":"dddd4444"}',
               capture_output=True, env=e11)
rc, out = run_arg(d11, "--badge")
check("badge: after delivery it remembers the arrival", "last" in out and "maestro-pc" in out, out)
check("badge: delivered mail is no longer counted as new", "0 unread" in out, out)

# and it forgets, rather than claiming a delivery from an hour ago
import time as _t
with open(os.path.join(d11, "state", "last_delivery.json"), "w") as f:
    json.dump({"label": "maestro-pc", "ts": _t.time() - 3600}, f)
rc, out = run_arg(d11, "--badge")
check("badge: stale arrival note is dropped", "last" not in out, out)

# ---- the hook must leave evidence that it RAN ---------------------------------
# Without this, "hook never fires" and "hook fires, nothing pending" are the same
# observation, which is exactly the confusion that cost an evening on a real box.
d12 = mkstate(1)
e12 = dict(os.environ, TORAGENTS_HOME=d12); e12.pop("TORAGENTS_STATE", None)
run(d12, {"hook_event_name": "SessionStart", "session_id": "eeee5555"},
    env_extra={"CLAUDE_CODE_ENTRYPOINT": "cli"})
run(d12, {"hook_event_name": "UserPromptSubmit", "session_id": "eeee5555"},
    env_extra={"CLAUDE_CODE_ENTRYPOINT": "cli"})
log = open(os.path.join(d12, "state", "hook.log")).read()
check("trace: records the event that ran", "event=SessionStart" in log, log)
check("trace: records a prompt that found nothing", "nothing-pending" in log, log)
check("trace: names the session", "session=claude-eeee5555" in log, log)
check("trace: one line per invocation", len(log.strip().splitlines()) == 2, log)
check("trace: never records the body", "hello from test" not in log, log)

# ---- one inbox, two harnesses: the loser must be able to find out -------------
d13 = mkstate(1)
e13 = dict(os.environ, TORAGENTS_HOME=d13); e13.pop("TORAGENTS_STATE", None)
e13.pop("PI_SESSION_ID", None); e13["CLAUDE_CODE_ENTRYPOINT"] = "cli"
subprocess.run([PY, HOOK], input=b'{"hook_event_name":"UserPromptSubmit","session_id":"cccc7777"}',
               capture_output=True, env=e13)
recpath = os.path.join(d13, "state", "delivered_by.json")
check("record: a delivery names the harness that took it",
      os.path.exists(recpath) and "claude" in open(recpath).read(), "missing")
# and the second harness is told nothing, but nothing is lost or double-marked
e14 = dict(e13); e14.pop("CLAUDE_CODE_ENTRYPOINT"); e14["PI_SESSION_ID"] = "dddd8888"
p14 = subprocess.run([PY, HOOK], input=b'{"hook_event_name":"UserPromptSubmit","session_id":"dddd8888"}',
                     capture_output=True, env=e14)
check("second harness: gets no duplicate of the same message", b"Incoming Tor" not in p14.stdout,
      p14.stdout[:80].decode("utf-8", "replace"))
check("second harness: did not erase the first claim",
      "cccc7777" in open(recpath).read() or "claude" in open(recpath).read(), open(recpath).read())

# ---- the payload must be the ONLY thing on stdout -----------------------------
# Measured on Claude Code 2.1.302: one extra stdout line discards the whole hook
# output silently, exit 0, nothing injected, message already marked delivered.
for ev in ("SessionStart", "UserPromptSubmit", "Stop"):
    d15 = mkstate(1)   # fresh state: the first delivery marks the only message
    rc, out, err = run(d15, {"hook_event_name": ev, "session_id": "abab1212"},
                       env_extra={"CLAUDE_CODE_ENTRYPOINT": "cli"})
    stripped = out.strip()
    one_object = stripped.startswith("{") and stripped.endswith("}") and stripped.count("\n") == 0
    check(f"stdout: {ev} emits one JSON object and nothing else", one_object, out[:120])
    if stripped:
        obj = json.loads(stripped)
        # Stop answers with a decision, not with context; both shapes are legal,
        # and asserting one shape for every event is how a test lies about a pass.
        if ev == "Stop":
            check(f"stdout: {ev} answers with a decision or context",
                  "decision" in obj or "hookSpecificOutput" in obj, stripped[:120])
        else:
            check(f"stdout: {ev} names its own event",
                  obj["hookSpecificOutput"]["hookEventName"] == ev, stripped[:120])

# a manual drain is the opposite case: a human runs it and wants prose
d16 = mkstate(1)
rc, out, err = run(d16, {}, "--print")
check("stdout: manual drain prints prose, not JSON", not out.strip().startswith("{"), out[:80])

# and the hook must not write a payload for an event it does not support
d17 = mkstate(1)
rc, out, err = run(d17, {"hook_event_name": "SomeFutureEvent", "session_id": "cdcd3434"})
check("stdout: unsupported event emits nothing", out.strip() == "", out[:80])
check("trace: unsupported event is recorded, not silent",
      "unsupported-event" in open(os.path.join(d17, "state", "hook.log")).read(), "missing")

# ---- the doctor probe must look without taking --------------------------------
d18 = mkstate(1)
e18 = dict(os.environ, TORAGENTS_HOME=d18, TORAGENTS_PEEK_JSON="1")
e18.pop("TORAGENTS_STATE", None)
p18 = subprocess.run([PY, HOOK], input=b'{"hook_event_name":"UserPromptSubmit","session_id":"efef5656"}',
                     capture_output=True, env=e18)
out18 = p18.stdout.decode()
check("peek-json: emits one JSON object for the harness", out18.strip().startswith("{") and p18.returncode == 0, out18[:60])
check("peek-json: marks nothing", not os.path.exists(os.path.join(d18, "state", "announced.json")), "marked")
check("peek-json: mail stays in the inbox", len(os.listdir(os.path.join(d18, "state", "inbox"))) == 1, "consumed")

# ---- doctor must diagnose a config that could never run ----------------------
def doctor(home, state):
    e = dict(os.environ, HOME=home, TORAGENTS_STATE=state)
    e.pop("TORAGENTS_HOME", None)
    r = subprocess.run([PY, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "inbox_agent.py"), "doctor"],
                       capture_output=True, env=e)
    return (r.stdout + r.stderr).decode("utf-8", "replace")

def home_with(settings: str, cmd: str):
    import tempfile
    h = tempfile.mkdtemp(); st = os.path.join(h, "state")
    os.makedirs(os.path.join(h, ".claude")); os.makedirs(os.path.join(st, "inbox"))
    open(os.path.join(h, ".claude", "settings.json"), "w").write(
        settings or '{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"%s"}]}]}}' % cmd)
    return h, st

h19, s19 = home_with("", PY + " " + HOOK)
t19 = doctor(h19, s19)
check("doctor: proves the configured command works", "works: emitted UserPromptSubmit JSON" in t19, t19[-400:])
h20, s20 = home_with("", PY + " /tmp/definitely-not-here/toragents_hook.py")
check("doctor: missing script is named, not silent", "MISSING" in doctor(h20, s20), "no MISSING")
h21, s21 = home_with('{"hooks":{oops', "")
check("doctor: unparseable settings.json is called BROKEN", "does not parse" in doctor(h21, s21), "no parse error")
h22, s22 = home_with('{"disableAllHooks":true,"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"%s"}]}]}}' % (PY + " " + HOOK), "")
check("doctor: disableAllHooks is called out", "disableAllHooks is true" in doctor(h22, s22), "not reported")

check("--peek never marks", run(d3, {}, "--peek")[1] != "" and ann(d3) is None)

print(f"\n  {PASS} passed, {FAIL} failed")
sys.exit(1 if FAIL else 0)
