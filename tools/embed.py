#!/usr/bin/env python3
"""Regenerate the embedded payloads in setup.sh from the source files.

`curl | bash` has no script directory, and fetching companions from a pinned
ref is fragile (a force-moved tag served stale bytes from the CDN, which is how
this was found). Embedding the files makes setup.sh self-contained: one URL,
one file, no ref resolution, no version skew between installer and payload.

Run after editing inbox_agent.py or wire.py:   python3 tools/embed.py
"""
import base64
import pathlib
import re

HERE = pathlib.Path(__file__).resolve().parent.parent
SETUP = HERE / "setup.sh"

for name, var in (("inbox_agent.py", "PAYLOAD_INBOX"), ("wire.py", "PAYLOAD_WIRE")):
    src = (HERE / name).read_bytes()
    b64 = base64.b64encode(src).decode()
    text = SETUP.read_text()
    text, n = re.subn(
        rf"^{var}='[^']*'$",
        f"{var}='{b64}'",
        text,
        flags=re.MULTILINE,
    )
    if n != 1:
        raise SystemExit(f"expected exactly one {var}= line in setup.sh, found {n}")
    SETUP.write_text(text)
    print(f"{var}: {len(src)} bytes -> {len(b64)} b64 chars")
