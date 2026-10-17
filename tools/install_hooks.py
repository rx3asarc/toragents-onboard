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
import json
import os
import shutil
import sys

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
                dry: bool, uninstall: bool) -> None:
    cfg, status = load_json(path)
    if status == "unreadable" or status.startswith("corrupt"):
        log(f"{label}: SKIPPED -- {path} is {status}.")
        log(f"{label}: fix or move that file, then re-run. I will not overwrite it.")
        return
    cfg = cfg or {}
    changed = merge_hooks(cfg, command, windows_command, uninstall)
    if not changed:
        log(f"{label}: already up to date ({path})")
        return
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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--python", default=sys.executable, help="interpreter that runs the hook")
    ap.add_argument("--script", default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                     "toragents_hook.py"))
    ap.add_argument("--home", default=os.path.expanduser("~"))
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--uninstall", action="store_true")
    a = ap.parse_args()

    script = os.path.abspath(a.script)
    if not os.path.exists(script):
        log(f"hook script missing: {script}")
        return 1
    # Quoted so a python path with spaces (Windows "Program Files", mac user
    # names with spaces) survives being handed to a shell.
    command = f'"{os.path.abspath(a.python)}" "{script}"'
    windows_command = f'"{os.path.abspath(a.python)}" "{script}"'

    claude = os.path.join(a.home, ".claude")
    codex = os.path.join(a.home, ".codex")
    pi = os.path.join(a.home, ".pi")
    found = []

    if os.path.isdir(claude):
        found.append("claude")
        install_one("Claude Code", os.path.join(claude, "settings.json"),
                    command, None, a.dry_run, a.uninstall)
    if os.path.isdir(codex):
        found.append("codex")
        install_one("Codex", os.path.join(codex, "hooks.json"),
                    command, windows_command, a.dry_run, a.uninstall)
    if os.path.isdir(pi):
        log(f"pi: extension handles delivery in-session (no hook needed){' -- present' if not found else ''}")

    if not found:
        log("no Claude Code or Codex config found on this machine.")
        log("That is fine: messages wait in the inbox, and you can drain them by hand:")
        log(f'  "{os.path.abspath(a.python)}" "{script}" --print')
        log("Re-run this after installing Claude Code or Codex and the hooks will be added.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
