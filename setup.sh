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
# Write the config but do not install/start the supervisors (containers, tests):
#   bash setup.sh --no-service --peer-onion x.onion --peer-fp 0123...
set -euo pipefail

# The daemon sources are embedded here as base64 by tools/embed.py. Fetching
# them from a ref was tried and removed: a force-moved tag served stale bytes
# from the CDN, so a pinned one-liner silently ran a mismatched installer.
PAYLOAD_INBOX='IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwoiIiJpbmJveF9hZ2VudC5weSAtLSBhIHZlcmlmaWVkIG1lc3NhZ2UgaW5ib3ggYmVoaW5kIGEgdG9yIGhpZGRlbiBzZXJ2aWNlLgoKUnVucyBvbiBIRVIgbWFjaGluZS4gTGlzdGVucyBvbiBhIHBsYWluIGxvY2FsaG9zdCBUQ1AgcG9ydDsgdG9yIGZvcndhcmRzIHRoZQpoaWRkZW4gc2VydmljZSB0byBpdC4gU2VydmluZyBuZWVkcyBubyB0b3IgQVBJIGF0IGFsbCAtLSBubyBjb250cm9sIHBvcnQsIG5vCkFERF9PTklPTiwgbm8ga2V5cyB0byBtYW5hZ2UuIE9ubHkgb3V0Ym91bmQgc2VuZHMgdG91Y2ggdG9yLCB2aWEgU09DS1MuCgpTZWN1cml0eSBtb2RlbAogICAgQSBtZXNzYWdlIGlzIGFjY2VwdGVkIG9ubHkgaWYgdGhlIHNlbmRlciBwcm92ZXMgcG9zc2Vzc2lvbiBvZiBhbgogICAgYWxsb3dsaXN0ZWQgRWQyNTUxOSBrZXkgb3ZlciBhIG9uZS11c2Ugbm9uY2UuIFRoZSBzZW5kZXIncyBjbGFpbWVkIG9uaW9uCiAgICBhZGRyZXNzIGlzIG5ldmVyIHRydXN0ZWQgZm9yIHJvdXRpbmcuCgpVc2FnZQogICAgaW5ib3hfYWdlbnQucHkgc2VydmUgICAgICAgICAgICAgICAgIHJ1biB0aGUgZGFlbW9uCiAgICBpbmJveF9hZ2VudC5weSB3aG9hbWkgICAgICAgICAgICAgICAgcHJpbnQgdGhpcyBtYWNoaW5lJ3Mgb25pb24gKyBmaW5nZXJwcmludAogICAgaW5ib3hfYWdlbnQucHkgYWRkLXBlZXIgRlAgLS1vbmlvbiBBIGFsbG93IGEgcGVlciB0byBzZW5kCiAgICBpbmJveF9hZ2VudC5weSBwZWVycwogICAgaW5ib3hfYWdlbnQucHkgaW5ib3gKICAgIGluYm94X2FnZW50LnB5IHJlYWQgPGlkPgogICAgaW5ib3hfYWdlbnQucHkgYWNrIDxpZD4KICAgIGluYm94X2FnZW50LnB5IHNlbmQgLS10byBMQUJFTCAtLWJvZHkgVEVYVAoiIiIKaW1wb3J0IGFyZ3BhcnNlCmltcG9ydCBiYXNlNjQKaW1wb3J0IGpzb24KaW1wb3J0IG9zCmltcG9ydCBzZWNyZXRzCmltcG9ydCBzb2NrZXQKaW1wb3J0IHN5cwppbXBvcnQgdGhyZWFkaW5nCmltcG9ydCB0aW1lCmltcG9ydCB1dWlkCgpmcm9tIHdpcmUgaW1wb3J0IEFnZW50S2V5cywgUHVibGljSWRlbnRpdHkKCkhPTUUgPSBvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX0hPTUUiLCBvcy5wYXRoLmV4cGFuZHVzZXIoIn4vLnRvcmFnZW50cyIpKQojIFRPUkFHRU5UU19TVEFURSB3aW5zIG92ZXIgJEhPTUUvc3RhdGUgc28gdGhpcyBDTEkgY2FuIG9wZXJhdGUgb24gYSBmbGF0IHN0YXRlCiMgZGlyZWN0b3J5ICh0aGUgbGF5b3V0IGxpc3RlbmVyLnB5IHVzZXMgb24gdGhlIGJveCkuIFdpdGhvdXQgaXQgdGhlIHR3byB0b29scwojIGRpc2FncmVlIGFib3V0IHdoZXJlIGlkZW50aXR5Lmpzb24gbGl2ZXMsIGFuZCB3aG9hbWkgc2lsZW50bHkgbWludHMgYQojIHRocm93YXdheSBrZXkgYW5kIHNpZ25zIHdpdGggdGhlIHdyb25nIG9uZS4KU1RBVEUgPSBvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX1NUQVRFIikgb3Igb3MucGF0aC5qb2luKEhPTUUsICJzdGF0ZSIpCklOQk9YID0gb3MucGF0aC5qb2luKFNUQVRFLCAiaW5ib3giKQpBUkNISVZFID0gb3MucGF0aC5qb2luKFNUQVRFLCAiYXJjaGl2ZSIpClBFRVJTID0gb3MucGF0aC5qb2luKFNUQVRFLCAicGVlcnMuanNvbiIpCklERklMRSA9IG9zLnBhdGguam9pbihTVEFURSwgImlkZW50aXR5Lmpzb24iKQpIT1NUTkFNRV9GSUxFID0gb3MucGF0aC5qb2luKEhPTUUsICJocyIsICJob3N0bmFtZSIpCgpDT05GSUcgPSBvcy5wYXRoLmpvaW4oU1RBVEUsICJjb25maWcuanNvbiIpCgoKZGVmIF9pbnN0YWxsZWRfY29uZmlnKCk6CiAgICAiIiJSZWFkIHRoZSBwb3J0cyB0aGUgaW5zdGFsbGVyIGFjdHVhbGx5IGNvbmZpZ3VyZWQuCgogICAgVGhpcyBleGlzdHMgYmVjYXVzZSB0aGUgQ0xJIGFuZCB0aGUgZGFlbW9uIG11c3QgYWdyZWUgb24gdGhlIFNPQ0tTIHBvcnQgYW5kCiAgICB0aGUgZGFlbW9uIGlzIHRoZSBvbmx5IG9uZSB0aGF0IGdldHMgVE9SQUdFTlRTX1NPQ0tTIGZyb20gaXRzIHNlcnZpY2UgdW5pdC4KICAgIFRoZSBvbGQgZmFsbGJhY2sgd2FzIDkwNTAgd2hpbGUgdGhlIGluc3RhbGxlciB3cml0ZXMgOTA2MSwgc28gZXZlcnkgYmFyZQogICAgYHNlbmRgL2BpbmJveGAgZGllZCB3aXRoICJDb25uZWN0aW9uIHJlZnVzZWQiIHVudGlsIHRoZSB1c2VyIGV4cG9ydGVkIHRoZQogICAgdmFyaWFibGUgYnkgaGFuZC4gRW52IHN0aWxsIHdpbnM7IHRoZSByZWNvcmRlZCBjb25maWcgaXMgdGhlIGZhbGxiYWNrLgogICAgIiIiCiAgICB0cnk6CiAgICAgICAgd2l0aCBvcGVuKENPTkZJRykgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIGpzb24ubG9hZChmKQogICAgZXhjZXB0IChPU0Vycm9yLCBWYWx1ZUVycm9yKToKICAgICAgICByZXR1cm4ge30KCgpfY2ZnID0gX2luc3RhbGxlZF9jb25maWcoKQpMSVNURU5fUE9SVCA9IGludChvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX1BPUlQiKSBvciBfY2ZnLmdldCgibG9jYWxfcG9ydCIpIG9yIDg3OTkpClNPQ0tTX1BPUlQgPSBpbnQob3MuZW52aXJvbi5nZXQoIlRPUkFHRU5UU19TT0NLUyIpIG9yIF9jZmcuZ2V0KCJzb2Nrc19wb3J0Iikgb3IgOTA1MCkKTk9OQ0VfVFRMID0gMTgwLjAKCmI2NGUgPSBsYW1iZGEgYjogYmFzZTY0LmI2NGVuY29kZShiKS5kZWNvZGUoImFzY2lpIikKYjY0ZCA9IGxhbWJkYSBzOiBiYXNlNjQuYjY0ZGVjb2RlKHMpCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIHN0YXRlIC0tLQpkZWYgZGlycygpOgogICAgZm9yIGQgaW4gKFNUQVRFLCBJTkJPWCwgQVJDSElWRSk6CiAgICAgICAgb3MubWFrZWRpcnMoZCwgZXhpc3Rfb2s9VHJ1ZSkKCgpkZWYga2V5cyhjcmVhdGU9RmFsc2UpOgogICAgIiIiTG9hZCB0aGUgaWRlbnRpdHkuIFJldHVybnMgTm9uZSBpZiBhYnNlbnQgYW5kIGNyZWF0ZSBpcyBGYWxzZS4KCiAgICBNaW50aW5nIGlzIG9wdC1pbiBvbiBwdXJwb3NlLiBBIHJlYWQtb25seSBjb21tYW5kIHRoYXQgY3JlYXRlcyBhbiBpZGVudGl0eQogICAgaXMgYSBmb290Z3VuOiBpdCB3cml0ZXMgYSBuZXcga2V5LCBhbmQgYW55dGhpbmcgdGhhdCB0aGVuIHNpZ25zIHdpdGggaXQgaXMKICAgIHNpbGVudGx5IHVzaW5nIHRoZSB3cm9uZyBpZGVudGl0eSwgd2hpY2ggdGhlIHBlZXIgcmVqZWN0cyBpbiBhIHdheSB0aGF0CiAgICBsb29rcyBsaWtlIGEgbmV0d29yayBmYXVsdC4KICAgICIiIgogICAgZGlycygpCiAgICBpZiBvcy5wYXRoLmV4aXN0cyhJREZJTEUpOgogICAgICAgIHdpdGggb3BlbihJREZJTEUpIGFzIGY6CiAgICAgICAgICAgIHJldHVybiBBZ2VudEtleXMuZnJvbV9zZWNyZXRfZGljdChqc29uLmxvYWQoZikpCiAgICBpZiBub3QgY3JlYXRlOgogICAgICAgIHJldHVybiBOb25lCiAgICBrID0gQWdlbnRLZXlzLmdlbmVyYXRlKCkKICAgIGZkID0gb3Mub3BlbihJREZJTEUsIG9zLk9fV1JPTkxZIHwgb3MuT19DUkVBVCB8IG9zLk9fVFJVTkMsIDBvNjAwKQogICAgd2l0aCBvcy5mZG9wZW4oZmQsICJ3IikgYXMgZjoKICAgICAgICBqc29uLmR1bXAoay50b19zZWNyZXRfZGljdCgpLCBmKQogICAgcmV0dXJuIGsKCgpkZWYgbmVlZF9rZXlzKCk6CiAgICBrID0ga2V5cygpCiAgICBpZiBrIGlzIE5vbmU6CiAgICAgICAgcHJpbnQoZiJubyBpZGVudGl0eSBhdCB7SURGSUxFfSIsIGZpbGU9c3lzLnN0ZGVycikKICAgICAgICBwcmludCgiICBjcmVhdGUgb25lIHdpdGg6ICBpbmJveF9hZ2VudC5weSBpbml0IiwgZmlsZT1zeXMuc3RkZXJyKQogICAgICAgIHByaW50KCIgICh0aGUgaW5zdGFsbGVyIGRvZXMgdGhpcyBmb3IgeW91OyB3aG9hbWkgbmV2ZXIgd3JpdGVzKSIsCiAgICAgICAgICAgICAgZmlsZT1zeXMuc3RkZXJyKQogICAgICAgIHJhaXNlIFN5c3RlbUV4aXQoMikKICAgIHJldHVybiBrCgoKZGVmIHBlZXJzKCk6CiAgICBpZiBub3Qgb3MucGF0aC5leGlzdHMoUEVFUlMpOgogICAgICAgIHJldHVybiB7fQogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihQRUVSUykgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIGpzb24ubG9hZChmKQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICByZXR1cm4ge30KCgpkZWYgc2F2ZV9wZWVycyhwKToKICAgIGRpcnMoKQogICAgdG1wID0gUEVFUlMgKyAiLnRtcCIKICAgIHdpdGggb3Blbih0bXAsICJ3IikgYXMgZjoKICAgICAgICBqc29uLmR1bXAocCwgZiwgaW5kZW50PTIsIHNvcnRfa2V5cz1UcnVlKQogICAgb3MucmVwbGFjZSh0bXAsIFBFRVJTKQoKCmRlZiBvbmlvbigpOgogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihIT1NUTkFNRV9GSUxFKSBhcyBmOgogICAgICAgICAgICByZXR1cm4gZi5yZWFkKCkuc3RyaXAoKQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICByZXR1cm4gTm9uZQoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIGZyYW1pbmcgLS0KZGVmIHNlbmRfbXNnKHNvY2ssIG9iaik6CiAgICBkYXRhID0ganNvbi5kdW1wcyhvYmopLmVuY29kZSgpCiAgICBzb2NrLnNlbmRhbGwobGVuKGRhdGEpLnRvX2J5dGVzKDQsICJiaWciKSArIGRhdGEpCgoKTUFYX0ZSQU1FID0gMTYgKiAxMDI0ICogMTAyNCAgIyBzYW1lIGNlaWxpbmcgdG9yYWdlbnRzIHVzZXM7IHN0b3BzIGEgaG9zdGlsZSBoZWFkZXIKCgpkZWYgcmVjdl9tc2coc29jayk6CiAgICBoZHIgPSBfcmVhZF9leGFjdChzb2NrLCA0KQogICAgaWYgaGRyIGlzIE5vbmU6CiAgICAgICAgcmV0dXJuIE5vbmUKICAgIG4gPSBpbnQuZnJvbV9ieXRlcyhoZHIsICJiaWciKQogICAgaWYgbiA+IE1BWF9GUkFNRToKICAgICAgICByYWlzZSBWYWx1ZUVycm9yKGYiZGVjbGFyZWQgZnJhbWUge259IGV4Y2VlZHMge01BWF9GUkFNRX0iKQogICAgYm9keSA9IF9yZWFkX2V4YWN0KHNvY2ssIG4pCiAgICBpZiBib2R5IGlzIE5vbmU6CiAgICAgICAgcmV0dXJuIE5vbmUKICAgIHJldHVybiBqc29uLmxvYWRzKGJvZHkuZGVjb2RlKCkpCgoKZGVmIF9yZWFkX2V4YWN0KHNvY2ssIG4pOgogICAgYnVmID0gYiIiCiAgICB3aGlsZSBsZW4oYnVmKSA8IG46CiAgICAgICAgY2h1bmsgPSBzb2NrLnJlY3YobiAtIGxlbihidWYpKQogICAgICAgIGlmIG5vdCBjaHVuazoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKICAgICAgICBidWYgKz0gY2h1bmsKICAgIHJldHVybiBidWYKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gbm9uY2VzIC0tCmNsYXNzIE5vbmNlczoKICAgIGRlZiBfX2luaXRfXyhzZWxmKToKICAgICAgICBzZWxmLl9kLCBzZWxmLl9sb2NrID0ge30sIHRocmVhZGluZy5Mb2NrKCkKCiAgICBkZWYgaXNzdWUoc2VsZik6CiAgICAgICAgbiA9IHNlY3JldHMudG9rZW5fYnl0ZXMoMzIpCiAgICAgICAgd2l0aCBzZWxmLl9sb2NrOgogICAgICAgICAgICBub3cgPSB0aW1lLnRpbWUoKQogICAgICAgICAgICBzZWxmLl9kID0ge2s6IHYgZm9yIGssIHYgaW4gc2VsZi5fZC5pdGVtcygpIGlmIHYgPiBub3d9CiAgICAgICAgICAgIHNlbGYuX2RbYjY0ZShuKV0gPSBub3cgKyBOT05DRV9UVEwKICAgICAgICByZXR1cm4gbgoKICAgIGRlZiBjb25zdW1lKHNlbGYsIHRva2VuKToKICAgICAgICB3aXRoIHNlbGYuX2xvY2s6CiAgICAgICAgICAgIGV4cCA9IHNlbGYuX2QucG9wKHRva2VuLCBOb25lKQogICAgICAgIGlmIGV4cCBpcyBOb25lIG9yIGV4cCA8IHRpbWUudGltZSgpOgogICAgICAgICAgICByZXR1cm4gTm9uZQogICAgICAgIHRyeToKICAgICAgICAgICAgcmV0dXJuIGI2NGQodG9rZW4pCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gc2VydmVyIC0tCmNsYXNzIEluYm94OgogICAgZGVmIF9faW5pdF9fKHNlbGYpOgogICAgICAgIHNlbGYuayA9IGtleXMoY3JlYXRlPVRydWUpICAgIyBhIGRhZW1vbiBjb21pbmcgdXAgaXMgYWxsb3dlZCB0byBtaW50CiAgICAgICAgc2VsZi5ub25jZXMgPSBOb25jZXMoKQogICAgICAgIHNlbGYucGVlcnMgPSBwZWVycygpCiAgICAgICAgc2VsZi5sb2NrID0gdGhyZWFkaW5nLkxvY2soKQogICAgICAgIHNlbGYuYWNjZXB0ZWQgPSBzZWxmLnJlamVjdGVkID0gMAogICAgICAgIHNlbGYuYWRkciA9IG9uaW9uKCkKICAgICAgICBzZWxmLl9wZWVyc19tdGltZSA9IHNlbGYuX210aW1lKCkKCiAgICBkZWYgX210aW1lKHNlbGYpOgogICAgICAgIHRyeToKICAgICAgICAgICAgcmV0dXJuIG9zLnBhdGguZ2V0bXRpbWUoUEVFUlMpCiAgICAgICAgZXhjZXB0IE9TRXJyb3I6CiAgICAgICAgICAgIHJldHVybiBOb25lCgogICAgZGVmIF9yZWxvYWRfcGVlcnNfaWZfY2hhbmdlZChzZWxmKToKICAgICAgICAiIiJQaWNrIHVwIGBhZGQtcGVlcmAgd2l0aG91dCByZXN0YXJ0aW5nIHRoZSBkYWVtb24uIiIiCiAgICAgICAgbm93ID0gc2VsZi5fbXRpbWUoKQogICAgICAgIGlmIG5vdyAhPSBzZWxmLl9wZWVyc19tdGltZToKICAgICAgICAgICAgd2l0aCBzZWxmLmxvY2s6CiAgICAgICAgICAgICAgICBzZWxmLnBlZXJzID0gcGVlcnMoKQogICAgICAgICAgICAgICAgc2VsZi5fcGVlcnNfbXRpbWUgPSBub3cKICAgICAgICAgICAgcHJpbnQoZiJbaW5ib3hdIHBlZXIgbGlzdCByZWxvYWRlZCAoe2xlbihzZWxmLnBlZXJzKX0gYWxsb3dlZCkiLCBmbHVzaD1UcnVlKQoKICAgIGRlZiBoYW5kbGUoc2VsZiwgcmVxKToKICAgICAgICBvcCA9IHJlcS5nZXQoIm9wIikKICAgICAgICBpZiBvcCA9PSAicGluZyI6CiAgICAgICAgICAgIHJldHVybiB7Im9rIjogVHJ1ZSwgInNlcnZpY2UiOiAidG9yYWdlbnRzLWluYm94IiwgIm9uaW9uIjogc2VsZi5hZGRyLAogICAgICAgICAgICAgICAgICAgICJmaW5nZXJwcmludCI6IHNlbGYuay5wdWJsaWMoKS5maW5nZXJwcmludH0KICAgICAgICBpZiBvcCA9PSAiaGVsbG8iOgogICAgICAgICAgICByZXR1cm4geyJvayI6IFRydWUsICJub25jZSI6IGI2NGUoc2VsZi5ub25jZXMuaXNzdWUoKSl9CiAgICAgICAgaWYgb3AgPT0gInNlbmQiOgogICAgICAgICAgICByZXR1cm4gc2VsZi5fYWNjZXB0KHJlcSkKICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiBmInVua25vd24gb3Age29wIXJ9In0KCiAgICBkZWYgX2FjY2VwdChzZWxmLCByZXEpOgogICAgICAgIHRva2VuLCBib2R5LCBwdWIsIHNpZyA9IChyZXEuZ2V0KCJub25jZSIpLCByZXEuZ2V0KCJib2R5IiksCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIHJlcS5nZXQoInB1YmtleSIpLCByZXEuZ2V0KCJzaWciKSkKICAgICAgICBpZiBub3QgYWxsKFt0b2tlbiwgaXNpbnN0YW5jZShib2R5LCBzdHIpLCBwdWIsIHNpZ10pOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogIm1hbGZvcm1lZCBzZW5kIn0KCiAgICAgICAgbm9uY2UgPSBzZWxmLm5vbmNlcy5jb25zdW1lKHRva2VuKQogICAgICAgIGlmIG5vbmNlIGlzIE5vbmU6CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAic3RhbGUgb3IgdW5rbm93biBub25jZSJ9CgogICAgICAgIHRyeToKICAgICAgICAgICAgc2VuZGVyID0gUHVibGljSWRlbnRpdHkuZnJvbV9kaWN0KHB1YikKICAgICAgICAgICAgc2lnbmF0dXJlID0gYjY0ZChzaWcpCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJiYWQgcHVia2V5IG9yIHNpZ25hdHVyZSBlbmNvZGluZyJ9CgogICAgICAgIGlmIG5vdCBzZW5kZXIudmVyaWZ5KG5vbmNlICsgYm9keS5lbmNvZGUoInV0Zi04IiksIHNpZ25hdHVyZSk6CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAic2lnbmF0dXJlIGRvZXMgbm90IHZlcmlmeSJ9CgogICAgICAgIGZwID0gc2VuZGVyLmZpbmdlcnByaW50CiAgICAgICAgc2VsZi5fcmVsb2FkX3BlZXJzX2lmX2NoYW5nZWQoKQogICAgICAgIHdpdGggc2VsZi5sb2NrOgogICAgICAgICAgICBwZWVyID0gc2VsZi5wZWVycy5nZXQoZnApCiAgICAgICAgaWYgcGVlciBpcyBOb25lOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogInNlbmRlciBub3Qgb24gYWxsb3dsaXN0IiwKICAgICAgICAgICAgICAgICAgICAiZmluZ2VycHJpbnQiOiBmcH0KCiAgICAgICAgbWlkID0gdXVpZC51dWlkNCgpLmhleFs6MTJdCiAgICAgICAgcmVjID0geyJpZCI6IG1pZCwgInJlY2VpdmVkIjogdGltZS50aW1lKCksICJmcm9tX2ZpbmdlcnByaW50IjogZnAsCiAgICAgICAgICAgICAgICJmcm9tX2xhYmVsIjogcGVlci5nZXQoImxhYmVsIiwgIiIpLCAiZnJvbV9vbmlvbiI6IHBlZXIuZ2V0KCJvbmlvbiIsICIiKSwKICAgICAgICAgICAgICAgImJvZHkiOiBib2R5fQogICAgICAgIHBhdGggPSBvcy5wYXRoLmpvaW4oSU5CT1gsIGYie3RpbWUudGltZSgpOi4wZn0te21pZH0uanNvbiIpCiAgICAgICAgd2l0aCBvcGVuKHBhdGggKyAiLnRtcCIsICJ3IikgYXMgZjoKICAgICAgICAgICAganNvbi5kdW1wKHJlYywgZiwgaW5kZW50PTIpCiAgICAgICAgb3MucmVwbGFjZShwYXRoICsgIi50bXAiLCBwYXRoKQogICAgICAgIHNlbGYuYWNjZXB0ZWQgKz0gMQogICAgICAgIHByaW50KGYiW2luYm94XSAre21pZH0gZnJvbSB7cGVlci5nZXQoJ2xhYmVsJykgb3IgZnBbOjEyXX0iLCBmbHVzaD1UcnVlKQogICAgICAgIHJldHVybiB7Im9rIjogVHJ1ZSwgImlkIjogbWlkfQoKCmRlZiBjbGllbnRfbG9vcChjb25uLCBib3gpOgogICAgdHJ5OgogICAgICAgIHdoaWxlIFRydWU6CiAgICAgICAgICAgIHJlcSA9IHJlY3ZfbXNnKGNvbm4pCiAgICAgICAgICAgIGlmIHJlcSBpcyBOb25lOgogICAgICAgICAgICAgICAgYnJlYWsKICAgICAgICAgICAgdHJ5OgogICAgICAgICAgICAgICAgcmVwbHkgPSBib3guaGFuZGxlKHJlcSkKICAgICAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbiBhcyBleGM6CiAgICAgICAgICAgICAgICByZXBseSA9IHsib2siOiBGYWxzZSwgImVycm9yIjogZiJoYW5kbGVyOiB7ZXhjfSJ9CiAgICAgICAgICAgIHNlbmRfbXNnKGNvbm4sIHJlcGx5KQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICBwYXNzCiAgICBmaW5hbGx5OgogICAgICAgIHRyeToKICAgICAgICAgICAgY29ubi5jbG9zZSgpCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgcGFzcwoKCmRlZiBzZXJ2ZSgpOgogICAgYm94ID0gSW5ib3goKQogICAgc3J2ID0gc29ja2V0LnNvY2tldChzb2NrZXQuQUZfSU5FVCwgc29ja2V0LlNPQ0tfU1RSRUFNKQogICAgc3J2LnNldHNvY2tvcHQoc29ja2V0LlNPTF9TT0NLRVQsIHNvY2tldC5TT19SRVVTRUFERFIsIDEpCiAgICBzcnYuYmluZCgoIjEyNy4wLjAuMSIsIExJU1RFTl9QT1JUKSkKICAgIHNydi5saXN0ZW4oMTYpCiAgICBwcmludChmImxpc3RlbmluZyAxMjcuMC4wLjE6e0xJU1RFTl9QT1JUfSIsIGZsdXNoPVRydWUpCiAgICBwcmludChmIm9uaW9uICAgICAge2JveC5hZGRyIG9yICcoaGlkZGVuIHNlcnZpY2Ugbm90IGNvbmZpZ3VyZWQgeWV0KSd9IiwgZmx1c2g9VHJ1ZSkKICAgIHByaW50KGYiZmluZ2VycHJpbnQge2JveC5rLnB1YmxpYygpLmZpbmdlcnByaW50fSIsIGZsdXNoPVRydWUpCiAgICBwcmludChmInBlZXJzICAgICAge2xlbihib3gucGVlcnMpfSIsIGZsdXNoPVRydWUpCiAgICB0cnk6CiAgICAgICAgd2hpbGUgVHJ1ZToKICAgICAgICAgICAgY29ubiwgXyA9IHNydi5hY2NlcHQoKQogICAgICAgICAgICB0aHJlYWRpbmcuVGhyZWFkKHRhcmdldD1jbGllbnRfbG9vcCwgYXJncz0oY29ubiwgYm94KSwgZGFlbW9uPVRydWUpLnN0YXJ0KCkKICAgIGV4Y2VwdCBLZXlib2FyZEludGVycnVwdDoKICAgICAgICBwYXNzCiAgICBmaW5hbGx5OgogICAgICAgIHNydi5jbG9zZSgpCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIGNsaWVudCAtLQojIEVzY2FsYXRpbmcgbGFkZGVyOiBmZXRjaGluZyBhIENPTEQgZGVzY3JpcHRvciAoYSBwZWVyIHdob3NlIHRvciBoYXMgb25seSBqdXN0CiMgcHVibGlzaGVkLCBpLmUuIGV2ZXJ5IGJyYW5kLW5ldyB1c2VyJ3MgZmlyc3QgbWVzc2FnZSkgcm91dGluZWx5IHRha2VzIGxvbmdlcgojIHRoYW4gYSBzaW5nbGUgc2hvcnQgdGltZW91dC4gQSBmbGF0IDR4MzBzIGJ1ZGdldCBwcm9kdWNlZCBhIHNwdXJpb3VzCiMgQ29ubmVjdGlvbkVycm9yIG9uIGZpcnN0IGNvbnRhY3QsIHRoZW4gc3VjY2VlZGVkIGluc3RhbnRseSBvbiByZXRyeS4KRElBTF9MQURERVIgPSBbaW50KHgpIGZvciB4IGluCiAgICAgICAgICAgICAgIG9zLmVudmlyb24uZ2V0KCJUT1JBR0VOVFNfRElBTF9MQURERVIiLCAiMzAsNjAsMTIwLDE4MCIpLnNwbGl0KCIsIildCgoKZGVmIGRpYWwodGFyZ2V0X29uaW9uLCB0aW1lb3V0PU5vbmUpOgogICAgIiIiUGxhaW4gU09DS1M1IGRpYWwgdGhyb3VnaCB0aGUgbG9jYWwgdG9yLiBObyB0b3IgQVBJLCBqdXN0IHNvY2tzLiIiIgogICAgaW1wb3J0IHNvY2tzCiAgICBob3N0ID0gdGFyZ2V0X29uaW9uWzotNl0gaWYgdGFyZ2V0X29uaW9uLmVuZHN3aXRoKCIub25pb24iKSBlbHNlIHRhcmdldF9vbmlvbgogICAgbGFzdCA9IE5vbmUKICAgIGZvciBpLCBidWRnZXQgaW4gZW51bWVyYXRlKERJQUxfTEFEREVSKToKICAgICAgICBzID0gc29ja3Muc29ja3NvY2tldCgpCiAgICAgICAgcy5zZXRfcHJveHkoc29ja3MuU09DS1M1LCAiMTI3LjAuMC4xIiwgU09DS1NfUE9SVCwgcmRucz1UcnVlKQogICAgICAgIHMuc2V0dGltZW91dChidWRnZXQpCiAgICAgICAgaWYgaToKICAgICAgICAgICAgcHJpbnQoZiIgIHJldHJ5IHtpfS97bGVuKERJQUxfTEFEREVSKSAtIDF9ICIKICAgICAgICAgICAgICAgICAgZiIod2FpdGluZyB1cCB0byB7YnVkZ2V0fXMgZm9yIHRoZSBkZXNjcmlwdG9yKSIsCiAgICAgICAgICAgICAgICAgIGZpbGU9c3lzLnN0ZGVycikKICAgICAgICB0cnk6CiAgICAgICAgICAgIHMuY29ubmVjdCgoaG9zdCArICIub25pb24iLCA4MCkpCiAgICAgICAgICAgIHJldHVybiBzCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbiBhcyBleGM6CiAgICAgICAgICAgIGxhc3QgPSBleGMKICAgICAgICAgICAgdHJ5OgogICAgICAgICAgICAgICAgcy5jbG9zZSgpCiAgICAgICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgICAgICBwYXNzCiAgICByYWlzZSBDb25uZWN0aW9uRXJyb3IoCiAgICAgICAgZiJjYW5ub3QgcmVhY2gge3RhcmdldF9vbmlvbls6MTZdfS4uLiBhZnRlciB7bGVuKERJQUxfTEFEREVSKX0gYXR0ZW1wdHM6IHtsYXN0fVxuIgogICAgICAgIGYiICBBIHBlZXIgdGhhdCBoYXMgb25seSBqdXN0IGNvbWUgb25saW5lIGNhbiB0YWtlIGEgY291cGxlIG9mIG1pbnV0ZXNcbiIKICAgICAgICBmIiAgdG8gcHVibGlzaCBpdHMgZGVzY3JpcHRvci4gUmV0cnkgaW4gYSBtaW51dGUgYmVmb3JlIGFzc3VtaW5nIGl0IGlzIGRvd24uXG4iCiAgICAgICAgZiIgIENoZWNrIHRoZSBwZWVyIGlzIHJ1bm5pbmcgYW5kIHRvciBpcyB1cCBvbiAxMjcuMC4wLjE6e1NPQ0tTX1BPUlR9LiIpCgoKZGVmIHNlbmRfdG8odGFyZ2V0X29uaW9uLCBib2R5LCBrPU5vbmUpOgogICAgayA9IGsgb3IgbmVlZF9rZXlzKCkgICAgICAgICAgICAgIyBuZXZlciBzaWduIHdpdGggYSBmcmVzaGx5IG1pbnRlZCBrZXkKICAgIHNvY2sgPSBkaWFsKHRhcmdldF9vbmlvbikKICAgIHRyeToKICAgICAgICBzZW5kX21zZyhzb2NrLCB7Im9wIjogImhlbGxvIn0pCiAgICAgICAgaGVsbG8gPSByZWN2X21zZyhzb2NrKQogICAgICAgIGlmIG5vdCBoZWxsbyBvciBub3QgaGVsbG8uZ2V0KCJvayIpOgogICAgICAgICAgICByYWlzZSBSdW50aW1lRXJyb3IoZiJoZWxsbyByZWZ1c2VkOiB7aGVsbG99IikKICAgICAgICBub25jZSA9IGI2NGQoaGVsbG9bIm5vbmNlIl0pCiAgICAgICAgc2VuZF9tc2coc29jaywgeyJvcCI6ICJzZW5kIiwgIm5vbmNlIjogaGVsbG9bIm5vbmNlIl0sICJib2R5IjogYm9keSwKICAgICAgICAgICAgICAgICAgICAgICAgInB1YmtleSI6IGsucHVibGljKCkudG9fZGljdCgpLAogICAgICAgICAgICAgICAgICAgICAgICAic2lnIjogYjY0ZShrLnNpZ24obm9uY2UgKyBib2R5LmVuY29kZSgidXRmLTgiKSkpfSkKICAgICAgICByZXR1cm4gcmVjdl9tc2coc29jaykKICAgIGZpbmFsbHk6CiAgICAgICAgdHJ5OgogICAgICAgICAgICBzb2NrLmNsb3NlKCkKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICBwYXNzCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIGNsaSAtLQpkZWYgY21kX3NlcnZlKGEpOgogICAgc2VydmUoKQoKCmRlZiBjbWRfaW5pdChhKToKICAgIGV4aXN0ZWQgPSBvcy5wYXRoLmV4aXN0cyhJREZJTEUpCiAgICBrID0ga2V5cyhjcmVhdGU9VHJ1ZSkKICAgIHByaW50KGYieydleGlzdGluZycgaWYgZXhpc3RlZCBlbHNlICdjcmVhdGVkJ30gIHtJREZJTEV9IikKICAgIHByaW50KGYiZmluZ2VycHJpbnQgIHtrLnB1YmxpYygpLmZpbmdlcnByaW50fSIpCiAgICBpZiBleGlzdGVkOgogICAgICAgIHByaW50KCJvbmlvbiAgICAgICAgdW5jaGFuZ2VkIChpZGVudGl0eSByZXVzZWQpIikKCgpkZWYgY21kX3dob2FtaShhKToKICAgIGsgPSBrZXlzKCkgICAgICAgICAgICAgICAgICAgICAgIyBuZXZlciBjcmVhdGVzCiAgICBwcmludChmIm9uaW9uICAgICAgICB7b25pb24oKSBvciAnKG5vdCBjb25maWd1cmVkKSd9IikKICAgIGlmIGsgaXMgTm9uZToKICAgICAgICBwcmludChmImZpbmdlcnByaW50ICAobm8gaWRlbnRpdHkgeWV0IC0gcnVuOiBpbmJveF9hZ2VudC5weSBpbml0KSIpCiAgICAgICAgcmFpc2UgU3lzdGVtRXhpdCgyKQogICAgcHJpbnQoZiJmaW5nZXJwcmludCAge2sucHVibGljKCkuZmluZ2VycHJpbnR9IikKCgpkZWYgY21kX2FkZF9wZWVyKGEpOgogICAgcCA9IHBlZXJzKCkKICAgIGZwID0gYS5maW5nZXJwcmludC5zdHJpcCgpLmxvd2VyKCkKICAgIGlmIGxlbihmcCkgIT0gMzI6CiAgICAgICAgc3lzLmV4aXQoZiJmaW5nZXJwcmludCBtdXN0IGJlIDMyIGhleCBjaGFycyAoZ290IHtsZW4oZnApfSkiKQogICAgaWYgbm90IGEub25pb24uZW5kc3dpdGgoIi5vbmlvbiIpOgogICAgICAgIHN5cy5leGl0KCItLW9uaW9uIG11c3QgZW5kIGluIC5vbmlvbiIpCiAgICBwW2ZwXSA9IHsib25pb24iOiBhLm9uaW9uLnN0cmlwKCksICJsYWJlbCI6IGEubGFiZWwgb3IgZnBbOjEyXSwKICAgICAgICAgICAgICJhZGRlZCI6IHRpbWUudGltZSgpfQogICAgc2F2ZV9wZWVycyhwKQogICAgcHJpbnQoZiJhbGxvd2xpc3RlZCB7cFtmcF1bJ2xhYmVsJ119ICh7ZnBbOjEyXX0uLi4pIC0+IHthLm9uaW9ufSIpCgoKZGVmIGNtZF9wZWVycyhhKToKICAgIHAgPSBwZWVycygpCiAgICBpZiBub3QgcDoKICAgICAgICBwcmludCgiKG5vIHBlZXJzIGFsbG93bGlzdGVkKSIpCiAgICBmb3IgZnAsIHYgaW4gc29ydGVkKHAuaXRlbXMoKSwga2V5PWxhbWJkYSBrdjoga3ZbMV0uZ2V0KCJsYWJlbCIsICIiKSk6CiAgICAgICAgcHJpbnQoZiJ7di5nZXQoJ2xhYmVsJywnJyk6MTh9IHtmcFs6MTZdfS4uLiAge3ZbJ29uaW9uJ119IikKCgpkZWYgX21zZ3MoaW5jbHVkZV9hcmNoaXZlZD1GYWxzZSk6CiAgICBvdXQgPSBbXQogICAgZm9yIGQsIGFyY2ggaW4gKChJTkJPWCwgRmFsc2UpLCAoQVJDSElWRSwgVHJ1ZSkpOgogICAgICAgIGlmIG5vdCBvcy5wYXRoLmlzZGlyKGQpOgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIGlmIGFyY2ggYW5kIG5vdCBpbmNsdWRlX2FyY2hpdmVkOgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIGZvciBuIGluIHNvcnRlZChvcy5saXN0ZGlyKGQpKToKICAgICAgICAgICAgaWYgbi5lbmRzd2l0aCgiLmpzb24iKToKICAgICAgICAgICAgICAgIHRyeToKICAgICAgICAgICAgICAgICAgICB3aXRoIG9wZW4ob3MucGF0aC5qb2luKGQsIG4pKSBhcyBmOgogICAgICAgICAgICAgICAgICAgICAgICBtID0ganNvbi5sb2FkKGYpCiAgICAgICAgICAgICAgICAgICAgbVsiX2FyY2hpdmVkIl0gPSBhcmNoCiAgICAgICAgICAgICAgICAgICAgb3V0LmFwcGVuZChtKQogICAgICAgICAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgICAgICAgICBwYXNzCiAgICByZXR1cm4gc29ydGVkKG91dCwga2V5PWxhbWJkYSBtOiBtLmdldCgicmVjZWl2ZWQiLCAwKSkKCgpkZWYgY21kX2luYm94KGEpOgogICAgbXMgPSBfbXNncyhhLmFsbCkKICAgIGlmIG5vdCBtczoKICAgICAgICBwcmludCgiKGluYm94IGVtcHR5KSIpCiAgICBmb3IgbSBpbiBtczoKICAgICAgICB3aGVuID0gdGltZS5zdHJmdGltZSgiJVktJW0tJWQgJUg6JU0iLCB0aW1lLmxvY2FsdGltZShtLmdldCgicmVjZWl2ZWQiLCAwKSkpCiAgICAgICAgcHJpbnQoZiJ7bVsnaWQnXX0gIHt3aGVufSAge20uZ2V0KCdmcm9tX2xhYmVsJywnPycpOjE2fSAiCiAgICAgICAgICAgICAgZiJ7KG0uZ2V0KCdib2R5Jykgb3IgJycpLnJlcGxhY2UoY2hyKDEwKSwnICcpWzo2MF19IikKCgpkZWYgY21kX3JlYWQoYSk6CiAgICBmb3IgbSBpbiBfbXNncyhUcnVlKToKICAgICAgICBpZiBtWyJpZCJdID09IGEuaWQ6CiAgICAgICAgICAgIHByaW50KGpzb24uZHVtcHMobSwgaW5kZW50PTIpKQogICAgICAgICAgICByZXR1cm4KICAgIHN5cy5leGl0KGYibm8gbWVzc2FnZSB7YS5pZH0iKQoKCmRlZiBjbWRfYWNrKGEpOgogICAgZm9yIG4gaW4gKG9zLmxpc3RkaXIoSU5CT1gpIGlmIG9zLnBhdGguaXNkaXIoSU5CT1gpIGVsc2UgW10pOgogICAgICAgIGlmIGEuaWQgaW4gbjoKICAgICAgICAgICAgb3MucmVwbGFjZShvcy5wYXRoLmpvaW4oSU5CT1gsIG4pLCBvcy5wYXRoLmpvaW4oQVJDSElWRSwgbikpCiAgICAgICAgICAgIHByaW50KGYiYXJjaGl2ZWQge2EuaWR9IikKICAgICAgICAgICAgcmV0dXJuCiAgICBzeXMuZXhpdChmIm5vIHVuYXJjaGl2ZWQgbWVzc2FnZSB7YS5pZH0iKQoKCmRlZiBjbWRfc2VuZChhKToKICAgIHAgPSBwZWVycygpCiAgICB0YXJnZXQgPSBOb25lCiAgICBmb3IgZnAsIHYgaW4gcC5pdGVtcygpOgogICAgICAgIGlmIGEudG8gaW4gKGZwLCB2LmdldCgibGFiZWwiKSwgZnBbOjEyXSk6CiAgICAgICAgICAgIHRhcmdldCA9IHYKICAgICAgICAgICAgYnJlYWsKICAgIGlmIHRhcmdldCBpcyBOb25lOgogICAgICAgIHN5cy5leGl0KGYidW5rbm93biBwZWVyIHthLnRvIXJ9OyB0cnk6IGluYm94X2FnZW50LnB5IHBlZXJzIikKICAgIHJlcGx5ID0gc2VuZF90byh0YXJnZXRbIm9uaW9uIl0sIGEuYm9keSkKICAgIHByaW50KGpzb24uZHVtcHMocmVwbHksIGluZGVudD0yKSkKICAgIHN5cy5leGl0KDAgaWYgcmVwbHkgYW5kIHJlcGx5LmdldCgib2siKSBlbHNlIDEpCgoKZGVmIG1haW4oKToKICAgIGFwID0gYXJncGFyc2UuQXJndW1lbnRQYXJzZXIoZGVzY3JpcHRpb249X19kb2NfXywKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZm9ybWF0dGVyX2NsYXNzPWFyZ3BhcnNlLlJhd0Rlc2NyaXB0aW9uSGVscEZvcm1hdHRlcikKICAgIHMgPSBhcC5hZGRfc3VicGFyc2VycyhkZXN0PSJjbWQiLCByZXF1aXJlZD1UcnVlKQogICAgcy5hZGRfcGFyc2VyKCJzZXJ2ZSIpLnNldF9kZWZhdWx0cyhmbj1jbWRfc2VydmUpCiAgICBzLmFkZF9wYXJzZXIoIndob2FtaSIpLnNldF9kZWZhdWx0cyhmbj1jbWRfd2hvYW1pKQogICAgcy5hZGRfcGFyc2VyKCJpbml0Iikuc2V0X2RlZmF1bHRzKGZuPWNtZF9pbml0KQogICAgcy5hZGRfcGFyc2VyKCJwZWVycyIpLnNldF9kZWZhdWx0cyhmbj1jbWRfcGVlcnMpCiAgICBwID0gcy5hZGRfcGFyc2VyKCJhZGQtcGVlciIpCiAgICBwLmFkZF9hcmd1bWVudCgiZmluZ2VycHJpbnQiKQogICAgcC5hZGRfYXJndW1lbnQoIi0tb25pb24iLCByZXF1aXJlZD1UcnVlKQogICAgcC5hZGRfYXJndW1lbnQoIi0tbGFiZWwiLCBkZWZhdWx0PSIiKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX2FkZF9wZWVyKQogICAgcCA9IHMuYWRkX3BhcnNlcigiaW5ib3giKQogICAgcC5hZGRfYXJndW1lbnQoIi0tYWxsIiwgYWN0aW9uPSJzdG9yZV90cnVlIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9pbmJveCkKICAgIHAgPSBzLmFkZF9wYXJzZXIoInJlYWQiKQogICAgcC5hZGRfYXJndW1lbnQoImlkIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9yZWFkKQogICAgcCA9IHMuYWRkX3BhcnNlcigiYWNrIikKICAgIHAuYWRkX2FyZ3VtZW50KCJpZCIpCiAgICBwLnNldF9kZWZhdWx0cyhmbj1jbWRfYWNrKQogICAgcCA9IHMuYWRkX3BhcnNlcigic2VuZCIpCiAgICBwLmFkZF9hcmd1bWVudCgiLS10byIsIHJlcXVpcmVkPVRydWUpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1ib2R5IiwgcmVxdWlyZWQ9VHJ1ZSkKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9zZW5kKQogICAgYSA9IGFwLnBhcnNlX2FyZ3MoKQogICAgYS5mbihhKQoKCmlmIF9fbmFtZV9fID09ICJfX21haW5fXyI6CiAgICBtYWluKCkK'
PAYLOAD_WIRE='IiIid2lyZS5weSAtLSB0aGUgb25seSBjcnlwdG8gdGhlIGluYm94IG5lZWRzLiBQeU5hQ2wsIG5vdGhpbmcgZWxzZS4KCkRlbGliZXJhdGVseSBpZGVudGljYWwgaW4gZm9ybWF0IHRvIHRvcmFnZW50cy5jcnlwdG8gc28gYW4gaWRlbnRpdHkgY3JlYXRlZCBieQplaXRoZXIgaW1wbGVtZW50YXRpb24gaXMgcmVhZGFibGUgYnkgdGhlIG90aGVyOiBzYW1lIHNlZWQvYm94IEpTT04sIHNhbWUKYmxha2UyYih2ZXJpZnl8fGJveCwgMTYpIGZpbmdlcnByaW50LiBQeU5hQ2wgZG9lcyBhbGwgdGhlIHJlYWwgd29yazsgdGhpcyBmaWxlCmp1c3QgbmFtZXMgdGhpbmdzLgoiIiIKaW1wb3J0IGJhc2U2NAoKaW1wb3J0IG5hY2wuaGFzaApmcm9tIG5hY2wuZW5jb2RpbmcgaW1wb3J0IFJhd0VuY29kZXIKZnJvbSBuYWNsLnB1YmxpYyBpbXBvcnQgUHJpdmF0ZUtleSwgUHVibGljS2V5LCBTZWFsZWRCb3gKZnJvbSBuYWNsLnNpZ25pbmcgaW1wb3J0IFNpZ25pbmdLZXksIFZlcmlmeUtleQoKYjY0ZSA9IGxhbWJkYSBiOiBiYXNlNjQuYjY0ZW5jb2RlKGIpLmRlY29kZSgiYXNjaWkiKQpiNjRkID0gbGFtYmRhIHM6IGJhc2U2NC5iNjRkZWNvZGUocykKCgpjbGFzcyBQdWJsaWNJZGVudGl0eToKICAgICIiIlNvbWVvbmUgZWxzZSdzIHB1YmxpYyBoYWxmOiB2ZXJpZnkgdGhlaXIgc2lnbmF0dXJlcywgc2VhbCBib3hlcyB0byB0aGVtLiIiIgoKICAgIGRlZiBfX2luaXRfXyhzZWxmLCB2ZXJpZnlfa2V5OiBieXRlcywgYm94X2tleTogYnl0ZXMpOgogICAgICAgIHNlbGYuX3ZlcmlmeSA9IFZlcmlmeUtleSh2ZXJpZnlfa2V5KQogICAgICAgIHNlbGYuX2JveCA9IFB1YmxpY0tleShib3hfa2V5KQoKICAgIEBwcm9wZXJ0eQogICAgZGVmIHZlcmlmeV9rZXkoc2VsZikgLT4gYnl0ZXM6CiAgICAgICAgcmV0dXJuIGJ5dGVzKHNlbGYuX3ZlcmlmeSkKCiAgICBAcHJvcGVydHkKICAgIGRlZiBib3hfa2V5KHNlbGYpIC0+IGJ5dGVzOgogICAgICAgIHJldHVybiBieXRlcyhzZWxmLl9ib3gpCgogICAgQHByb3BlcnR5CiAgICBkZWYgZmluZ2VycHJpbnQoc2VsZikgLT4gc3RyOgogICAgICAgIHJldHVybiBuYWNsLmhhc2guYmxha2UyYigKICAgICAgICAgICAgc2VsZi52ZXJpZnlfa2V5ICsgc2VsZi5ib3hfa2V5LCBkaWdlc3Rfc2l6ZT0xNiwgZW5jb2Rlcj1SYXdFbmNvZGVyCiAgICAgICAgKS5oZXgoKQoKICAgIGRlZiB2ZXJpZnkoc2VsZiwgbWVzc2FnZTogYnl0ZXMsIHNpZ25hdHVyZTogYnl0ZXMpIC0+IGJvb2w6CiAgICAgICAgdHJ5OgogICAgICAgICAgICBzZWxmLl92ZXJpZnkudmVyaWZ5KG1lc3NhZ2UsIHNpZ25hdHVyZSkKICAgICAgICAgICAgcmV0dXJuIFRydWUKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICByZXR1cm4gRmFsc2UKCiAgICBkZWYgdG9fZGljdChzZWxmKSAtPiBkaWN0OgogICAgICAgIHJldHVybiB7InZlcmlmeSI6IGI2NGUoc2VsZi52ZXJpZnlfa2V5KSwgImJveCI6IGI2NGUoc2VsZi5ib3hfa2V5KX0KCiAgICBAY2xhc3NtZXRob2QKICAgIGRlZiBmcm9tX2RpY3QoY2xzLCBkOiBkaWN0KSAtPiAiUHVibGljSWRlbnRpdHkiOgogICAgICAgIHJldHVybiBjbHMoYjY0ZChkWyJ2ZXJpZnkiXSksIGI2NGQoZFsiYm94Il0pKQoKICAgIGRlZiBfX2VxX18oc2VsZiwgb3RoZXIpOgogICAgICAgIHJldHVybiBpc2luc3RhbmNlKG90aGVyLCBQdWJsaWNJZGVudGl0eSkgYW5kIHNlbGYudG9fZGljdCgpID09IG90aGVyLnRvX2RpY3QoKQoKICAgIGRlZiBfX2hhc2hfXyhzZWxmKToKICAgICAgICByZXR1cm4gaGFzaCgoc2VsZi52ZXJpZnlfa2V5LCBzZWxmLmJveF9rZXkpKQoKCmNsYXNzIEFnZW50S2V5czoKICAgICIiIk91ciBwcml2YXRlIGlkZW50aXR5LiBOZXZlciBsZWF2ZXMgdGhpcyBtYWNoaW5lLiIiIgoKICAgIGRlZiBfX2luaXRfXyhzZWxmLCBzaWduaW5nX2tleTogU2lnbmluZ0tleSwgYm94X2tleTogUHJpdmF0ZUtleSk6CiAgICAgICAgc2VsZi5fc2lnbmluZyA9IHNpZ25pbmdfa2V5CiAgICAgICAgc2VsZi5fYm94ID0gYm94X2tleQoKICAgIEBjbGFzc21ldGhvZAogICAgZGVmIGdlbmVyYXRlKGNscykgLT4gIkFnZW50S2V5cyI6CiAgICAgICAgcmV0dXJuIGNscyhTaWduaW5nS2V5LmdlbmVyYXRlKCksIFByaXZhdGVLZXkuZ2VuZXJhdGUoKSkKCiAgICBkZWYgcHVibGljKHNlbGYpIC0+IFB1YmxpY0lkZW50aXR5OgogICAgICAgIHJldHVybiBQdWJsaWNJZGVudGl0eShieXRlcyhzZWxmLl9zaWduaW5nLnZlcmlmeV9rZXkpLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICBieXRlcyhzZWxmLl9ib3gucHVibGljX2tleSkpCgogICAgZGVmIHNpZ24oc2VsZiwgbWVzc2FnZTogYnl0ZXMpIC0+IGJ5dGVzOgogICAgICAgIHJldHVybiBzZWxmLl9zaWduaW5nLnNpZ24obWVzc2FnZSkuc2lnbmF0dXJlCgogICAgZGVmIHRvX3NlY3JldF9kaWN0KHNlbGYpIC0+IGRpY3Q6CiAgICAgICAgcmV0dXJuIHsic2VlZCI6IGI2NGUoc2VsZi5fc2lnbmluZy5lbmNvZGUoKSksICJib3giOiBiNjRlKGJ5dGVzKHNlbGYuX2JveCkpfQoKICAgIEBjbGFzc21ldGhvZAogICAgZGVmIGZyb21fc2VjcmV0X2RpY3QoY2xzLCBkOiBkaWN0KSAtPiAiQWdlbnRLZXlzIjoKICAgICAgICByZXR1cm4gY2xzKFNpZ25pbmdLZXkoYjY0ZChkWyJzZWVkIl0pKSwgUHJpdmF0ZUtleShiNjRkKGRbImJveCJdKSkpCgogICAgZGVmIHNlYWwoc2VsZiwgcmVjaXBpZW50OiBQdWJsaWNJZGVudGl0eSwgcGxhaW50ZXh0OiBieXRlcykgLT4gYnl0ZXM6CiAgICAgICAgcmV0dXJuIFNlYWxlZEJveChyZWNpcGllbnQuX2JveCkuZW5jcnlwdChwbGFpbnRleHQpCgogICAgZGVmIG9wZW5fc2VhbGVkKHNlbGYsIHNlYWxlZDogYnl0ZXMpIC0+IGJ5dGVzOgogICAgICAgIHJldHVybiBTZWFsZWRCb3goc2VsZi5fYm94KS5kZWNyeXB0KHNlYWxlZCkKCgpkZWYgc2VhbF90byhyZWNpcGllbnQ6IFB1YmxpY0lkZW50aXR5LCBwbGFpbnRleHQ6IGJ5dGVzKSAtPiBieXRlczoKICAgIHJldHVybiBTZWFsZWRCb3gocmVjaXBpZW50Ll9ib3gpLmVuY3J5cHQocGxhaW50ZXh0KQoKCmRlZiBvcGVuX3NlYWxlZChrZXlzOiBBZ2VudEtleXMsIHNlYWxlZDogYnl0ZXMpIC0+IGJ5dGVzOgogICAgcmV0dXJuIFNlYWxlZEJveChrZXlzLl9ib3gpLmRlY3J5cHQoc2VhbGVkKQo='

HOME_DIR="${TORAGENTS_HOME:-$HOME/.toragents}"
PORT="${TORAGENTS_PORT:-8799}"
SOCKS="${TORAGENTS_SOCKS:-9061}"     # NOT 9050: that is a homebrew tor's default
PEER_ONION=""; PEER_FP=""; PEER_LABEL="peer"; DRY=0
NOSVC="${NOSVC:-0}"

while [ $# -gt 0 ]; do
  case "$1" in
    --peer-onion) PEER_ONION="$2"; shift 2 ;;
    --peer-fp)    PEER_FP="$2"; shift 2 ;;
    --peer-label) PEER_LABEL="$2"; shift 2 ;;
    --dry-run)    DRY=1; shift ;;
    --no-service) NOSVC=1; shift ;;  # write units but never install/start them
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

# Portable CPython from python-build-standalone: no package manager, no admin,
# same artifact for every OS/arch. This is what makes python a non-requirement.
PBS_TAG="${TORAGENTS_PBS_TAG:-20261013}"
PBS_VER="${TORAGENTS_PBS_VER:-3.11.17}"

install_portable_python() {
  local trip
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64)   trip=aarch64-apple-darwin ;;
    Darwin-x86_64)  trip=x86_64-apple-darwin ;;
    Linux-x86_64)   trip=x86_64-unknown-linux-gnu ;;
    Linux-aarch64)  trip=aarch64-unknown-linux-gnu ;;
    Linux-arm64)    trip=aarch64-unknown-linux-gnu ;;
    *) return 1 ;;
  esac
  local url="https://github.com/astral-sh/python-build-standalone/releases/download/${PBS_TAG}/cpython-${PBS_VER}+${PBS_TAG}-${trip}-install_only.tar.gz"
  mkdir -p "$HOME_DIR/python"
  curl -fsSL "$url" | tar xz -C "$HOME_DIR/python" --strip-components=1 || return 1
  local c="$HOME_DIR/python/bin/python3"
  [ -x "$c" ] || return 1
  echo "$c"
}

PY="$(find_python python3 /opt/homebrew/bin/python3 /usr/local/bin/python3 || true)"
if [ -z "$PY" ]; then
  say "No system python3 (3.10+) found -- fetching a portable one"
  if [ "$DRY" = 1 ]; then
    warn "dry-run: would download portable cpython $PBS_VER"
    PY=/tmp/portable/python/bin/python3
  else
    PY="$(install_portable_python || true)"
    [ -n "$PY" ] || die "could not fetch portable python for $(uname -s)-$(uname -m).
  Install python3.10+ manually and re-run, or set TORAGENTS_PBS_TAG/VER."
  fi
fi
ok "python: $PY ($("$PY" -c 'import sys;print("%d.%d.%d"%sys.version_info[:3])'))"

# ------------------------------------------------------------------ tor ---
# No Homebrew? tor publishes a self-contained macOS binary ("expert bundle"),
# so a Mac without brew can still run this. Nothing to compile.
TOR_BUNDLE_VER="${TORAGENTS_TOR_BUNDLE:-15.0.25}"
install_tor_expert_bundle() {
  local plat arch url
  # torproject publishes: macos aarch64/x86_64, linux x86_64, windows x86_64.
  # Linux arm64 has no bundle -- it falls back to the package manager.
  case "$(uname -s)" in
    Darwin) plat=macos ;;
    Linux)  plat=linux ;;
    *) return 1 ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) arch=aarch64 ;;
    x86_64|amd64)  arch=x86_64 ;;
    *) return 1 ;;
  esac
  [ "$plat-$arch" = "linux-aarch64" ] && return 1
  url="https://dist.torproject.org/torbrowser/${TOR_BUNDLE_VER}/tor-expert-bundle-${plat}-${arch}-${TOR_BUNDLE_VER}.tar.gz"
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
      warn "no package manager; using the official tor expert bundle"
      TORBIN="$(install_tor_expert_bundle || true)"
      [ -n "$TORBIN" ] || die "no tor and no bundle available for $(uname -s)-$(uname -m).
  Install tor manually and re-run."
    fi
    TORBIN="$(find_tor || true)"
    [ -n "$TORBIN" ] || TORBIN="$HOME_DIR/tor-bin/tor/tor"
    [ -x "$TORBIN" ] || die "tor installed but not found"
  fi
fi
ok "tor: $TORBIN"

# --------------------------------------------------------------- layout ---
mkdir -p "$HOME_DIR"
# state/ is always created: state/config.json is written even in a dry run, and
# a missing parent made that write fail silently in the dry-run path.
mkdir -p "$HOME_DIR/state/inbox" "$HOME_DIR/state/archive"
if [ "$DRY" = 1 ]; then
  say "dry-run: writing files under $HOME_DIR, no services started"
else
  mkdir -p "$HOME_DIR/hs" "$HOME_DIR/tor-data"
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

# The daemon learns its ports from its service unit; the CLI does not. Without
# this record a bare `send` fell back to SOCKS 9050 and failed with
# "Connection refused" even though tor was listening on 9061.
printf '{"local_port": %s, "socks_port": %s}\n' "$PORT" "$SOCKS" > "$HOME_DIR/state/config.json"
ok "state/config.json written (cli uses socks $SOCKS)"

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

# Self-contained: decode the embedded sources. No network, no ref lookup.
SRC_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

decode() { # b64-string, dest
  printf '%s' "$1" | "$PY" -c 'import sys,base64;sys.stdout.buffer.write(base64.b64decode(sys.stdin.read()))' > "$2"
}

if [ -n "$PAYLOAD_INBOX" ] && [ -n "$PAYLOAD_WIRE" ]; then
  decode "$PAYLOAD_INBOX" "$HOME_DIR/inbox_agent.py"
  decode "$PAYLOAD_WIRE"  "$HOME_DIR/wire.py"
  ok "daemon installed (embedded)"
elif [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/inbox_agent.py" ]; then
  cp "$SRC_DIR/inbox_agent.py" "$SRC_DIR/wire.py" "$HOME_DIR/"
  ok "daemon installed (local source tree)"
else
  die "no embedded payload and no local sources. Run: python3 tools/embed.py"
fi

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

  if [ "$DRY" = 0 ] && [ "$NOSVC" = 0 ]; then
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
  if [ "$DRY" = 0 ] && [ "$NOSVC" = 0 ]; then
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

# With --no-service tor is never started, so the hostname file never appears.
# Waiting here was a hang: the install finished and then blocked forever.
if [ "$NOSVC" = 1 ]; then
  say "Supervisors skipped (--no-service)"
  printf '  Start tor, then your onion appears in %s/hs/hostname\n\n' "$HOME_DIR"
  printf '    %s -f %s/torrc &\n' "$TORBIN" "$HOME_DIR"
  printf '    TORAGENTS_HOME=%s %s %s/inbox_agent.py serve &\n\n' "$HOME_DIR" "$VPY" "$HOME_DIR"
  printf '  Your fingerprint:\n'
  printf '    TORAGENTS_HOME=%s %s %s/inbox_agent.py whoami\n\n' "$HOME_DIR" "$VPY" "$HOME_DIR"
  printf '  Re-running this installer later is safe; it never rotates the identity.\n'
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
# init explicitly: whoami is read-only now and must never mint an identity
TORAGENTS_HOME="$HOME_DIR" "$VPY" "$HOME_DIR/inbox_agent.py" init >/dev/null
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
