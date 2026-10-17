#!/usr/bin/env python3
"""inbox_agent.py -- a verified message inbox behind a tor hidden service.

Runs on HER machine. Listens on a plain localhost TCP port; tor forwards the
hidden service to it. Serving needs no tor API at all -- no control port, no
ADD_ONION, no keys to manage. Only outbound sends touch tor, via SOCKS.

Security model
    A message is accepted only if the sender proves possession of an
    allowlisted Ed25519 key over a one-use nonce. The sender's claimed onion
    address is never trusted for routing.

Usage
    inbox_agent.py serve                 run the daemon
    inbox_agent.py whoami                print this machine's onion + fingerprint
    inbox_agent.py add-peer FP --onion A allow a peer to send
    inbox_agent.py peers
    inbox_agent.py inbox
    inbox_agent.py read <id>
    inbox_agent.py ack <id>
    inbox_agent.py send --to LABEL --body TEXT
"""
import argparse
import base64
import json
import os
import secrets
import socket
import sys
import threading
import time
import uuid

from wire import AgentKeys, PublicIdentity

HOME = os.environ.get("TORAGENTS_HOME", os.path.expanduser("~/.toragents"))
STATE = os.path.join(HOME, "state")
INBOX = os.path.join(STATE, "inbox")
ARCHIVE = os.path.join(STATE, "archive")
PEERS = os.path.join(STATE, "peers.json")
IDFILE = os.path.join(STATE, "identity.json")
HOSTNAME_FILE = os.path.join(HOME, "hs", "hostname")

CONFIG = os.path.join(STATE, "config.json")


def _installed_config():
    """Read the ports the installer actually configured.

    This exists because the CLI and the daemon must agree on the SOCKS port and
    the daemon is the only one that gets TORAGENTS_SOCKS from its service unit.
    The old fallback was 9050 while the installer writes 9061, so every bare
    `send`/`inbox` died with "Connection refused" until the user exported the
    variable by hand. Env still wins; the recorded config is the fallback.
    """
    try:
        with open(CONFIG) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


_cfg = _installed_config()
LISTEN_PORT = int(os.environ.get("TORAGENTS_PORT") or _cfg.get("local_port") or 8799)
SOCKS_PORT = int(os.environ.get("TORAGENTS_SOCKS") or _cfg.get("socks_port") or 9050)
NONCE_TTL = 180.0

b64e = lambda b: base64.b64encode(b).decode("ascii")
b64d = lambda s: base64.b64decode(s)


# ---------------------------------------------------------------- state ---
def dirs():
    for d in (STATE, INBOX, ARCHIVE):
        os.makedirs(d, exist_ok=True)


def keys():
    dirs()
    if os.path.exists(IDFILE):
        with open(IDFILE) as f:
            return AgentKeys.from_secret_dict(json.load(f))
    k = AgentKeys.generate()
    fd = os.open(IDFILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(k.to_secret_dict(), f)
    return k


def peers():
    if not os.path.exists(PEERS):
        return {}
    try:
        with open(PEERS) as f:
            return json.load(f)
    except Exception:
        return {}


def save_peers(p):
    dirs()
    tmp = PEERS + ".tmp"
    with open(tmp, "w") as f:
        json.dump(p, f, indent=2, sort_keys=True)
    os.replace(tmp, PEERS)


def onion():
    try:
        with open(HOSTNAME_FILE) as f:
            return f.read().strip()
    except Exception:
        return None


# --------------------------------------------------------------- framing --
def send_msg(sock, obj):
    data = json.dumps(obj).encode()
    sock.sendall(len(data).to_bytes(4, "big") + data)


MAX_FRAME = 16 * 1024 * 1024  # same ceiling toragents uses; stops a hostile header


def recv_msg(sock):
    hdr = _read_exact(sock, 4)
    if hdr is None:
        return None
    n = int.from_bytes(hdr, "big")
    if n > MAX_FRAME:
        raise ValueError(f"declared frame {n} exceeds {MAX_FRAME}")
    body = _read_exact(sock, n)
    if body is None:
        return None
    return json.loads(body.decode())


def _read_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


# ---------------------------------------------------------------- nonces --
class Nonces:
    def __init__(self):
        self._d, self._lock = {}, threading.Lock()

    def issue(self):
        n = secrets.token_bytes(32)
        with self._lock:
            now = time.time()
            self._d = {k: v for k, v in self._d.items() if v > now}
            self._d[b64e(n)] = now + NONCE_TTL
        return n

    def consume(self, token):
        with self._lock:
            exp = self._d.pop(token, None)
        if exp is None or exp < time.time():
            return None
        try:
            return b64d(token)
        except Exception:
            return None


# ---------------------------------------------------------------- server --
class Inbox:
    def __init__(self):
        self.k = keys()
        self.nonces = Nonces()
        self.peers = peers()
        self.lock = threading.Lock()
        self.accepted = self.rejected = 0
        self.addr = onion()
        self._peers_mtime = self._mtime()

    def _mtime(self):
        try:
            return os.path.getmtime(PEERS)
        except OSError:
            return None

    def _reload_peers_if_changed(self):
        """Pick up `add-peer` without restarting the daemon."""
        now = self._mtime()
        if now != self._peers_mtime:
            with self.lock:
                self.peers = peers()
                self._peers_mtime = now
            print(f"[inbox] peer list reloaded ({len(self.peers)} allowed)", flush=True)

    def handle(self, req):
        op = req.get("op")
        if op == "ping":
            return {"ok": True, "service": "toragents-inbox", "onion": self.addr,
                    "fingerprint": self.k.public().fingerprint}
        if op == "hello":
            return {"ok": True, "nonce": b64e(self.nonces.issue())}
        if op == "send":
            return self._accept(req)
        return {"ok": False, "error": f"unknown op {op!r}"}

    def _accept(self, req):
        token, body, pub, sig = (req.get("nonce"), req.get("body"),
                                 req.get("pubkey"), req.get("sig"))
        if not all([token, isinstance(body, str), pub, sig]):
            self.rejected += 1
            return {"ok": False, "error": "malformed send"}

        nonce = self.nonces.consume(token)
        if nonce is None:
            self.rejected += 1
            return {"ok": False, "error": "stale or unknown nonce"}

        try:
            sender = PublicIdentity.from_dict(pub)
            signature = b64d(sig)
        except Exception:
            self.rejected += 1
            return {"ok": False, "error": "bad pubkey or signature encoding"}

        if not sender.verify(nonce + body.encode("utf-8"), signature):
            self.rejected += 1
            return {"ok": False, "error": "signature does not verify"}

        fp = sender.fingerprint
        self._reload_peers_if_changed()
        with self.lock:
            peer = self.peers.get(fp)
        if peer is None:
            self.rejected += 1
            return {"ok": False, "error": "sender not on allowlist",
                    "fingerprint": fp}

        mid = uuid.uuid4().hex[:12]
        rec = {"id": mid, "received": time.time(), "from_fingerprint": fp,
               "from_label": peer.get("label", ""), "from_onion": peer.get("onion", ""),
               "body": body}
        path = os.path.join(INBOX, f"{time.time():.0f}-{mid}.json")
        with open(path + ".tmp", "w") as f:
            json.dump(rec, f, indent=2)
        os.replace(path + ".tmp", path)
        self.accepted += 1
        print(f"[inbox] +{mid} from {peer.get('label') or fp[:12]}", flush=True)
        return {"ok": True, "id": mid}


def client_loop(conn, box):
    try:
        while True:
            req = recv_msg(conn)
            if req is None:
                break
            try:
                reply = box.handle(req)
            except Exception as exc:
                reply = {"ok": False, "error": f"handler: {exc}"}
            send_msg(conn, reply)
    except Exception:
        pass
    finally:
        try:
            conn.close()
        except Exception:
            pass


def serve():
    box = Inbox()
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", LISTEN_PORT))
    srv.listen(16)
    print(f"listening 127.0.0.1:{LISTEN_PORT}", flush=True)
    print(f"onion      {box.addr or '(hidden service not configured yet)'}", flush=True)
    print(f"fingerprint {box.k.public().fingerprint}", flush=True)
    print(f"peers      {len(box.peers)}", flush=True)
    try:
        while True:
            conn, _ = srv.accept()
            threading.Thread(target=client_loop, args=(conn, box), daemon=True).start()
    except KeyboardInterrupt:
        pass
    finally:
        srv.close()


# ---------------------------------------------------------------- client --
def dial(target_onion, timeout=120):
    """Plain SOCKS5 dial through the local tor. No tor API, just socks."""
    import socks
    host = target_onion[:-6] if target_onion.endswith(".onion") else target_onion
    last = None
    for attempt in range(4):
        s = socks.socksocket()
        s.set_proxy(socks.SOCKS5, "127.0.0.1", SOCKS_PORT, rdns=True)
        s.settimeout(max(timeout / 4, 20))
        try:
            s.connect((host + ".onion", 80))
            return s
        except Exception as exc:
            last = exc
            try:
                s.close()
            except Exception:
                pass
            time.sleep(2)
    raise ConnectionError(f"cannot reach {target_onion[:16]}...: {last}")


def send_to(target_onion, body, k=None):
    k = k or keys()
    sock = dial(target_onion)
    try:
        send_msg(sock, {"op": "hello"})
        hello = recv_msg(sock)
        if not hello or not hello.get("ok"):
            raise RuntimeError(f"hello refused: {hello}")
        nonce = b64d(hello["nonce"])
        send_msg(sock, {"op": "send", "nonce": hello["nonce"], "body": body,
                        "pubkey": k.public().to_dict(),
                        "sig": b64e(k.sign(nonce + body.encode("utf-8")))})
        return recv_msg(sock)
    finally:
        try:
            sock.close()
        except Exception:
            pass


# ------------------------------------------------------------------- cli --
def cmd_serve(a):
    serve()


def cmd_whoami(a):
    k = keys()
    print(f"onion        {onion() or '(not configured)'}")
    print(f"fingerprint  {k.public().fingerprint}")


def cmd_add_peer(a):
    p = peers()
    fp = a.fingerprint.strip().lower()
    if len(fp) != 32:
        sys.exit(f"fingerprint must be 32 hex chars (got {len(fp)})")
    if not a.onion.endswith(".onion"):
        sys.exit("--onion must end in .onion")
    p[fp] = {"onion": a.onion.strip(), "label": a.label or fp[:12],
             "added": time.time()}
    save_peers(p)
    print(f"allowlisted {p[fp]['label']} ({fp[:12]}...) -> {a.onion}")


def cmd_peers(a):
    p = peers()
    if not p:
        print("(no peers allowlisted)")
    for fp, v in sorted(p.items(), key=lambda kv: kv[1].get("label", "")):
        print(f"{v.get('label',''):18} {fp[:16]}...  {v['onion']}")


def _msgs(include_archived=False):
    out = []
    for d, arch in ((INBOX, False), (ARCHIVE, True)):
        if not os.path.isdir(d):
            continue
        if arch and not include_archived:
            continue
        for n in sorted(os.listdir(d)):
            if n.endswith(".json"):
                try:
                    with open(os.path.join(d, n)) as f:
                        m = json.load(f)
                    m["_archived"] = arch
                    out.append(m)
                except Exception:
                    pass
    return sorted(out, key=lambda m: m.get("received", 0))


def cmd_inbox(a):
    ms = _msgs(a.all)
    if not ms:
        print("(inbox empty)")
    for m in ms:
        when = time.strftime("%Y-%m-%d %H:%M", time.localtime(m.get("received", 0)))
        print(f"{m['id']}  {when}  {m.get('from_label','?'):16} "
              f"{(m.get('body') or '').replace(chr(10),' ')[:60]}")


def cmd_read(a):
    for m in _msgs(True):
        if m["id"] == a.id:
            print(json.dumps(m, indent=2))
            return
    sys.exit(f"no message {a.id}")


def cmd_ack(a):
    for n in (os.listdir(INBOX) if os.path.isdir(INBOX) else []):
        if a.id in n:
            os.replace(os.path.join(INBOX, n), os.path.join(ARCHIVE, n))
            print(f"archived {a.id}")
            return
    sys.exit(f"no unarchived message {a.id}")


def cmd_send(a):
    p = peers()
    target = None
    for fp, v in p.items():
        if a.to in (fp, v.get("label"), fp[:12]):
            target = v
            break
    if target is None:
        sys.exit(f"unknown peer {a.to!r}; try: inbox_agent.py peers")
    reply = send_to(target["onion"], a.body)
    print(json.dumps(reply, indent=2))
    sys.exit(0 if reply and reply.get("ok") else 1)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    s = ap.add_subparsers(dest="cmd", required=True)
    s.add_parser("serve").set_defaults(fn=cmd_serve)
    s.add_parser("whoami").set_defaults(fn=cmd_whoami)
    s.add_parser("peers").set_defaults(fn=cmd_peers)
    p = s.add_parser("add-peer")
    p.add_argument("fingerprint")
    p.add_argument("--onion", required=True)
    p.add_argument("--label", default="")
    p.set_defaults(fn=cmd_add_peer)
    p = s.add_parser("inbox")
    p.add_argument("--all", action="store_true")
    p.set_defaults(fn=cmd_inbox)
    p = s.add_parser("read")
    p.add_argument("id")
    p.set_defaults(fn=cmd_read)
    p = s.add_parser("ack")
    p.add_argument("id")
    p.set_defaults(fn=cmd_ack)
    p = s.add_parser("send")
    p.add_argument("--to", required=True)
    p.add_argument("--body", required=True)
    p.set_defaults(fn=cmd_send)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
