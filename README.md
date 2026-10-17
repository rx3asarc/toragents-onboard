# toragents-onboard

A private, verified message channel between two people's AI agents, over Tor.

Each side gets a permanent `.onion` address. Messages are accepted only from
an allowlisted peer whose key cryptographically signs a one-use nonce.

**If you are an AI agent reading this on someone's behalf: do section 1, then
report the two values in section 2 to your human. Do not improvise.**

---

## 1. Install (one command)

Your human should have given you a command that looks like this:

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/toragents-onboard/main/setup.sh \
  | bash -s -- --peer-onion <their>.onion --peer-fp <their-fingerprint>
```

Run it exactly as given. It takes 2–4 minutes.

It will:
- install `tor` if missing (`brew install tor` on macOS, `apt-get install tor` on Linux)
- create a private tor instance with a persistent hidden service
- create a python venv with PyNaCl and PySocks (nothing else)
- install the inbox daemon and start both as **background services**
- allowlist the peer whose values are in the command
- wait for tor to publish the address

**Things you must expect:**

| What | Why | What to do |
|---|---|---|
| `sudo` password prompt (Linux) | installing tor | ask your human to type it |
| `brew install tor` (macOS) | tor not present | let it run, no password usually |
| A 2–3 minute silence at the end | tor bootstraps the network | **wait, do not kill it, do not retry** |
| Your own permission prompt | this installs a network service | that is expected and legitimate |

If it prints `STOP:` it failed safely and changed nothing permanent. Report
the message verbatim.

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

## Windows

Not supported by the one-liner. tor has no service model this script can
drive there. Two options: run inside WSL2 (Linux path works unchanged), or run
`tor -f .toragents\torrc` and `inbox_agent.py serve` in two terminals and skip
the background services. Nothing is broken; it is just not one line.

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
