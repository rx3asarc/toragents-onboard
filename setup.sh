#!/usr/bin/env bash
# toragents setup -- one line, then it prints two values to send back.
#
#   curl -fsSL <URL> | bash -s -- --peer-onion THEIR.onion --peer-fp THEIR_FP
#
# Installs: tor, a private tor instance with a persistent hidden service, a
# python venv, the inbox daemon, and background services. Idempotent: safe to
# re-run, never rotates an existing identity.
#
# Test without side effects:
#   TORAGENTS_FORCE_OS=mac bash setup.sh --dry-run --peer-onion x.onion --peer-fp 0123...
set -euo pipefail

# Bumped on every release. Companion files are fetched from this ref, so a
# pinned one-liner installs matching code even when main has moved on.
REPO_REF="v0.1.0"
REPO_RAW="https://raw.githubusercontent.com/rx3asarc/toragents-onboard/${REPO_REF}"

HOME_DIR="${TORAGENTS_HOME:-$HOME/.toragents}"
PORT="${TORAGENTS_PORT:-8799}"
SOCKS="${TORAGENTS_SOCKS:-9061}"     # NOT 9050: that is a homebrew tor's default
PEER_ONION=""; PEER_FP=""; PEER_LABEL="peer"; DRY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --peer-onion) PEER_ONION="$2"; shift 2 ;;
    --peer-fp)    PEER_FP="$2"; shift 2 ;;
    --peer-label) PEER_LABEL="$2"; shift 2 ;;
    --dry-run)    DRY=1; shift ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok()  { printf '  \033[32mok\033[0m %s\n' "$*"; }
warn(){ printf '  \033[33mnote\033[0m %s\n' "$*"; }
die() { printf '\n\033[31mSTOP:\033[0m %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------- platform ---
if [ -n "${TORAGENTS_FORCE_OS:-}" ]; then
  OS="$TORAGENTS_FORCE_OS"
else
  case "$(uname -s)" in
    Linux)  OS=linux ;;
    Darwin) OS=mac ;;
    *) die "This script supports macOS and Linux.

Windows: tor has no service model this script can drive. Use WSL2 (the Linux
path then works unchanged) or run tor and the daemon in two terminals." ;;
  esac
fi
ok "platform: $OS"

# The homebrew prefix differs on Apple Silicon vs Intel.
BREW=""
if [ "$OS" = mac ]; then
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$b" ] && { BREW="$b"; break; }
  done
  [ -n "$BREW" ] || command -v brew >/dev/null 2>&1 && BREW="${BREW:-$(command -v brew)}"
fi

# launchd does NOT inherit the shell PATH, so resolve absolute binaries now.
find_tor() {
  command -v tor >/dev/null 2>&1 && { command -v tor; return 0; }
  for t in /opt/homebrew/bin/tor /usr/local/bin/tor /usr/bin/tor /usr/sbin/tor; do
    [ -x "$t" ] && { echo "$t"; return 0; }
  done
  return 1
}

# macOS ships a python3 STUB that only exists to trigger an Xcode CLT install,
# so `command -v python3` can succeed while actually running fails. Test it.
find_python() {
  local c v
  for c in "$@" ; do
    command -v "$c" >/dev/null 2>&1 || continue
    "$c" -c 'import sys' >/dev/null 2>&1 || continue
    v="$("$c" -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null)" || continue
    [ -n "$v" ] || continue
    "$c" -c 'import sys;sys.exit(0 if sys.version_info>=(3,10) else 1)' 2>/dev/null || continue
    echo "$c"; return 0
  done
  return 1
}

PY="$(find_python python3 /opt/homebrew/bin/python3 /usr/local/bin/python3 || true)"
if [ -z "$PY" ]; then
  say "No usable python3 (3.10+) found"
  if [ "$OS" = mac ]; then
    printf '  macOS no longer bundles python. Install one of:\n'
    printf '    xcode-select --install      (gives you python3)\n'
    printf '    %s install python          (if Homebrew is installed)\n' "${BREW:-brew}"
  fi
  die "install python3.10+ then re-run"
fi
ok "python: $PY ($("$PY" -c 'import sys;print("%d.%d.%d"%sys.version_info[:3])'))"

# ------------------------------------------------------------------ tor ---
# No Homebrew? tor publishes a self-contained macOS binary ("expert bundle"),
# so a Mac without brew can still run this. Nothing to compile.
TOR_BUNDLE_VER="${TORAGENTS_TOR_BUNDLE:-15.0.25}"
install_tor_expert_bundle() {
  local arch url
  case "$(uname -m)" in
    arm64|aarch64) arch=aarch64 ;;
    x86_64)        arch=x86_64 ;;
    *) return 1 ;;
  esac
  url="https://dist.torproject.org/torbrowser/${TOR_BUNDLE_VER}/tor-expert-bundle-macos-${arch}-${TOR_BUNDLE_VER}.tar.gz"
  mkdir -p "$HOME_DIR/tor-bin"
  curl -fsSL "$url" | tar xz -C "$HOME_DIR/tor-bin" || return 1
  local t
  t="$(find "$HOME_DIR/tor-bin" -type f -name tor 2>/dev/null | head -1)"
  [ -n "$t" ] || return 1
  chmod +x "$t"
  xattr -d com.apple.quarantine "$t" 2>/dev/null || true
  echo "$t"
}

TORBIN="$(find_tor || true)"
if [ -z "$TORBIN" ]; then
  say "Installing tor"
  if [ "$DRY" = 1 ]; then
    warn "dry-run: would install tor"
    TORBIN=/usr/local/bin/tor
  elif [ "$OS" = mac ]; then
    if [ -n "$BREW" ]; then
      "$BREW" install tor
      TORBIN="$(find_tor || true)"
    else
      warn "no Homebrew; using the official tor expert bundle instead"
      TORBIN="$(install_tor_expert_bundle || true)"
      [ -n "$TORBIN" ] || die "could not fetch the tor expert bundle.
  Either install Homebrew (https://brew.sh) and re-run, or download tor
  manually from https://dist.torproject.org/torbrowser/"
    fi
  else
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update -qq && sudo apt-get install -y tor
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y tor
    else
      die "no supported package manager; install 'tor' manually and re-run"
    fi
    TORBIN="$(find_tor || true)"
    [ -n "$TORBIN" ] || die "tor installed but not found"
  fi
fi
ok "tor: $TORBIN"

# --------------------------------------------------------------- layout ---
mkdir -p "$HOME_DIR"
if [ "$DRY" = 1 ]; then
  say "dry-run: writing files under $HOME_DIR, no services started"
else
  mkdir -p "$HOME_DIR/hs" "$HOME_DIR/tor-data" "$HOME_DIR/state/inbox" "$HOME_DIR/state/archive"
  chmod 700 "$HOME_DIR/tor-data" "$HOME_DIR/hs"
fi

# No AvoidDiskWrites: we depend on tor writing the hostname file at startup.
cat > "$HOME_DIR/torrc" <<TORRC
# managed by toragents setup -- safe to re-run
SocksPort 127.0.0.1:$SOCKS
DataDirectory $HOME_DIR/tor-data
HiddenServiceDir $HOME_DIR/hs
HiddenServicePort 80 127.0.0.1:$PORT
Log notice file $HOME_DIR/tor.log
TORRC
ok "torrc written (hidden service -> 127.0.0.1:$PORT, socks $SOCKS)"

# ------------------------------------------------------------- python env ---
VPY="$HOME_DIR/venv/bin/python"
if [ "$DRY" = 0 ]; then
  [ -x "$VPY" ] || { say "Creating python environment"; "$PY" -m venv "$HOME_DIR/venv"; }
  "$VPY" -m pip install -q --upgrade pip
  if ! "$VPY" -c 'import nacl, socks' >/dev/null 2>&1; then
    say "Installing dependencies (PyNaCl, PySocks)"
    "$VPY" -m pip install -q PyNaCl PySocks
  fi
  "$VPY" -c 'import nacl, socks' || die "dependency install failed"
fi
ok "venv: $VPY"

# The one-liner is `curl | bash`, so there is no script directory to copy
# from: BASH_SOURCE is "bash" and dirname is ".". Fetch the companion files
# from the pinned ref instead, and fall back to local copies for a git clone.
# BASH_SOURCE is unbound under `set -u` when the script arrives on stdin, so
# test it explicitly rather than letting dirname("") resolve to the cwd.
SRC_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
for f in inbox_agent.py wire.py; do
  if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/$f" ]; then
    cp "$SRC_DIR/$f" "$HOME_DIR/$f"
    ok "installed $f (local)"
  elif curl -fsSL "$REPO_RAW/$f" -o "$HOME_DIR/$f" 2>/dev/null && [ -s "$HOME_DIR/$f" ]; then
    ok "installed $f (from $REPO_REF)"
  else
    die "could not obtain $f
  Tried alongside the script and $REPO_RAW/$f
  Check your network, or clone the repo and run ./setup.sh"
  fi
done

# -------------------------------------------------------------- services ---
say "Installing background services"
if [ "$OS" = mac ]; then
  LA="$HOME_DIR/launchagents"; mkdir -p "$LA"

  write_plist() { # label, outfile, then program args one per line after --
    local label="$1" out="$2"; shift 2
    {
      printf '<?xml version="1.0" encoding="UTF-8"?>\n'
      printf '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" '
      printf '"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
      printf '<plist version="1.0"><dict>\n'
      printf '  <key>Label</key><string>%s</string>\n' "$label"
      printf '  <key>ProgramArguments</key><array>\n'
      for a in "$@"; do printf '    <string>%s</string>\n' "$a"; done
      printf '  </array>\n'
      printf '  <key>RunAtLoad</key><true/>\n'
      printf '  <key>KeepAlive</key><true/>\n'
      printf '  <key>WorkingDirectory</key><string>%s</string>\n' "$HOME_DIR"
      printf '  <key>EnvironmentVariables</key><dict>\n'
      printf '    <key>TORAGENTS_HOME</key><string>%s</string>\n' "$HOME_DIR"
      printf '    <key>TORAGENTS_PORT</key><string>%s</string>\n' "$PORT"
      printf '    <key>TORAGENTS_SOCKS</key><string>%s</string>\n' "$SOCKS"
      printf '    <key>PATH</key><string>/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin</string>\n'
      printf '  </dict>\n'
      printf '  <key>StandardOutPath</key><string>%s/%s.out.log</string>\n' "$HOME_DIR" "$label"
      printf '  <key>StandardErrorPath</key><string>%s/%s.err.log</string>\n' "$HOME_DIR" "$label"
      printf '</dict></plist>\n'
    } > "$out"
  }

  write_plist com.toragents.tor  "$LA/com.toragents.tor.plist"  "$TORBIN" -f "$HOME_DIR/torrc"
  write_plist com.toragents.inbox "$LA/com.toragents.inbox.plist" "$VPY" "$HOME_DIR/inbox_agent.py" serve
  ok "plists written to $LA"

  if [ "$DRY" = 0 ]; then
    REAL_LA="$HOME/Library/LaunchAgents"; mkdir -p "$REAL_LA"
    cp "$LA"/*.plist "$REAL_LA"/
    for p in "$REAL_LA"/com.toragents.*.plist; do
      launchctl bootout "gui/$UID" "$p" 2>/dev/null || launchctl unload "$p" 2>/dev/null || true
      launchctl bootstrap "gui/$UID" "$p" 2>/dev/null || launchctl load "$p"
    done
    ok "services bootstrapped"
  fi
else
  UD="$HOME_DIR/systemd"; mkdir -p "$UD"
  cat > "$UD/toragents-tor.service" <<UNIT
[Unit]
Description=tor for toragents (hidden service)

[Service]
ExecStart=$TORBIN -f $HOME_DIR/torrc
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
UNIT
  cat > "$UD/toragents-inbox.service" <<UNIT
[Unit]
Description=toragents inbox daemon
After=toragents-tor.service

[Service]
ExecStart=$VPY $HOME_DIR/inbox_agent.py serve
Environment=TORAGENTS_HOME=$HOME_DIR
Environment=TORAGENTS_PORT=$PORT
Environment=TORAGENTS_SOCKS=$SOCKS
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
UNIT
  ok "units written to $UD"
  if [ "$DRY" = 0 ]; then
    RD="$HOME/.config/systemd/user"; mkdir -p "$RD"; cp "$UD"/*.service "$RD"/
    systemctl --user daemon-reload
    systemctl --user enable --now toragents-tor.service toragents-inbox.service
    ok "services enabled"
  fi
fi

# ------------------------------------------------------------------ peer ---
if [ -n "$PEER_FP" ] || [ -n "$PEER_ONION" ]; then
  [ -n "$PEER_FP" ] && [ -n "$PEER_ONION" ] \
    || die "give both --peer-fp and --peer-onion, or neither"
  if [ "$DRY" = 1 ]; then
    warn "dry-run: would allowlist $PEER_LABEL ($PEER_FP)"
  else
    printf '{\n  "%s": {"onion": "%s", "label": "%s", "added": %s}\n}\n' \
      "$PEER_FP" "$PEER_ONION" "$PEER_LABEL" "$(date +%s)" > "$HOME_DIR/state/peers.json"
    chmod 600 "$HOME_DIR/state/peers.json"
    ok "peer allowlisted: $PEER_LABEL"
  fi
else
  warn "no peer given -- nobody can send yet"
fi

# ------------------------------------------------------- first bootstrap ---
if [ "$DRY" = 1 ]; then
  say "dry-run complete. Nothing was started."
  printf '  torrc        %s/torrc\n  plists/units %s\n' "$HOME_DIR" "$HOME_DIR"
  exit 0
fi

say "Waiting for tor to publish the hidden service"
printf '  (first run bootstraps the tor network -- up to 3 minutes, be patient)\n'
i=0
while [ ! -s "$HOME_DIR/hs/hostname" ]; do
  i=$((i+1))
  if [ $i -gt 200 ]; then
    printf '\n'
    die "timed out waiting for $HOME_DIR/hs/hostname
  Check $HOME_DIR/tor.log -- it should reach 'Bootstrapped 100%'.
  Most common cause on macOS: a homebrew tor already holds port $SOCKS.
  Re-run with TORAGENTS_SOCKS=9062"
  fi
  sleep 1
done
ONION="$(cat "$HOME_DIR/hs/hostname")"
FP="$(TORAGENTS_HOME="$HOME_DIR" "$VPY" "$HOME_DIR/inbox_agent.py" whoami | awk '/fingerprint/{print $2}')"

cat <<DONE

============================================================================
  INSTALLED. Send these two values back:

  onion        $ONION
  fingerprint  $FP

  The onion is this machine's permanent address. The fingerprint is its ID.
  Your peer must allowlist the fingerprint before they can be reached.
============================================================================

  logs    $HOME_DIR/*.log
  state   $HOME_DIR/state
  stop    $( [ "$OS" = mac ] && echo "launchctl bootout gui/\$UID ~/Library/LaunchAgents/com.toragents.*.plist" || echo "systemctl --user stop toragents-tor toragents-inbox" )
  start   $( [ "$OS" = mac ] && echo "launchctl bootstrap gui/\$UID ~/Library/LaunchAgents/com.toragents.inbox.plist" || echo "systemctl --user start toragents-inbox" )

  Inside your agent:
    export TORAGENTS_HOME=$HOME_DIR
    $VPY \$TORAGENTS_HOME/inbox_agent.py inbox
    $VPY \$TORAGENTS_HOME/inbox_agent.py send --to $PEER_LABEL --body "hi"
DONE
