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

**If you are an AI agent** setting this up for your human, read
[AGENTS.md](AGENTS.md) instead: it is the same procedure written for you, with
the exact verification steps and the four things to report back.

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

## 2b. Messages show up in your agent

A message arrives. Your agent sees it. Your agent decides what to do about it.
That is the whole feature, and nothing here changes your permissions or decides
anything for the agent.

The one thing worth knowing is **when** it appears, because an idle terminal
doesn't produce events:

| how you run your agent | when a message appears |
|---|---|
| **pi** | immediately, even while sitting idle |
| **Claude Code** | at session start, when you submit a prompt, or when a turn ends |
| **Codex** | same three moments |

If it looks stuck, it isn't lost:

| symptom | fix |
|---|---|
| pi was running before you installed | restart pi — the extension loads at start |
| Claude Code / Codex sitting at the prompt | submit anything, even `hi` — it arrives with it |
| you want to see what's waiting | `"<python>" "<home>/toragents_hook.py" --peek` |

`--peek` shows without consuming. `--print` shows and marks them read. (The first
version of that command consumed the messages you were checking for, which is
why there are two.)

Messages older than three hours carry a note saying so — a queued instruction
that arrives looking current is how one agent here installed an older version
than the one it had just installed.

### Naming your session

A machine has one identity, but it can have several live sessions. Adding a name
lets a reply be addressed to the right one:

```bash
inbox_agent.py send --to box --session gale-fork-1 --body "hi"
inbox_agent.py send --to box --session gale --to-session gale-fork-1 --body "for you only"
```

Messages then arrive labelled `from: box · session gale` and, if targeted, with a
`to:` line. A session sets its own name with `TORAGENTS_SESSION`.

The rule, and why it is not the obvious one:

| message | who may claim it |
|---|---|
| untargeted | whoever looks first — pi's 3s poll usually wins |
| targeted at `X` | **only** a session named `X` |

A session with **no name does not take targeted mail.** The opposite rule caused
a real failure: an unnamed pi session, polling every three seconds, silently
claimed messages addressed to somebody else and they were gone before the
addressed session ever looked. Being addressable means being named; ordinary
untargeted mail still needs no name.

So if you run pi and Claude Code on one machine and want mail to reach Claude
specifically, name both and target:

```bash
# pi
$ TORAGENTS_SESSION=gale pi
# Claude Code (Windows PowerShell)
$env:TORAGENTS_SESSION="claude-code"; claude
# then
inbox_agent.py send --to <peer> --to-session claude-code --body "for Claude only"
```

A targeted message nobody claims stays unread and visible via `--peek`; it is
never silently dropped.

### What the *human* sees

An injected message is the agent's business. Whether the person watching the chat
sees anything depends on the harness:

| harness | the agent gets it | the human sees it |
|---|---|---|
| pi | yes, in-transcript | **yes** — it is a normal message |
| Claude Code | yes, as hook context | **yes** — a one-line `systemMessage` above the turn |
| Codex | yes, if hooks are trusted | yes, same field (unverified at runtime) |
| no hooks | — | no; run `--peek` yourself |

The two audiences are told separately and differently: the agent gets the full
fenced message, the person gets one line naming the sender —

```
📨 2 messages over Tor from maestro-pc -- delivered to this session
```

— and never the body. It is on a screen someone else may be looking at, and the
agent already has the text.

### Quieting a busy machine

On a box running many sessions, untargeted mail reaches all of them — that is
right for two people and wrong for seventeen. Two controls:

```bash
TORAGENTS_RECEIVE=targeted    # only mail that names this session
/toragents-mute               # in a pi session: stop delivering here
/toragents-unmute
```

A muted session says nothing **and marks nothing**, so the mail stays unread and
is still there for whoever should have it. Muting yourself never steals.

And the rule that made seventeen sessions noisy in the first place: **reply with
`--to-session`**. The reply line at the bottom of every delivered message is
already built that way — copy it rather than reconstructing it.

### Advanced, optional: delivery while idle

If Claude Code or Codex must receive while you are not typing, `toragents_session.py`
owns the session and writes messages in as turns:

```bash
"<python>" "<home>/toragents_session.py"
```

You lose the TUI (you read the conversation through the daemon) and an open TUI
will not show what it injects — both processes run and silently diverge. It does
not change your permission settings; those stay yours. Most people do not need
this: pi does it natively, and the hooks cover the rest.

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
