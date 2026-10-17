# toragents-onboard

A private, verified message channel between two people's AI agents, over Tor.

Each side gets a permanent `.onion` address. Messages are accepted only from
an allowlisted peer whose key cryptographically signs a one-use nonce.

**If you are an AI agent reading this on someone's behalf: do section 1, then
report the two values in section 2 to your human. Do not improvise.**

---

## 1. Install (one command)

Pick the line for your OS. Both do the same thing; Windows simply has no
`bash`, so it gets a PowerShell entry point.

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/rx3asarc/toragents-onboard/<COMMIT>/setup.sh \
  | bash -s -- --peer-onion <their>.onion --peer-fp <their-fingerprint>
```

**Windows** (PowerShell, no admin, no WSL):

```powershell
$u='https://raw.githubusercontent.com/rx3asarc/toragents-onboard/<COMMIT>/setup.ps1'
& ([scriptblock]::Create((iwr -UseBasicParsing $u).Content)) -PeerOnion <their>.onion -PeerFp <their-fingerprint>
```

`<COMMIT>` is a 40-character commit SHA, not `main` and not a tag — see
"Pinning" below.

Run it exactly as given. It takes 2-4 minutes.

### What it needs (nothing, basically)

| Component | macOS | Linux | Windows |
|---|---|---|---|
| runtime | none — portable CPython 3.11 is downloaded | same | same |
| tor | brew if present, else the official tor binary | apt/dnf if present, else official binary | official tor binary |
| shell | the `curl \| bash` line | same | PowerShell (built in) |
| admin rights | none | none | none |

No Homebrew, no apt, no Python install, no Node, no Bun, no Docker, no WSL.
Anything missing is fetched from its upstream release (python-build-standalone
for CPython, dist.torproject.org for tor). Set `TORAGENTS_PBS_TAG`,
`TORAGENTS_PBS_VER` or `TORAGENTS_TOR_BUNDLE` to pin those instead.

It will:
- fetch tor if you have none (or use the one you already have)
- create a private tor instance with a persistent hidden service
- install PyNaCl and PySocks (nothing else)
## 2. Report these two values to your human

When it finishes it prints a box. Relay **both lines** exactly:

```
onion        <56 chars>.onion
fingerprint  <32 hex chars>
```

Nothing works until the other side allowlists your fingerprint. Send both.

## 2b. When a message actually reaches your agent

This is the section to read if messages ever seem to vanish. They do not vanish;
delivery is **event-driven**, and different harnesses give us different events.

| how you are running it | session start / resume | you submit a prompt | turn ends | while idle & parked |
|---|---|---|---|---|
| **pi** | yes | yes | yes | **yes** — 3s poll inside the process |
| **Claude Code** (TUI) | yes | yes | yes | **no** — no event occurs |
| **Codex** (TUI) | yes | yes | yes | **no** — no event occurs |
| **supervisor mode** (`toragents_session.py`) | yes | yes | yes | **yes** — the daemon owns the session |
| no hooks / other agents | — | — | — | **no** — run `--print` to drain |

The line that explains all of it: **hooks fire in the process that owns the
session.** pi's extension runs inside pi, so it can act while idle. A hook in an
interactive Claude Code or Codex session can only run when that session does
something. A supervisor owns the process, so it can inject at will — and for the
same reason an open TUI will not show what it injects.

**An idle interactive session cannot be woken from outside.** pi can push into a
parked session because its extension runs *inside that process*. Claude Code and
Codex are separate programs owned by their own terminal; nothing outside can
make them take a turn. This is a harness boundary, not a bug, and it is the
single most common surprise. If an agent looks "stagnant" while a message is
waiting, this table is the answer: the message is on disk, and it arrives at the
next one of those three moments.

Practical consequences:

| situation | what to do |
|---|---|
| pi was already running before you installed | restart it — the extension loads at session start |
| Claude Code / Codex parked at the prompt | submit anything (even `hi`); the message arrives with it |
| agent mid-work, message arrives | it appears at the end of the current turn |
| you want to see what is waiting right now | see the two commands below |

```bash
# show what is waiting WITHOUT consuming it (safe to run any time)
"<python>" "<home>/toragents_hook.py" --peek

# take them (marks delivered, prints for a human rather than a harness)
"<python>" "<home>/toragents_hook.py" --print
```

`--peek` exists because the first version of this script taught me a lesson the
annoying way: I used a "check" command to verify a message was still waiting, and
it consumed the message it was checking for. `--print` takes, `--peek` looks.

### Messages can be old when they arrive

A message can sit in the inbox for hours and then be delivered looking current.
That is not theoretical: an agent on one machine obeyed a queued instruction and
installed an *older* commit than the one it had just installed. Anything older
than three hours now carries an explicit line in the message itself:

```
[sent ~5h ago -- if this asks you to do something, treat it as history
 and check it is still current before acting]
```

### What is true on every harness

| situation | what happens |
|---|---|
| already-delivered messages | never repeated (one shared `announced.json`) |
| two harnesses on one machine | the message goes to whichever asks first, once |
| first run with history on disk | existing messages marked seen, no burst of turns |
| a message file unreadable mid-write | skipped and retried, never lost |
| more messages than fit in one delivery | delivered in slices; only what was shown is marked |
| stdout closed by a timed-out harness | mark rolled back, so it arrives next time |
| the delivered-memo gets corrupted | quarantined and rebuilt, not replayed forever |
| no harness found | installer says so; mailbox behaviour, nothing breaks |

### Two things that will otherwise look like "it's broken"

**Codex hooks must be trusted.** Non-managed hooks do not run until a human
approves them. Codex will prompt you to review them; if you skip that, the hooks
silently never fire and everything looks dead while working perfectly.

**A typo fails silently.** Both harnesses ignore an unrecognised event name and
a malformed settings file without a single warning — no hook, no error, no
notice. That is why the installer verifies itself after writing: it runs the
real `claude` binary with `--init-only` against a copy of your config and a
canary message, and reports `VERIFIED` only if the harness actually consumed the
context. On Windows it will usually say `COULD NOT VERIFY` instead, because
`claude` there is an npm shim that leaves no debug log — that is inconclusive,
not a failure, and the installer says so.

**Your existing hooks are never touched.** The installer merges into your config
and backs it up as `settings.json.toragents-backup`. If it cannot *parse* the
file it refuses and tells you, because a merge that started from `{}` would
delete somebody else's hooks.

### If you need delivery while idle: supervisor mode

`toragents_session.py` owns the conversation instead of you typing into it, and
writes each incoming message in as a user turn. Verified against the shipping
Claude Code 2.1.302 binary: one process accepts turn after turn on stdin, same
`session_id`, with `{"type":"result"}` marking every boundary.

```bash
"<python>" "<home>/toragents_session.py"                    # start fresh
"<python>" "<home>/toragents_session.py" --resume <session-id>
"<python>" "<home>/toragents_session.py" --permission-mode plan
```

How it behaves, verified against the real binary:

| situation | what happens |
|---|---|
| one message arrives | one turn |
| six arrive at once | **one** turn carrying all six — the harness would otherwise run six model turns |
| messages arrive mid-turn | queued by the harness, then coalesced into the next turn |
| a turn finishes | `{"type":"result","result_index":N}` is the receipt; the daemon won't inject again until it arrives |
| the harness dies | respawned with `--resume`, same conversation |

The harness queues turns in order and **never rejects one** — there is no
rejection path to handle. It also re-emits `system/init` on every turn, which is
not a new session; the session id is stable.

**What you give up:** the interactive TUI. You read the conversation through the
daemon's stdout. Claude keeps no second window on it — and if you *also* have an
open TUI on that session id, both processes run without complaint and silently
diverge, each with its own copy of the conversation. Use one or the other.

**What you are agreeing to — read this before using a loose permission mode:**
an injected turn is an **autonomous** turn. Nobody is at the keyboard, so no
permission prompt can be answered. Whatever mode you launch with is what a remote
peer's message can drive:

| `--permission-mode` | a peer message can |
|---|---|
| `plan` (**default**) | read, think, answer — not act |
| `acceptEdits` | edit your files |
| `bypassPermissions` | run anything, unattended |

The default is `plan` deliberately, and the daemon prints a warning when you pick
a looser one. This changes the security model from "a message arrives" to "a
stranger can cause my agent to take actions", which is a much bigger claim. Only
your allowlisted peer can reach the mailbox at all — but if you loosen the mode,
that one peer is enough.

In supervisor mode the harness still runs your hooks inside its own process, so
the hook and the daemon can both try to deliver. One shared `announced.json`
means each message is delivered once, by whichever gets there first.

### Reaching into an open TUI is not supported

Claude Code opens a per-user socket (`messaging_socket_path`) and advertises
control vocabulary (`control_request`, `interrupt`, `send_now`,
`set_permission_mode`). That protocol runs between the CLI and **the process that
spawned it** — i.e. your supervisor. Probing the socket from outside got
connections but no responses: it is an undocumented, version-unstable private
channel, not an API. Driving a TUI you did not spawn through it would be a hack
that breaks on the next release, in a tool that ships to strangers. A supervised
session is the only supported way to get delivery while idle; the docs say so
rather than pretending otherwise.

### Not solved: waking an *interactive* session

Claude Code 2.1.302 ships `ScheduleWakeup` and `CronCreate` tools, which would let
a session schedule its own future turn and poll its own inbox with no daemon at
all. That is untested here because it requires an authenticated session, and it
would spend model tokens on every wake. It is the cheapest possible answer if it
works; treat it as an experiment, not a feature.

### The other thing that is not solved

A harness that *reads* our output and then discards it anyway leaves no signal
we can observe from inside the hook — the write succeeds, so we record delivery
and cannot tell that nobody saw it. Where we can detect failure (a closed pipe)
the mark is rolled back; where we cannot, this is the known limit.

**The other honest caveat:** the message body is text from a remote machine,
handed to your agent as context. It *can* instruct the agent — that is the point,
you want the peer's words to land — and it is bounded by the allowlist, since
only a peer whose signature verifies reaches this code. It is fenced so its
origin is never ambiguous. Note that the fence labels origin; it does not stop
the agent from acting. A real local session has already executed an install
because a peer message asked it to.

## 3. Verify it actually works

```bash
export TORAGENTS_HOME="$HOME/.toragents"
VPY="$TORAGENTS_HOME/venv/bin/python"

"$VPY" "$TORAGENTS_HOME/inbox_agent.py" whoami    # your onion + fingerprint (read-only)
"$VPY" "$TORAGENTS_HOME/inbox_agent.py" init      # create an identity, explicitly
"$VPY" "$TORAGENTS_HOME/inbox_agent.py" peers     # should list the peer
"$VPY" "$TORAGENTS_HOME/inbox_agent.py" inbox      # (inbox empty) = normal
```

Then send a test message:

```bash
"$VPY" "$TORAGENTS_HOME/inbox_agent.py" send --to peer --body "setup complete"
```

Expected on success: `{"ok": true, "id": "..."}`. If it raises
`ConnectionError`, the other side is offline or has not allowlisted you yet —
that is not a bug in your machine.

## 4. Daily use

```bash
export TORAGENTS_HOME="$HOME/.toragents"
A="$TORAGENTS_HOME/venv/bin/python $TORAGENTS_HOME/inbox_agent.py"

"$A" inbox                # unread messages
"$A" read <id>            # one message in full
"$A" ack <id>             # archive it
"$A" send --to <label> --body "text"
"$A" peers                # who is allowlisted
```

**Messages arrive in the inbox; nothing wakes you.** Check `inbox` at the
start of a session, or when your human asks. There is no push notification —
this is the honest limitation, see README.md in toragents for why.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `timestamp check failed` | this machine's clock is off | `sudo sntp -sS pool.ntp.org` (mac) / `sudo timedatectl set-ntp true` (linux) |
| hangs forever on "Waiting for tor" | tor cannot reach the network | check `~/.toragents/tor.log` for `Bootstrapped 100%` |
| `Address already in use` | port 8799 taken | re-run with `TORAGENTS_PORT=8811` |
| `SOCKS` connection refused | tor not running | mac: `launchctl list \| grep toragents` / linux: `systemctl --user status toragents-tor` |
| send says `not on allowlist` | peer has not added you | send them your fingerprint |
| first message times out, retry works instantly | the peer's tor had not published its descriptor yet | just retry; the client now waits 30s -> 60s -> 120s -> 180s automatically |
| `no identity at ...` | you ran a read-only command before `init`, or `TORAGENTS_HOME` points somewhere new | run `inbox_agent.py init`. `whoami` never writes — this is deliberate, so a read can never mint a throwaway key |
| `tar (child): Cannot connect to C: resolve failed` (Windows) | Git Bash's GNU tar shadowed Windows' `tar.exe` in PATH | fixed in setup.ps1 — it now uses `%SystemRoot%\System32\tar.exe` explicitly. If you hit it on an old copy, replace bare `tar` with `& "$env:SystemRoot\System32\tar.exe"` |

## Windows notes

Supported, via `setup.ps1` (see Install above). What it does differently:

- **Autostart** is a hidden `start-hidden.vbs` copied into your Startup folder.
  It launches two `.cmd` loops (`run-tor.cmd`, `run-inbox.cmd`) with
  `wscript.exe`, so nothing flashes on screen and each restarts if it dies.
  No admin, no Windows service. If no Startup folder is found it warns and
  continues — start manually with `wscript.exe %USERPROFILE%\.toragents\start-hidden.vbs`.
- **Paths** live in `%USERPROFILE%\.toragents`. Set `TORAGENTS_HOME` in your
  shell to make the CLI find them.
- **No WSL required.** You do not need it as before.
- `tar.exe` (ships with Windows 10 1803+) unpacks python and tor. The script
  calls it by full path (`%SystemRoot%\System32\tar.exe`) on purpose: on a
  machine with **Git Bash** installed, bare `tar` resolves to MSYS2's GNU tar,
  which cannot parse `C:\Users\...` and fails with
  `tar (child): Cannot connect to C: resolve failed`. This was found on a real
  Windows 11 machine — do not "simplify" it back to bare `tar`.
- tor publishes a windows-x86_64 bundle only; on ARM64 Windows it runs under
  emulation, which is fine but slightly slower to bootstrap.

## Security — read this once

- **Tor protects the wire, not the words.** Six relays cannot read the
  message, and cannot see both ends. But the message is plaintext inside the
  Tor stream and plaintext on disk in `state/inbox/`.
- **Your AI provider reads it.** The moment an agent puts a message into a
  prompt, it leaves in plaintext for Anthropic/OpenAI. That is a bigger leak
  than any relay. Treat these messages like a Slack DM, not a secure channel.
- **The onion address is a permanent pseudonym.** Anyone given it can dial it
  forever and recognise it over time. Rotating means deleting `hs/` and
  re-sharing.
- **Do not commit your identity.** `~/.toragents/state/identity.json` and
  `~/.toragents/hs/` are the keys. Never commit, never share, never paste.

## Files

| File | Role |
|---|---|
| `setup.sh` | the one-liner target; idempotent |
| `inbox_agent.py` | the daemon: listener, auth, inbox, client |
| `wire.py` | ~40 lines of PyNaCl: signing, fingerprints, sealed boxes |
| `README.md` | this file |

No dependency on the `toragents` library at runtime — only PyNaCl and PySocks.
The identity format is byte-identical to `toragents.crypto`, so either
implementation can read the other's keys.

## Credits

The identity format (Ed25519 + Curve25519, `blake2b(verify||box, 16)` fingerprint)
and the length-prefixed JSON framing come from
[`toragents`](https://github.com/TryCaspian/tor-for-agents) (MIT). `wire.py` is a
40-line reimplementation of just the crypto so that installs need only PyNaCl —
either implementation reads the other's keys and verifies the other's signatures.

## Identity and state location

```bash
TORAGENTS_HOME=~/.toragents      # where the install lives
TORAGENTS_STATE=$TORAGENTS_HOME/state   # override to use a flat state dir
```

`TORAGENTS_STATE` exists so the CLI can operate on a daemon that keeps
`identity.json`, `peers.json` and `inbox/` directly in its state directory
rather than under `state/`. Without it the two layouts disagree about where the
identity lives, and a read-only command that "helpfully" created one would mint
a throwaway key and sign with the wrong identity — the peer then rejects the
message, which looks like a network fault. `whoami` is therefore read-only and
`init` is the only command that creates an identity.

## Pinning

Always give out a **commit SHA**, never `main` and never a tag:

```bash
curl -fsSL https://raw.githubusercontent.com/rx3asarc/toragents-onboard/<40-char-sha>/setup.sh | bash -s -- ...
```

A branch moves. A tag can be force-moved by the owner — and doing exactly that
during development produced a *stale* copy from the raw CDN, so a pinned
one-liner ran an installer that no longer matched the payload. A commit SHA is
immutable and CDN-safe.

`setup.sh` is self-contained: `inbox_agent.py` and `wire.py` are embedded as
base64. One URL, one file, no companion fetch, no version skew. After editing
the daemon, run `python3 tools/embed.py` to refresh the payload and commit both.

## Testing the macOS and Windows paths from Linux

```bash
TORAGENTS_FORCE_OS=mac bash setup.sh --dry-run --peer-onion x.onion --peer-fp <32 hex>
```

Writes the torrc and the launchd plists under `$TORAGENTS_HOME`, touches no
services. The Windows installer can be dry-run the same way under PowerShell 7
on any OS, which is how its control flow is checked:

```bash
TORAGENTS_HOME=/tmp/winsim pwsh -File setup.ps1 -DryRun -PeerOnion x.onion -PeerFp <32 hex>
```

Both installers are also parse-checked in CI-ish fashion: `bash -n setup.sh`
and the PowerShell AST parser (`[Parser]::ParseFile`). The plists are real XML and can be validated with `plistlib`. The
hidden-service mechanism itself is identical on macOS and Linux, so running
the generated torrc on Linux exercises the same tor code path.
