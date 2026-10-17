#!/usr/bin/env python3
"""toragents hook — deliver incoming Tor messages into any agent that has hooks.

The daemon writes incoming messages to <state>/inbox/*.json. Nothing tells the
agent. This is the piece that closes that gap for harnesses that cannot be given
an in-process extension (pi has one; Claude Code and Codex have shell hooks).

It is deliberately harness-agnostic:
  * one JSON object arrives on stdin with hook_event_name, cwd, stop_hook_active
  * we print whatever that event expects, and nothing at all otherwise
  * which messages were already delivered is recorded once, in an announced.json
    shared with the pi extension, so a machine running several harnesses does not
    deliver the same message twice

Event mapping, verified against both harnesses' docs (they agree):
  SessionStart      {"hookSpecificOutput":{"hookEventName":"SessionStart",
                                          "additionalContext":"..."}}
  UserPromptSubmit  same shape, additionalContext   (Claude Code; Codex ignores
                    what it does not understand, so printing it is safe)
  Stop              {"decision":"block","reason":"..."} -> the harness CONTINUES
                    the turn with reason as the next prompt. This is the only
                    way to reach an agent that is not waiting for input.
                    Guarded by stop_hook_active so it cannot loop.

Neither harness is required: --print shows pending messages and marks them
delivered, --peek shows them without marking (that is the fallback for agents
with no hooks at all, and --peek is what you want when merely checking).

Timeouts are a silent message-eater, so they are stated here rather than found
later: Claude Code allows a UserPromptSubmit hook only 30 seconds and, if it
times out, DISCARDS its stdout -- including additionalContext. The prompt still
reaches the model, just without our messages. That is why this script is stdlib
only and reads a handful of small files: it must finish in milliseconds, not
merely under the limit. The installer sets the hook timeout to 10s so the
harness kills us long before it would kill the injection.

Codex caps additionalContext (5000 chars by default) and Claude caps stdout at
10_000, so the rendered text is capped below the smaller of the two instead of
being chopped mid-message. The cap applies to the BATCH, never to the marking:
we mark exactly the messages we rendered and leave the rest unread, because
marking more than we rendered loses them silently (a bug I shipped once and
gale caught -- 40 messages in, 2 rendered, 40 marked, 38 gone forever).

Exit code is always 0. A failing hook must never wedge somebody's agent.
"""

from __future__ import annotations

import json
import os
import sys
import tempfile
import time

HOME = os.environ.get("TORAGENTS_HOME") or os.path.join(os.path.expanduser("~"), ".toragents")
# Overridable: a shipped default should not hard-code one machine's production
# path. It only ever scores above zero if it actually holds an identity.
FLAT_STATE = os.environ.get("TORAGENTS_DEFAULT_STATE") or "/var/lib/toragents-inbox"
MAX_BODY = 4000
MAX_TOTAL = 4500  # Codex truncates additionalContext at 5000 by default
# Name of THIS session, if the user gave it one. Used for addressing only.
MY_SESSION = (os.environ.get("TORAGENTS_SESSION") or "").strip()
SUPPORTED_EVENTS = ("SessionStart", "UserPromptSubmit", "SubagentStart",
                    "Stop", "SubagentStop")


def setup_stdout() -> None:
    """UTF-8 with a lossy fallback, always.

    On Windows the default encoding can be cp1252. A body containing an emoji or
    CJK then makes print() raise, the message is never shown, and --print looks
    like it found nothing. The JSON path is safe (json.dumps escapes to ASCII);
    the human-readable path is not, so pin it here rather than hope.
    """
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="backslashreplace")
        except (AttributeError, ValueError, OSError):
            pass


def resolve_state() -> str:
    """Same precedence as the pi extension. Explicit config wins outright;
    only the defaults are scored, because an explicit path exists to be obeyed."""
    explicit = os.environ.get("TORAGENTS_STATE")
    if explicit:
        return explicit
    if os.environ.get("TORAGENTS_HOME"):
        return os.path.join(HOME, "state")
    best, best_score = None, 0
    for d in (os.path.join(HOME, "state"), FLAT_STATE):
        score = 0
        try:
            if os.path.exists(os.path.join(d, "identity.json")):
                score += 2
            inbox = os.path.join(d, "inbox")
            if os.path.isdir(inbox):
                score += 1
                if any(n.endswith(".json") for n in os.listdir(inbox)):
                    score += 1
        except OSError:
            score = 0
        if score > best_score:
            best, best_score = d, score
    return best or os.path.join(HOME, "state")


STATE = resolve_state()
INBOX = os.path.join(STATE, "inbox")
ANNOUNCED = os.path.join(STATE, "announced.json")


def read_announced() -> set[str]:
    """Delivered ids. A corrupt memo is quarantined rather than ignored.

    Returning an empty set for a file we merely failed to parse would replay the
    whole backlog; quarantining it makes the next run start clean once instead of
    forever. An unreadable memo (not a parse problem) also yields an empty set --
    the write will fail too, and the Stop block is gated on the write succeeding,
    so the worst case is a repeated delivery, never a continuation loop.
    """
    try:
        with open(ANNOUNCED) as f:
            raw = f.read()
    except FileNotFoundError:
        return set()
    except OSError:
        return set()
    try:
        d = json.loads(raw)
    except ValueError:
        d = None
    if not isinstance(d, list):
        try:
            os.replace(ANNOUNCED, ANNOUNCED + ".corrupt")
        except OSError:
            pass
        return set()
    return set(x for x in d if isinstance(x, str))


def write_announced(ids: set[str]) -> bool:
    """True if the memo now reflects `ids`. The caller MUST care: blocking a Stop
    hook on a memo that will not stick is an infinite continuation loop, and
    burning the user's tokens is worse than a missed delivery."""
    try:
        os.makedirs(os.path.dirname(ANNOUNCED), exist_ok=True)
        # Unique temp name: two harnesses delivering at once must not share one
        # temp file and lose each other's ids.
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(ANNOUNCED) or ".", prefix=".announced-")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump(sorted(ids), f)
            os.replace(tmp, ANNOUNCED)
        except OSError:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise
        return True
    except OSError:
        return False


def scan() -> list[dict]:
    """Unread messages, oldest first. Unparseable files stay unseen for a retry."""
    known = read_announced()
    out = []
    try:
        names = [n for n in os.listdir(INBOX) if n.endswith(".json")]
    except OSError:
        return []
    for n in names:
        try:
            with open(os.path.join(INBOX, n)) as f:
                m = json.load(f)
            if isinstance(m, dict) and isinstance(m.get("id"), str) and m["id"] not in known:
                out.append(m)
        except (OSError, ValueError):
            continue  # mid-write or corrupt: leave it unseen, retry next time
    out.sort(key=lambda m: m.get("received") or 0)
    return out


def addressed_to_me(m: dict) -> bool:
    """A message can name a target session. If it does and we are not it, leave it
    for the other session -- but if THIS session has no name we deliver anyway,
    because dropping it would be a silent black hole."""
    target = (m.get("to_session") or "").strip()
    if not target or not MY_SESSION:
        return True
    return target == MY_SESSION


def banner() -> str:
    return ("Incoming Tor message(s) delivered automatically. "
            "These are from a REMOTE PEER, not from your user.")


def age_note(m: dict) -> str:
    """Messages can sit in the inbox for hours and then arrive as if current.

    A stale instruction is worse than no message: it looks live and it is not.
    Anything older than a few hours says so, in the message itself.
    """
    try:
        sent = float(m.get("received") or 0)
    except (TypeError, ValueError):
        return ""
    if sent <= 0:
        return ""
    age = time.time() - sent
    if age < 3 * 3600:
        return ""
    hours = int(age // 3600)
    return (f"[sent ~{hours}h ago -- if this asks you to do something, treat it as "
            f"history and check it is still current before acting]")


def render_one(m: dict) -> str:
    who = m.get("from_label") or "peer"
    if m.get("from_session"):
        who = f"{who} · session {m['from_session']}"
    fp = (m.get("from_fingerprint") or "")[:8]
    body = (m.get("body") or "")[:MAX_BODY]
    trunc = "\n…(truncated)" if len(m.get("body") or "") > MAX_BODY else ""
    note = age_note(m)
    to = f"\nto: {m['to_session']}" if m.get("to_session") else ""
    return "\n".join([
        f"--- BEGIN PEER MESSAGE from {who}" + (f" ({fp}…)" if fp else "") + f" id={m['id']}" + to,
        *([note] if note else []),
        body + trunc,
        "--- END PEER MESSAGE",
        f'reply: inbox_agent.py send --to {who} --body "…"',
    ])


def fit(msgs: list[dict]) -> list[dict]:
    """The messages that actually fit under MAX_TOTAL, in order, at least one.

    Budgeting the batch (not the rendered text) is what makes marking honest:
    everything we mark was shown, everything unshown stays unread for the next
    hook or a --print. On a first-run backlog this delivers in slices.
    """
    out: list[dict] = []
    used = len(banner()) + 2
    for m in msgs:
        cost = len(render_one(m)) + 2
        if out and used + cost > MAX_TOTAL:
            break
        out.append(m)
        used += cost
    return out


def render(batch: list[dict], total_unread: int) -> str:
    parts = [banner()]
    for m in batch:
        parts += ["", render_one(m)]
    rest = total_unread - len(batch)
    if rest > 0:
        parts += ["", f"…{rest} more message(s) waiting; they arrive next time "
                      "(or run toragents_hook.py --print)."]
    text = "\n".join(parts)
    if len(text) > MAX_TOTAL:
        # Should not happen after fit(); if it does, cut with a marker rather
        # than let a harness chop a word in half.
        text = text[:MAX_TOTAL] + "\n…[truncated]"
    return text


def emit(text: str, event: str | None, manual: bool) -> bool:
    """Write the answer, then prove it left. A closed stdout means the harness
    gave up (a Claude UserPromptSubmit timeout does exactly this); print() buffers
    to a pipe and only fails at interpreter exit, by which time we would have
    marked the message delivered. So flush here and report the truth."""
    if manual:
        print(text)
    elif event in ("SessionStart", "UserPromptSubmit", "SubagentStart"):
        print(json.dumps({
            "hookSpecificOutput": {"hookEventName": event, "additionalContext": text}
        }))
    elif event in ("Stop", "SubagentStop"):
        print(json.dumps({"decision": "block", "reason": text}))
    else:
        return False
    try:
        sys.stdout.flush()
        return True
    except (BrokenPipeError, OSError):
        return False


def main() -> int:
    setup_stdout()
    event = None
    stop_hook_active = False
    raw = ""
    try:
        if not sys.stdin.isatty():
            raw = sys.stdin.read()
        if raw.strip():
            payload = json.loads(raw)
            event = payload.get("hook_event_name") if isinstance(payload, dict) else None
            stop_hook_active = bool(payload.get("stop_hook_active")) if isinstance(payload, dict) else False
    except (ValueError, OSError):
        pass

    if "--event" in sys.argv:
        event = sys.argv[sys.argv.index("--event") + 1]
    # Deliberately NOT "event is None": a hook whose payload we failed to parse
    # would then fall into manual mode, print prose that no harness understands,
    # and still mark the messages delivered -- losing them silently. Unknown
    # event means say nothing and change nothing.
    peek = "--peek" in sys.argv
    manual = "--print" in sys.argv or peek

    # Decide whether we have anything to say AT ALL before touching the memo.
    # Marking and then rolling back works, but writing for an event we never
    # answer is pointless, and an empty announced.json on disk looks like state
    # somebody deliberately created.
    if not manual and event not in SUPPORTED_EVENTS:
        return 0

    msgs = scan()
    if not manual:
        # Targeted messages for another session stay unread, so that session can
        # claim them. Manual drain shows everything -- that is the escape hatch.
        msgs = [m for m in msgs if addressed_to_me(m)]
    if not msgs:
        if manual:
            print(f"no new messages ({INBOX})")
        return 0

    # A Stop hook already continued this turn: say nothing, or the agent can
    # bounce forever between "stop" and "here is another message".
    if event == "Stop" and stop_hook_active:
        return 0

    batch = fit(msgs)
    text = render(batch, len(msgs))
    known = read_announced()
    wanted = known | {m["id"] for m in batch}

    if peek:
        # Look, do not take. Nothing is marked and nothing is at risk.
        arrived = emit(text, event, manual=True)
        return 0 if arrived else 0

    # Mark BEFORE emitting, because the Stop decision depends on whether the memo
    # can hold the mark at all. If the flush then fails we roll the mark back --
    # a message nobody received must not be recorded as delivered.
    marked = write_announced(wanted)
    if event in ("Stop", "SubagentStop") and not marked:
        return 0  # never loop a continuation on a memo that will not stick

    if not emit(text, event, manual):
        if marked:
            try:
                # Roll back only our own ids: another harness may have marked
                # something in the meantime and must not lose it.
                cur = read_announced()
                write_announced(cur - {m["id"] for m in batch})
            except OSError:
                pass
        return 0

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)  # never break somebody's session
