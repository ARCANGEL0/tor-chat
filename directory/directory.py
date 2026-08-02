#!/usr/bin/env python3
"""
TorChat Directory Server
========================
A tiny, dependency-free "phonebook" that maps friendly namecodes to Tor
.onion addresses so users don't have to type 56-character addresses.

It is purely a *lookup* service: chat messages NEVER pass through it.
The room password is NEVER sent here (it is verified by the room host).

Endpoints
---------
POST /api/register    {"namecode", "onion", "token"}    create/claim a name
POST /api/refresh     {"namecode", "token"}             keep a registration alive
POST /api/unregister  {"namecode", "token"}             release a name
GET  /api/lookup?name=<namecode>                        {"namecode","onion"}
GET  /api/list                                          all live namecodes
GET  /health                                            {"status":"ok"}

Env vars
--------
HOST      bind address          (default 0.0.0.0)
PORT      listen port           (default 8080)
TTL       registration lifetime (seconds, default 21600 = 6h)
DB_FILE   persistence path      (default ./rooms.json)

Run:
    python3 directory.py
"""

import json
import os
import secrets
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8080"))
TTL_SECONDS = int(os.environ.get("TTL", str(6 * 3600)))
DB_FILE = os.environ.get("DB_FILE", os.path.join(os.path.dirname(os.path.abspath(__file__)), "rooms.json"))

_lock = threading.Lock()
_rooms = {}  # namecode -> {"onion": str, "token": str, "lastSeen": float, "createdAt": float}


def _load():
    global _rooms
    try:
        with open(DB_FILE, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict):
            _rooms = data
    except (OSError, ValueError):
        _rooms = {}


def _save():
    try:
        tmp = DB_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(_rooms, fh, indent=2)
        os.replace(tmp, DB_FILE)
    except OSError:
        pass


def _prune(now):
    expired = [n for n, r in _rooms.items() if now - r.get("lastSeen", 0) > TTL_SECONDS]
    for name in expired:
        del _rooms[name]
    return expired


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    # ------------------------------------------------------------------ utils
    def _send(self, code, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length <= 0 or length > 1 << 20:
            return None
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            return None

    def _validate_name(self, name):
        if not name or not isinstance(name, str):
            return False
        if len(name) > 40:
            return False
        return all(c.isalnum() or c in "._-" for c in name)

    def _validate_onion(self, onion):
        if not onion or not isinstance(onion, str):
            return False
        return onion.endswith(".onion") and 16 < len(onion) <= 62

    def log_message(self, fmt, *args):
        pass  # keep logs quiet

    # ------------------------------------------------------------------ routes
    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._send(200, {"status": "ok"})
        elif parsed.path == "/api/lookup":
            query = parse_qs(parsed.query)
            name = (query.get("name") or [""])[0].lower()
            now = time.time()
            with _lock:
                _prune(now)
                room = _rooms.get(name)
            if room:
                self._send(200, {"namecode": name, "onion": room["onion"]})
            else:
                self._send(404, {"error": "not_found"})
        elif parsed.path == "/api/list":
            now = time.time()
            with _lock:
                _prune(now)
                names = sorted(_rooms.keys())
            self._send(200, {"rooms": names})
        else:
            self._send(404, {"error": "not_found"})

    def do_POST(self):
        parsed = urlparse(self.path)
        body = self._read_json()
        now = time.time()

        if parsed.path == "/api/register":
            if not body:
                self._send(400, {"error": "bad_json"})
                return
            name = (body.get("namecode") or "").lower()
            onion = (body.get("onion") or "").lower()
            token = body.get("token") or secrets.token_urlsafe(16)
            if not self._validate_name(name):
                self._send(400, {"error": "invalid_name"})
                return
            if not self._validate_onion(onion):
                self._send(400, {"error": "invalid_onion"})
                return
            with _lock:
                _prune(now)
                existing = _rooms.get(name)
                if existing and existing["token"] != token:
                    self._send(409, {"error": "name_taken"})
                    return
                _rooms[name] = {"onion": onion, "token": token, "lastSeen": now, "createdAt": existing["createdAt"] if existing else now}
                _save()
            self._send(200, {"namecode": name, "onion": onion, "token": token})

        elif parsed.path in ("/api/refresh", "/api/unregister"):
            if not body:
                self._send(400, {"error": "bad_json"})
                return
            name = (body.get("namecode") or "").lower()
            token = body.get("token") or ""
            with _lock:
                _prune(now)
                room = _rooms.get(name)
                if not room:
                    self._send(404, {"error": "not_found"})
                    return
                if room["token"] != token:
                    self._send(403, {"error": "forbidden"})
                    return
                if parsed.path == "/api/refresh":
                    room["lastSeen"] = now
                else:
                    del _rooms[name]
                _save()
            self._send(200, {"ok": True})

        else:
            self._send(404, {"error": "not_found"})


def main():
    _load()
    _prune(time.time())
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"[+] TorChat directory server listening on {HOST}:{PORT}")
    print(f"[+] {len(_rooms)} room(s) loaded, TTL = {TTL_SECONDS}s, db = {DB_FILE}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[!] Shutting down...")
        server.shutdown()


if __name__ == "__main__":
    main()
