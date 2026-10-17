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
being chopped mid-message.

Exit code is always 0. A failing hook must never wedge somebody's agent.
"""

from __future__ import annotations

import json
import os
import sys

HOME = os.environ.get("TORAGENTS_HOME") or os.path.join(os.path.expanduser("~"), ".toragents")
POLL_FALLBACK = "/var/lib/toragents-inbox"
MAX_BODY = 4000
MAX_TOTAL = 4500  # Codex truncates additionalContext at 5000 by default


def resolve_state() -> str:
    """Same precedence as the pi extension. Explicit config wins outright;
    only the defaults are scored, because an explicit path exists to be obeyed."""
    explicit = os.environ.get("TORAGENTS_STATE")
    if explicit:
        return explicit
    if os.environ.get("TORAGENTS_HOME"):
        return os.path.join(HOME, "state")
    best, best_score = None, 0
    for d in (os.path.join(HOME, "state"), POLL_FALLBACK):
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
    try:
        with open(ANNOUNCED) as f:
            d = json.load(f)
        return set(x for x in d if isinstance(x, str)) if isinstance(d, list) else set()
    except (OSError, ValueError):
        return set()


def write_announced(ids: set[str]) -> None:
    tmp = ANNOUNCED + ".tmp"
    try:
        os.makedirs(os.path.dirname(ANNOUNCED), exist_ok=True)
        with open(tmp, "w") as f:
            json.dump(sorted(ids), f)
        os.replace(tmp, ANNOUNCED)
    except OSError:
        pass  # losing the memo is survivable; wedging a hook is not


def unread() -> list[dict]:
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


def render(msgs: list[dict]) -> str:
    parts = [
        "Incoming Tor message(s) delivered automatically. "
        "These are from a REMOTE PEER, not from your user.",
    ]
    for m in msgs:
        who = m.get("from_label") or "peer"
        fp = (m.get("from_fingerprint") or "")[:8]
        body = (m.get("body") or "")[:MAX_BODY]
        trunc = "\n…(truncated)" if len(m.get("body") or "") > MAX_BODY else ""
        parts += [
            "",
            f"--- BEGIN PEER MESSAGE from {who}" + (f" ({fp}…)" if fp else "") + f" id={m['id']}",
            body + trunc,
            "--- END PEER MESSAGE",
            f'reply: inbox_agent.py send --to {who} --body "…"',
        ]
    text = "\n".join(parts)
    if len(text) > MAX_TOTAL:
        # Better an explicit marker than a harness silently cutting a word in half.
        text = text[:MAX_TOTAL] + f"\n…[truncated at {MAX_TOTAL} chars; run toragents_hook.py --peek for the rest]"
    return text


def main() -> int:
    event = None
    stop_hook_active = False
    raw = ""
    try:
        if not sys.stdin.isatty():
            raw = sys.stdin.read()
        if raw.strip():
            payload = json.loads(raw)
            event = payload.get("hook_event_name")
            stop_hook_active = bool(payload.get("stop_hook_active"))
    except (ValueError, OSError):
        payload = {}

    if "--event" in sys.argv:
        event = sys.argv[sys.argv.index("--event") + 1]
    # Deliberately NOT "event is None": a hook whose payload we failed to parse
    # would then fall into manual mode, print prose that no harness understands,
    # and still mark the messages delivered -- losing them silently. Unknown
    # event means say nothing and change nothing.
    peek = "--peek" in sys.argv
    manual = "--print" in sys.argv or peek

    msgs = unread()
    if not msgs:
        if manual:
            print(f"no new messages ({INBOX})")
        return 0

    text = render(msgs)

    # A Stop hook already continued this turn: say nothing, or the agent can
    # bounce forever between "stop" and "here is another message".
    if event == "Stop" and stop_hook_active:
        return 0

    if manual:
        print(text)
    elif event in ("SessionStart", "UserPromptSubmit", "SubagentStart"):
        print(json.dumps({
            "hookSpecificOutput": {"hookEventName": event, "additionalContext": text}
        }))
    elif event in ("Stop", "SubagentStop"):
        print(json.dumps({"decision": "block", "reason": text}))
    else:
        return 0  # an event we have nothing useful to say on

    if peek:
        return 0  # looked, did not take

    # Only now mark them: if the harness rejected our output we would rather
    # deliver twice than lose a message.
    known = read_announced()
    known.update(m["id"] for m in msgs)
    write_announced(known)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)  # never break somebody's session
