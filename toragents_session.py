#!/usr/bin/env python3
"""toragents session — run an agent so that incoming messages become turns.

The problem this solves: hooks fire at session start, on prompt submit and at
turn end. A session parked at the prompt produces none of those, so a message
can sit on disk with the agent unaware. Nothing outside an interactive terminal
can make it take a turn. That is a hard boundary.

The way around it is to not be a terminal. Claude Code accepts turns on stdin in
 stream-json mode, and — verified against the shipping 2.1.302 binary — one
process keeps consuming them: same session_id across turns, with
{"type":"result","result_index":N} marking each boundary. So this daemon owns
the conversation and, when a message arrives, writes it in as a user turn. The
agent wakes and answers; nobody types anything.

  toragents_session.py                 # run the session, inject incoming messages
  toragents_session.py --resume <id>   # continue an earlier session
  toragents_session.py --harness CMD   # drive something else that speaks this protocol

The trade-off is real and stated plainly in the README: this is not the
interactive TUI. You get the session in a terminal through our stdout, not
Claude's own interface. Interactive TUI *or* true push — the harness does not
offer both.

Exit codes: 0 clean, 2 usage, anything else the harness died and could not be
restarted.
"""

from __future__ import annotations

import json
import os
import queue
import shlex
import subprocess
import sys
import tempfile
import threading
import time

HOME = os.environ.get("TORAGENTS_HOME") or os.path.join(os.path.expanduser("~"), ".toragents")
FLAT_STATE = os.environ.get("TORAGENTS_DEFAULT_STATE") or "/var/lib/toragents-inbox"
POLL = float(os.environ.get("TORAGENTS_SESSION_POLL") or 2)
MAX_BODY = 4000


def resolve_state() -> str:
    if os.environ.get("TORAGENTS_STATE"):
        return os.environ["TORAGENTS_STATE"]
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


def say(msg: str) -> None:
    print(msg, flush=True)


def read_announced() -> set[str]:
    try:
        with open(ANNOUNCED) as f:
            d = json.load(f)
    except (OSError, ValueError):
        return set()
    return set(x for x in d if isinstance(x, str)) if isinstance(d, list) else set()


def mark_delivered(ids: set[str]) -> bool:
    try:
        os.makedirs(os.path.dirname(ANNOUNCED), exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=os.path.dirname(ANNOUNCED) or ".", prefix=".announced-")
        with os.fdopen(fd, "w") as f:
            json.dump(sorted(ids), f)
        os.replace(tmp, ANNOUNCED)
        return True
    except OSError:
        return False


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
            continue
    out.sort(key=lambda m: m.get("received") or 0)
    return out


def as_turn_text(msgs: list[dict]) -> str:
    parts = ["Incoming message(s) over Tor. This is a REMOTE PEER, not your user."]
    for m in msgs:
        who = m.get("from_label") or "peer"
        parts += ["", f"--- BEGIN PEER MESSAGE from {who} id={m['id']}",
                  (m.get("body") or "")[:MAX_BODY], "--- END PEER MESSAGE",
                  f'reply: inbox_agent.py send --to {who} --body "…"']
    return "\n".join(parts)


class Session:
    """Owns one harness process and writes turns into it."""

    def __init__(self, cmd: list[str]) -> None:
        self.cmd = cmd
        self.proc: subprocess.Popen | None = None
        self.session_id: str | None = None
        self.busy = False
        self.result_index = 0
        self.restarts = 0

    def start(self, resume: str | None) -> bool:
        cmd = list(self.cmd)
        if resume:
            cmd += ["--resume", resume]
        try:
            self.proc = subprocess.Popen(
                cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, text=True, bufsize=1,
                # Explicit UTF-8: text=True otherwise uses the locale encoding,
                # and a cp1252 pipe mangles Swedish text or splits a JSON line.
                encoding="utf-8", errors="replace",
            )
        except OSError as e:
            say(f"[session] cannot start harness: {e}")
            return False
        threading.Thread(target=self._read, daemon=True).start()
        return True

    def _read(self) -> None:
        assert self.proc and self.proc.stdout
        for line in self.proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
            except ValueError:
                say(line)  # harness chatter we do not understand: show, do not die
                continue
            kind = ev.get("type")
            if kind == "system" and ev.get("subtype") == "init":
                self.session_id = ev.get("session_id") or self.session_id
                say(f"[session] harness ready (session {self.session_id})")
            elif kind == "assistant":
                for block in (ev.get("message") or {}).get("content") or []:
                    if block.get("type") == "text" and block.get("text"):
                        say(f"\n{block['text']}\n")
            elif kind == "result":
                # The turn boundary. Only now is it safe to inject the next one.
                self.result_index = ev.get("result_index", self.result_index + 1)
                self.busy = False
                if ev.get("is_error") and ev.get("result"):
                    say(f"[session] harness reported: {ev['result']}")
        self.busy = False
        say("[session] harness exited")

    def alive(self) -> bool:
        return self.proc is not None and self.proc.poll() is None

    def inject(self, text: str) -> bool:
        if not self.alive() or not self.proc or not self.proc.stdin:
            return False
        turn = {"type": "user",
                "message": {"role": "user", "content": [{"type": "text", "text": text}]}}
        try:
            self.proc.stdin.write(json.dumps(turn) + "\n")
            self.proc.stdin.flush()
        except (BrokenPipeError, OSError, ValueError):
            return False
        self.busy = True
        return True


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="backslashreplace")
        except (AttributeError, ValueError, OSError):
            pass

    resume = None
    if "--resume" in sys.argv:
        resume = sys.argv[sys.argv.index("--resume") + 1]
    harness = os.environ.get("TORAGENTS_HARNESS")
    if "--harness" in sys.argv:
        harness = sys.argv[sys.argv.index("--harness") + 1]
    mode = os.environ.get("TORAGENTS_PERMISSION_MODE", "plan")
    if "--permission-mode" in sys.argv:
        mode = sys.argv[sys.argv.index("--permission-mode") + 1]
    cmd = shlex.split(harness) if harness else [
        "claude", "-p", "--verbose",
        "--input-format", "stream-json", "--output-format", "stream-json",
        # PLAN BY DEFAULT, and deliberately. An injected turn is an AUTONOMOUS
        # turn: nobody is at the keyboard to approve a tool call, so whatever
        # permission mode is set here is what a remote peer can drive. plan lets
        # the agent read and answer without acting; acceptEdits or
        # bypassPermissions would let a message make it change your machine.
        "--permission-mode", mode,
    ]

    say(f"[session] state {STATE}")
    say(f"[session] harness {' '.join(cmd)}")
    if mode in ("bypassPermissions", "acceptEdits", "auto"):
        say(f"[session] WARNING: permission mode '{mode}' lets an incoming peer message")
        say("[session] WARNING: cause real changes with nobody approving them.")
    if not os.path.isdir(INBOX):
        say(f"[session] no inbox yet at {INBOX} (the daemon creates it)")

    sess = Session(cmd)
    if not sess.start(resume):
        return 2
    if resume:
        sess.session_id = resume

    pending: queue.Queue[dict] = queue.Queue()
    # unread() keeps returning a message until it is marked, so without this a
    # message waiting in the queue would be re-queued on every poll and turn
    # into a burst of identical turns.
    queued: set[str] = set()

    try:
        while True:
            # 1. keep the harness alive; resume the same conversation if it dies
            if not sess.alive():
                sess.restarts += 1
                if sess.restarts > 5:
                    say("[session] harness keeps dying; giving up rather than looping")
                    return 1
                say(f"[session] restarting (resume {sess.session_id})")
                time.sleep(2)
                if not sess.start(sess.session_id):
                    time.sleep(5)
                continue

            # 2. queue anything new; mark only what we manage to inject
            for m in unread():
                if m["id"] not in queued:
                    queued.add(m["id"])
                    pending.put(m)

            # 3. inject one turn whenever the harness is idle
            if not sess.busy and not pending.empty():
                batch = [pending.get()]
                while not pending.empty() and len(batch) < 5:
                    batch.append(pending.get())
                text = as_turn_text(batch)
                ids = [m["id"] for m in batch]
                if sess.inject(text):
                    for i in ids:
                        queued.discard(i)
                    known = read_announced()
                    if not mark_delivered(known | set(ids)):
                        say("[session] warning: delivered but could not record it "
                            "(may repeat next start)")
                else:
                    for m in batch:      # put them back; nothing was delivered
                        pending.put(m)
                    time.sleep(2)

            time.sleep(POLL)
    except KeyboardInterrupt:
        say("\n[session] stopping")
        if sess.proc and sess.proc.poll() is None:
            try:
                sess.proc.stdin and sess.proc.stdin.close()
            except OSError:
                pass
        return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:
        say(f"[session] fatal: {e}")
        sys.exit(1)
