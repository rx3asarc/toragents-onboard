#!/usr/bin/env python3
"""Regenerate the embedded payloads in setup.sh and setup.ps1.

`curl | bash` and `irm | iex` have no script directory, and fetching the
companion files from a ref was fragile (a force-moved tag served stale bytes
from the CDN, so a pinned one-liner ran a mismatched installer). Embedding
makes each installer self-contained: one URL, one file, no version skew.

Run after editing inbox_agent.py or wire.py:   python3 tools/embed.py
"""
import base64
import pathlib
import re
import sys

# (file, variable, regex-prefix) -- the prefix differs: sh has no '$'
TARGETS = [
    ("setup.sh",  "PAYLOAD_INBOX", r"^PAYLOAD_INBOX='[^']*'$",  ""),
    ("setup.sh",  "PAYLOAD_WIRE",  r"^PAYLOAD_WIRE='[^']*'$",   ""),
    # tolerant of a stray backslash from an earlier broken run
    ("setup.ps1", "PAYLOAD_INBOX", r"^\\?\$PAYLOAD_INBOX='[^']*'$", "$"),
    ("setup.ps1", "PAYLOAD_WIRE",  r"^\\?\$PAYLOAD_WIRE='[^']*'$",  "$"),
]

HERE = pathlib.Path(__file__).resolve().parent.parent
fail = False

for target, var, pattern, prefix in TARGETS:
    path = HERE / target
    if not path.exists():
        print(f"skip {target} (absent)")
        continue
    src_name = "inbox_agent.py" if var == "PAYLOAD_INBOX" else "wire.py"
    src = (HERE / src_name).read_bytes()
    b64 = base64.b64encode(src).decode()
    text = path.read_text()
    replacement = prefix + var + f"='{b64}'"
    # function replacement => literal text, no backslash escape processing
    new, n = re.subn(pattern, lambda m: replacement, text, flags=re.MULTILINE)
    if n != 1:
        print(f"ERROR {target}: expected 1 {var} line, found {n}")
        fail = True
        continue
    path.write_text(new)
    print(f"{target:10} {var:15} {src_name} {len(src)}B -> {len(b64)} b64 chars")

sys.exit(1 if fail else 0)
