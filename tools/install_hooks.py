#!/usr/bin/env python3
"""Install toragents auto-delivery hooks into the agent harnesses on this machine.

pi gets an in-session extension (toragents_watch.ts) and needs nothing here.
Claude Code and Codex have shell hooks, so one script -- toragents_hook.py --
serves both; only the config file and the event casing differ per harness.

Design rules, learned the hard way:
  * A settings file we cannot parse is NEVER overwritten. Someone's hooks may be
    in there; a merge that starts from {} would silently delete them. We back
    out with instructions instead.
  * Re-running removes our own previous entries first, so installs are
    idempotent and a changed python path does not stack duplicates.
  * Everything is written atomically (tmp + os.replace).
  * If no harness is found we say so and exit 0 -- the daemon still works, the
    messages just wait in the inbox like they always did.

Usage:
  install_hooks.py --python <python-exe> [--script <hook.py>] [--home DIR]
                   [--dry-run] [--uninstall]
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile

MARKER = "toragents_hook.py"  # how we recognise (and later remove) our own hooks
EVENTS = ("SessionStart", "UserPromptSubmit", "Stop")
# Claude gives UserPromptSubmit only 30s and DISCARDS the hook's stdout on
# timeout -- the prompt still runs, our messages just vanish. 10s keeps us far
# away from that cliff; the script itself needs milliseconds.
TIMEOUTS = {"UserPromptSubmit": 10}
TIMEOUT_DEFAULT = 20


def log(msg: str) -> None:
    print(f"  {msg}")


def load_json(path: str) -> tuple[dict | None, str]:
    """Return (data, status). status is absent | ok | unreadable | corrupt."""
    try:
        with open(path) as f:
            raw = f.read()
    except FileNotFoundError:
        return None, "absent"
    except OSError as e:
        return None, f"unreadable ({e.strerror})"
    if not raw.strip():
        return {}, "ok"
    try:
        data = json.loads(raw)
    except ValueError as e:
        return None, f"corrupt ({e.msg})"
    if not isinstance(data, dict):
        return None, "corrupt (not a JSON object)"
    return data, "ok"


def save_json(path: str, data: dict, dry: bool) -> None:
    if dry:
        log(f"[dry-run] would write {path}")
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        shutil.copy2(path, path + ".toragents-backup")
    tmp = path + ".toragents-tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)


def hook_entry(command: str, windows_command: str | None = None,
               timeout: int = TIMEOUT_DEFAULT) -> dict:
    entry: dict = {"type": "command", "command": command, "timeout": timeout}
    if windows_command:
        entry["commandWindows"] = windows_command
    return entry


def merge_hooks(cfg: dict, command: str, windows_command: str | None,
                uninstall: bool) -> int:
    """Merge our hooks into a harness config. Returns how many event slots changed."""
    hooks = cfg.get("hooks")
    if not isinstance(hooks, dict):
        hooks = {}
    changed = 0
    for event in EVENTS:
        groups = hooks.get(event)
        if not isinstance(groups, list):
            groups = []
        # drop our own previous entries, keep every foreign one
        kept, pruned = [], 0
        for g in groups:
            inner = g.get("hooks") if isinstance(g, dict) else None
            ours = isinstance(inner, list) and any(
                isinstance(h, dict) and MARKER in str(h.get("command", "")) for h in inner
            )
            if ours:
                pruned += 1
            else:
                kept.append(g)
        if not uninstall:
            kept.append({"hooks": [hook_entry(command, windows_command,
                                             TIMEOUTS.get(event, TIMEOUT_DEFAULT))]})
        if kept != groups:
            changed += 1
        if kept:
            hooks[event] = kept
        else:
            hooks.pop(event, None)
    if hooks:
        cfg["hooks"] = hooks
    else:
        cfg.pop("hooks", None)
    return changed


def install_one(label: str, path: str, command: str, windows_command: str | None,
                dry: bool, uninstall: bool) -> str:
    """Returns written | same | skipped."""
    cfg, status = load_json(path)
    if status == "unreadable" or status.startswith("corrupt"):
        log(f"{label}: SKIPPED -- {path} is {status}.")
        log(f"{label}: fix or move that file, then re-run. I will not overwrite it.")
        return "skipped"
    cfg = cfg or {}
    changed = merge_hooks(cfg, command, windows_command, uninstall)
    if not changed:
        log(f"{label}: already up to date ({path})")
        return "same"
    save_json(path, cfg, dry)
    verb = "removed from" if uninstall else "installed into"
    log(f"{label}: hooks {verb} {path}")
    if not dry and os.path.exists(path + ".toragents-backup"):
        log(f"{label}: previous file saved as {os.path.basename(path)}.toragents-backup")
    if not uninstall and label == "Codex":
        # Non-managed hooks do not run until a human approves them. Without this
        # line a Codex user sees silence and concludes the watcher is broken.
        log("Codex: hooks must be TRUSTED before they run -- approve them when")
        log("Codex prompts, or nothing will be delivered and it will look broken.")
    return "written"


def verify_claude(settings_path: str, claude_bin: str) -> tuple[bool | None, str]:
    """True = proven, False = proven broken, None = could not tell."""
    """Ask the REAL binary whether it accepts the config we just wrote.

    This exists because a malformed settings.json fails completely silently:
    no hook runs, no warning, no error. A user sees nothing arrive and concludes
    the whole feature is broken. A canary message plus --init-only (which starts
    no conversation and needs no credentials) turns that into a one-second check.

    It runs in a throwaway copy of the home, so the user's real config and debug
    logs are not touched.
    """
    home = tempfile.mkdtemp(prefix="toragents-verify-")
    try:
        os.makedirs(os.path.join(home, ".claude"), exist_ok=True)
        shutil.copy2(settings_path, os.path.join(home, ".claude", "settings.json"))
        state = os.path.join(home, "state")
        os.makedirs(os.path.join(state, "inbox"))
        with open(os.path.join(state, "inbox", "verify.json"), "w") as f:
            json.dump({"id": "verify-canary", "body": "canary", "from_label": "verify",
                       "received": 1}, f)
        env = dict(os.environ, HOME=home, TORAGENTS_STATE=state)
        env.pop("TORAGENTS_HOME", None)
        try:
            subprocess.run([claude_bin, "--init-only", "--debug"], cwd=home, env=env,
                           capture_output=True, timeout=90)
        except (OSError, subprocess.SubprocessError) as e:
            return False, f"could not run {claude_bin}: {e}"
        logs = sorted(glob.glob(os.path.join(home, ".claude", "debug", "*.txt")),
                      key=os.path.getmtime)
        if not logs:
            # Cannot tell. On Windows `claude` is usually an npm .cmd shim, which
            # needs a shell to spawn; the run produces no log at all. Reporting
            # that as NOT VERIFIED told a user with a perfectly working install
            # that it was broken -- so it is reported as inconclusive instead.
            return None, "the harness left no debug log (normal on Windows shims)"
        txt = open(logs[-1], errors="replace").read()
        if "parsed and validated hook JSON output" not in txt:
            return False, "claude ran but never validated our hook output"
        if "additionalContext" not in txt:
            return False, "our hook ran but no context was consumed"
        return True, "real Claude Code ran our hook and consumed its context"
    finally:
        shutil.rmtree(home, ignore_errors=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--python", default=sys.executable, help="interpreter that runs the hook")
    ap.add_argument("--script", default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                     "toragents_hook.py"))
    ap.add_argument("--home", default=os.path.expanduser("~"))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--uninstall", action="store_true")
    ap.add_argument("--no-verify", action="store_true", help="skip the live harness check")
    ap.add_argument("--claude-bin", default=None, help="override the claude executable")
    a = ap.parse_args()

    script = os.path.abspath(a.script)
    if not os.path.exists(script):
        log(f"hook script missing: {script}")
        return 1
    # Quoted so a python path with spaces (Windows "Program Files", mac user
    # names with spaces) survives being handed to a shell.
    def win_ok(path: str) -> str:
        """Forward slashes: Windows accepts them everywhere, and a backslash
        inside double quotes is an escape in some shells. C:/Users/Hp/... is
        unambiguous in Git Bash, PowerShell, cmd and Python alike."""
        return os.path.abspath(path).replace("\\", "/")

    command = f'"{win_ok(a.python)}" "{win_ok(script)}"'
    windows_command = command

    claude = os.path.join(a.home, ".claude")
    codex = os.path.join(a.home, ".codex")
    pi = os.path.join(a.home, ".pi")
    found = []

    # A harness can be installed before it has ever written its config dir, so
    # "binary on PATH" counts too. Skipping here meant a fresh Claude Code
    # install got no hooks and the user saw silence, which reads as breakage.
    claude_bin = a.claude_bin or shutil.which("claude")
    claude_result = "skipped"
    if os.path.isdir(claude) or claude_bin:
        found.append("claude")
        claude_result = install_one("Claude Code", os.path.join(claude, "settings.json"),
                                    command, None, a.dry_run, a.uninstall)
    if os.path.isdir(codex) or shutil.which("codex"):
        found.append("codex")
        install_one("Codex", os.path.join(codex, "hooks.json"),
                    command, windows_command, a.dry_run, a.uninstall)
    if os.path.isdir(pi) or shutil.which("pi"):
        log(f"pi: extension handles delivery in-session (no hook needed){' -- present' if not found else ''}")

    if "claude" in found and claude_result in ("written", "same") and not a.uninstall and not a.dry_run:
        if not a.no_verify and claude_bin:
            ok, why = verify_claude(os.path.join(claude, "settings.json"), claude_bin)
            verdict = "VERIFIED" if ok else ("COULD NOT VERIFY" if ok is None else "NOT VERIFIED")
            log(f"Claude Code: {verdict} -- {why}")
            if ok is None:
                log("Claude Code: this is not a failure. Open a session; if messages")
                log("Claude Code: do not arrive, run: claude --init-only --debug")
            if ok is False:
                log("Claude Code: the hooks are written but the harness did not accept them.")
                log("Claude Code: check ~/.claude/settings.json, or run with --no-verify.")
        elif not claude_bin:
            log("Claude Code: hooks written; could not verify (no claude on PATH).")
            log("Claude Code: open a session and look for the messages -- if they do not")
            log("Claude Code: appear, run: claude --init-only --debug and check the log.")

    if not found:
        log("no Claude Code or Codex config found on this machine.")
        log("That is fine: messages wait in the inbox, and you can drain them by hand:")
        log(f'  "{os.path.abspath(a.python)}" "{script}" --print')
        log("Re-run this after installing Claude Code or Codex and the hooks will be added.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
