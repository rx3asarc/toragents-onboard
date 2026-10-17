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

## 3. Verify it actually works

```bash
export TORAGENTS_HOME="$HOME/.toragents"
VPY="$TORAGENTS_HOME/venv/bin/python"

"$VPY" "$TORAGENTS_HOME/inbox_agent.py" whoami    # your onion + fingerprint
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
- `tar.exe` (ships with Windows 10 1803+) is used to unpack python and tor.
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
