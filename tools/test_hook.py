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

check("--peek never marks", run(d3, {}, "--peek")[1] != "" and ann(d3) is None)

print(f"\n  {PASS} passed, {FAIL} failed")
sys.exit(1 if FAIL else 0)
