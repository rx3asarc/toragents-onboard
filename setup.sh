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
PAYLOAD_INBOX='IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwoiIiJpbmJveF9hZ2VudC5weSAtLSBhIHZlcmlmaWVkIG1lc3NhZ2UgaW5ib3ggYmVoaW5kIGEgdG9yIGhpZGRlbiBzZXJ2aWNlLgoKUnVucyBvbiBIRVIgbWFjaGluZS4gTGlzdGVucyBvbiBhIHBsYWluIGxvY2FsaG9zdCBUQ1AgcG9ydDsgdG9yIGZvcndhcmRzIHRoZQpoaWRkZW4gc2VydmljZSB0byBpdC4gU2VydmluZyBuZWVkcyBubyB0b3IgQVBJIGF0IGFsbCAtLSBubyBjb250cm9sIHBvcnQsIG5vCkFERF9PTklPTiwgbm8ga2V5cyB0byBtYW5hZ2UuIE9ubHkgb3V0Ym91bmQgc2VuZHMgdG91Y2ggdG9yLCB2aWEgU09DS1MuCgpTZWN1cml0eSBtb2RlbAogICAgQSBtZXNzYWdlIGlzIGFjY2VwdGVkIG9ubHkgaWYgdGhlIHNlbmRlciBwcm92ZXMgcG9zc2Vzc2lvbiBvZiBhbgogICAgYWxsb3dsaXN0ZWQgRWQyNTUxOSBrZXkgb3ZlciBhIG9uZS11c2Ugbm9uY2UuIFRoZSBzZW5kZXIncyBjbGFpbWVkIG9uaW9uCiAgICBhZGRyZXNzIGlzIG5ldmVyIHRydXN0ZWQgZm9yIHJvdXRpbmcuCgpVc2FnZQogICAgaW5ib3hfYWdlbnQucHkgc2VydmUgICAgICAgICAgICAgICAgIHJ1biB0aGUgZGFlbW9uCiAgICBpbmJveF9hZ2VudC5weSB3aG9hbWkgICAgICAgICAgICAgICAgcHJpbnQgdGhpcyBtYWNoaW5lJ3Mgb25pb24gKyBmaW5nZXJwcmludAogICAgaW5ib3hfYWdlbnQucHkgYWRkLXBlZXIgRlAgLS1vbmlvbiBBIGFsbG93IGEgcGVlciB0byBzZW5kCiAgICBpbmJveF9hZ2VudC5weSBwZWVycwogICAgaW5ib3hfYWdlbnQucHkgaW5ib3gKICAgIGluYm94X2FnZW50LnB5IHJlYWQgPGlkPgogICAgaW5ib3hfYWdlbnQucHkgYWNrIDxpZD4KICAgIGluYm94X2FnZW50LnB5IHNlbmQgLS10byBMQUJFTCAtLWJvZHkgVEVYVAoiIiIKaW1wb3J0IGFyZ3BhcnNlCmltcG9ydCBiYXNlNjQKaW1wb3J0IGpzb24KaW1wb3J0IG9zCmltcG9ydCBzZWNyZXRzCmltcG9ydCBzb2NrZXQKaW1wb3J0IHN5cwppbXBvcnQgdGhyZWFkaW5nCmltcG9ydCB0aW1lCmltcG9ydCB1dWlkCgpmcm9tIHdpcmUgaW1wb3J0IEFnZW50S2V5cywgUHVibGljSWRlbnRpdHkKCkhPTUUgPSBvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX0hPTUUiLCBvcy5wYXRoLmV4cGFuZHVzZXIoIn4vLnRvcmFnZW50cyIpKQpTVEFURSA9IG9zLnBhdGguam9pbihIT01FLCAic3RhdGUiKQpJTkJPWCA9IG9zLnBhdGguam9pbihTVEFURSwgImluYm94IikKQVJDSElWRSA9IG9zLnBhdGguam9pbihTVEFURSwgImFyY2hpdmUiKQpQRUVSUyA9IG9zLnBhdGguam9pbihTVEFURSwgInBlZXJzLmpzb24iKQpJREZJTEUgPSBvcy5wYXRoLmpvaW4oU1RBVEUsICJpZGVudGl0eS5qc29uIikKSE9TVE5BTUVfRklMRSA9IG9zLnBhdGguam9pbihIT01FLCAiaHMiLCAiaG9zdG5hbWUiKQoKQ09ORklHID0gb3MucGF0aC5qb2luKFNUQVRFLCAiY29uZmlnLmpzb24iKQoKCmRlZiBfaW5zdGFsbGVkX2NvbmZpZygpOgogICAgIiIiUmVhZCB0aGUgcG9ydHMgdGhlIGluc3RhbGxlciBhY3R1YWxseSBjb25maWd1cmVkLgoKICAgIFRoaXMgZXhpc3RzIGJlY2F1c2UgdGhlIENMSSBhbmQgdGhlIGRhZW1vbiBtdXN0IGFncmVlIG9uIHRoZSBTT0NLUyBwb3J0IGFuZAogICAgdGhlIGRhZW1vbiBpcyB0aGUgb25seSBvbmUgdGhhdCBnZXRzIFRPUkFHRU5UU19TT0NLUyBmcm9tIGl0cyBzZXJ2aWNlIHVuaXQuCiAgICBUaGUgb2xkIGZhbGxiYWNrIHdhcyA5MDUwIHdoaWxlIHRoZSBpbnN0YWxsZXIgd3JpdGVzIDkwNjEsIHNvIGV2ZXJ5IGJhcmUKICAgIGBzZW5kYC9gaW5ib3hgIGRpZWQgd2l0aCAiQ29ubmVjdGlvbiByZWZ1c2VkIiB1bnRpbCB0aGUgdXNlciBleHBvcnRlZCB0aGUKICAgIHZhcmlhYmxlIGJ5IGhhbmQuIEVudiBzdGlsbCB3aW5zOyB0aGUgcmVjb3JkZWQgY29uZmlnIGlzIHRoZSBmYWxsYmFjay4KICAgICIiIgogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihDT05GSUcpIGFzIGY6CiAgICAgICAgICAgIHJldHVybiBqc29uLmxvYWQoZikKICAgIGV4Y2VwdCAoT1NFcnJvciwgVmFsdWVFcnJvcik6CiAgICAgICAgcmV0dXJuIHt9CgoKX2NmZyA9IF9pbnN0YWxsZWRfY29uZmlnKCkKTElTVEVOX1BPUlQgPSBpbnQob3MuZW52aXJvbi5nZXQoIlRPUkFHRU5UU19QT1JUIikgb3IgX2NmZy5nZXQoImxvY2FsX3BvcnQiKSBvciA4Nzk5KQpTT0NLU19QT1JUID0gaW50KG9zLmVudmlyb24uZ2V0KCJUT1JBR0VOVFNfU09DS1MiKSBvciBfY2ZnLmdldCgic29ja3NfcG9ydCIpIG9yIDkwNTApCk5PTkNFX1RUTCA9IDE4MC4wCgpiNjRlID0gbGFtYmRhIGI6IGJhc2U2NC5iNjRlbmNvZGUoYikuZGVjb2RlKCJhc2NpaSIpCmI2NGQgPSBsYW1iZGEgczogYmFzZTY0LmI2NGRlY29kZShzKQoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBzdGF0ZSAtLS0KZGVmIGRpcnMoKToKICAgIGZvciBkIGluIChTVEFURSwgSU5CT1gsIEFSQ0hJVkUpOgogICAgICAgIG9zLm1ha2VkaXJzKGQsIGV4aXN0X29rPVRydWUpCgoKZGVmIGtleXMoKToKICAgIGRpcnMoKQogICAgaWYgb3MucGF0aC5leGlzdHMoSURGSUxFKToKICAgICAgICB3aXRoIG9wZW4oSURGSUxFKSBhcyBmOgogICAgICAgICAgICByZXR1cm4gQWdlbnRLZXlzLmZyb21fc2VjcmV0X2RpY3QoanNvbi5sb2FkKGYpKQogICAgayA9IEFnZW50S2V5cy5nZW5lcmF0ZSgpCiAgICBmZCA9IG9zLm9wZW4oSURGSUxFLCBvcy5PX1dST05MWSB8IG9zLk9fQ1JFQVQgfCBvcy5PX1RSVU5DLCAwbzYwMCkKICAgIHdpdGggb3MuZmRvcGVuKGZkLCAidyIpIGFzIGY6CiAgICAgICAganNvbi5kdW1wKGsudG9fc2VjcmV0X2RpY3QoKSwgZikKICAgIHJldHVybiBrCgoKZGVmIHBlZXJzKCk6CiAgICBpZiBub3Qgb3MucGF0aC5leGlzdHMoUEVFUlMpOgogICAgICAgIHJldHVybiB7fQogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihQRUVSUykgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIGpzb24ubG9hZChmKQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICByZXR1cm4ge30KCgpkZWYgc2F2ZV9wZWVycyhwKToKICAgIGRpcnMoKQogICAgdG1wID0gUEVFUlMgKyAiLnRtcCIKICAgIHdpdGggb3Blbih0bXAsICJ3IikgYXMgZjoKICAgICAgICBqc29uLmR1bXAocCwgZiwgaW5kZW50PTIsIHNvcnRfa2V5cz1UcnVlKQogICAgb3MucmVwbGFjZSh0bXAsIFBFRVJTKQoKCmRlZiBvbmlvbigpOgogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihIT1NUTkFNRV9GSUxFKSBhcyBmOgogICAgICAgICAgICByZXR1cm4gZi5yZWFkKCkuc3RyaXAoKQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICByZXR1cm4gTm9uZQoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIGZyYW1pbmcgLS0KZGVmIHNlbmRfbXNnKHNvY2ssIG9iaik6CiAgICBkYXRhID0ganNvbi5kdW1wcyhvYmopLmVuY29kZSgpCiAgICBzb2NrLnNlbmRhbGwobGVuKGRhdGEpLnRvX2J5dGVzKDQsICJiaWciKSArIGRhdGEpCgoKTUFYX0ZSQU1FID0gMTYgKiAxMDI0ICogMTAyNCAgIyBzYW1lIGNlaWxpbmcgdG9yYWdlbnRzIHVzZXM7IHN0b3BzIGEgaG9zdGlsZSBoZWFkZXIKCgpkZWYgcmVjdl9tc2coc29jayk6CiAgICBoZHIgPSBfcmVhZF9leGFjdChzb2NrLCA0KQogICAgaWYgaGRyIGlzIE5vbmU6CiAgICAgICAgcmV0dXJuIE5vbmUKICAgIG4gPSBpbnQuZnJvbV9ieXRlcyhoZHIsICJiaWciKQogICAgaWYgbiA+IE1BWF9GUkFNRToKICAgICAgICByYWlzZSBWYWx1ZUVycm9yKGYiZGVjbGFyZWQgZnJhbWUge259IGV4Y2VlZHMge01BWF9GUkFNRX0iKQogICAgYm9keSA9IF9yZWFkX2V4YWN0KHNvY2ssIG4pCiAgICBpZiBib2R5IGlzIE5vbmU6CiAgICAgICAgcmV0dXJuIE5vbmUKICAgIHJldHVybiBqc29uLmxvYWRzKGJvZHkuZGVjb2RlKCkpCgoKZGVmIF9yZWFkX2V4YWN0KHNvY2ssIG4pOgogICAgYnVmID0gYiIiCiAgICB3aGlsZSBsZW4oYnVmKSA8IG46CiAgICAgICAgY2h1bmsgPSBzb2NrLnJlY3YobiAtIGxlbihidWYpKQogICAgICAgIGlmIG5vdCBjaHVuazoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKICAgICAgICBidWYgKz0gY2h1bmsKICAgIHJldHVybiBidWYKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gbm9uY2VzIC0tCmNsYXNzIE5vbmNlczoKICAgIGRlZiBfX2luaXRfXyhzZWxmKToKICAgICAgICBzZWxmLl9kLCBzZWxmLl9sb2NrID0ge30sIHRocmVhZGluZy5Mb2NrKCkKCiAgICBkZWYgaXNzdWUoc2VsZik6CiAgICAgICAgbiA9IHNlY3JldHMudG9rZW5fYnl0ZXMoMzIpCiAgICAgICAgd2l0aCBzZWxmLl9sb2NrOgogICAgICAgICAgICBub3cgPSB0aW1lLnRpbWUoKQogICAgICAgICAgICBzZWxmLl9kID0ge2s6IHYgZm9yIGssIHYgaW4gc2VsZi5fZC5pdGVtcygpIGlmIHYgPiBub3d9CiAgICAgICAgICAgIHNlbGYuX2RbYjY0ZShuKV0gPSBub3cgKyBOT05DRV9UVEwKICAgICAgICByZXR1cm4gbgoKICAgIGRlZiBjb25zdW1lKHNlbGYsIHRva2VuKToKICAgICAgICB3aXRoIHNlbGYuX2xvY2s6CiAgICAgICAgICAgIGV4cCA9IHNlbGYuX2QucG9wKHRva2VuLCBOb25lKQogICAgICAgIGlmIGV4cCBpcyBOb25lIG9yIGV4cCA8IHRpbWUudGltZSgpOgogICAgICAgICAgICByZXR1cm4gTm9uZQogICAgICAgIHRyeToKICAgICAgICAgICAgcmV0dXJuIGI2NGQodG9rZW4pCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gc2VydmVyIC0tCmNsYXNzIEluYm94OgogICAgZGVmIF9faW5pdF9fKHNlbGYpOgogICAgICAgIHNlbGYuayA9IGtleXMoKQogICAgICAgIHNlbGYubm9uY2VzID0gTm9uY2VzKCkKICAgICAgICBzZWxmLnBlZXJzID0gcGVlcnMoKQogICAgICAgIHNlbGYubG9jayA9IHRocmVhZGluZy5Mb2NrKCkKICAgICAgICBzZWxmLmFjY2VwdGVkID0gc2VsZi5yZWplY3RlZCA9IDAKICAgICAgICBzZWxmLmFkZHIgPSBvbmlvbigpCiAgICAgICAgc2VsZi5fcGVlcnNfbXRpbWUgPSBzZWxmLl9tdGltZSgpCgogICAgZGVmIF9tdGltZShzZWxmKToKICAgICAgICB0cnk6CiAgICAgICAgICAgIHJldHVybiBvcy5wYXRoLmdldG10aW1lKFBFRVJTKQogICAgICAgIGV4Y2VwdCBPU0Vycm9yOgogICAgICAgICAgICByZXR1cm4gTm9uZQoKICAgIGRlZiBfcmVsb2FkX3BlZXJzX2lmX2NoYW5nZWQoc2VsZik6CiAgICAgICAgIiIiUGljayB1cCBgYWRkLXBlZXJgIHdpdGhvdXQgcmVzdGFydGluZyB0aGUgZGFlbW9uLiIiIgogICAgICAgIG5vdyA9IHNlbGYuX210aW1lKCkKICAgICAgICBpZiBub3cgIT0gc2VsZi5fcGVlcnNfbXRpbWU6CiAgICAgICAgICAgIHdpdGggc2VsZi5sb2NrOgogICAgICAgICAgICAgICAgc2VsZi5wZWVycyA9IHBlZXJzKCkKICAgICAgICAgICAgICAgIHNlbGYuX3BlZXJzX210aW1lID0gbm93CiAgICAgICAgICAgIHByaW50KGYiW2luYm94XSBwZWVyIGxpc3QgcmVsb2FkZWQgKHtsZW4oc2VsZi5wZWVycyl9IGFsbG93ZWQpIiwgZmx1c2g9VHJ1ZSkKCiAgICBkZWYgaGFuZGxlKHNlbGYsIHJlcSk6CiAgICAgICAgb3AgPSByZXEuZ2V0KCJvcCIpCiAgICAgICAgaWYgb3AgPT0gInBpbmciOgogICAgICAgICAgICByZXR1cm4geyJvayI6IFRydWUsICJzZXJ2aWNlIjogInRvcmFnZW50cy1pbmJveCIsICJvbmlvbiI6IHNlbGYuYWRkciwKICAgICAgICAgICAgICAgICAgICAiZmluZ2VycHJpbnQiOiBzZWxmLmsucHVibGljKCkuZmluZ2VycHJpbnR9CiAgICAgICAgaWYgb3AgPT0gImhlbGxvIjoKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBUcnVlLCAibm9uY2UiOiBiNjRlKHNlbGYubm9uY2VzLmlzc3VlKCkpfQogICAgICAgIGlmIG9wID09ICJzZW5kIjoKICAgICAgICAgICAgcmV0dXJuIHNlbGYuX2FjY2VwdChyZXEpCiAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogZiJ1bmtub3duIG9wIHtvcCFyfSJ9CgogICAgZGVmIF9hY2NlcHQoc2VsZiwgcmVxKToKICAgICAgICB0b2tlbiwgYm9keSwgcHViLCBzaWcgPSAocmVxLmdldCgibm9uY2UiKSwgcmVxLmdldCgiYm9keSIpLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICByZXEuZ2V0KCJwdWJrZXkiKSwgcmVxLmdldCgic2lnIikpCiAgICAgICAgaWYgbm90IGFsbChbdG9rZW4sIGlzaW5zdGFuY2UoYm9keSwgc3RyKSwgcHViLCBzaWddKToKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJtYWxmb3JtZWQgc2VuZCJ9CgogICAgICAgIG5vbmNlID0gc2VsZi5ub25jZXMuY29uc3VtZSh0b2tlbikKICAgICAgICBpZiBub25jZSBpcyBOb25lOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogInN0YWxlIG9yIHVua25vd24gbm9uY2UifQoKICAgICAgICB0cnk6CiAgICAgICAgICAgIHNlbmRlciA9IFB1YmxpY0lkZW50aXR5LmZyb21fZGljdChwdWIpCiAgICAgICAgICAgIHNpZ25hdHVyZSA9IGI2NGQoc2lnKQogICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAiYmFkIHB1YmtleSBvciBzaWduYXR1cmUgZW5jb2RpbmcifQoKICAgICAgICBpZiBub3Qgc2VuZGVyLnZlcmlmeShub25jZSArIGJvZHkuZW5jb2RlKCJ1dGYtOCIpLCBzaWduYXR1cmUpOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogInNpZ25hdHVyZSBkb2VzIG5vdCB2ZXJpZnkifQoKICAgICAgICBmcCA9IHNlbmRlci5maW5nZXJwcmludAogICAgICAgIHNlbGYuX3JlbG9hZF9wZWVyc19pZl9jaGFuZ2VkKCkKICAgICAgICB3aXRoIHNlbGYubG9jazoKICAgICAgICAgICAgcGVlciA9IHNlbGYucGVlcnMuZ2V0KGZwKQogICAgICAgIGlmIHBlZXIgaXMgTm9uZToKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJzZW5kZXIgbm90IG9uIGFsbG93bGlzdCIsCiAgICAgICAgICAgICAgICAgICAgImZpbmdlcnByaW50IjogZnB9CgogICAgICAgIG1pZCA9IHV1aWQudXVpZDQoKS5oZXhbOjEyXQogICAgICAgIHJlYyA9IHsiaWQiOiBtaWQsICJyZWNlaXZlZCI6IHRpbWUudGltZSgpLCAiZnJvbV9maW5nZXJwcmludCI6IGZwLAogICAgICAgICAgICAgICAiZnJvbV9sYWJlbCI6IHBlZXIuZ2V0KCJsYWJlbCIsICIiKSwgImZyb21fb25pb24iOiBwZWVyLmdldCgib25pb24iLCAiIiksCiAgICAgICAgICAgICAgICJib2R5IjogYm9keX0KICAgICAgICBwYXRoID0gb3MucGF0aC5qb2luKElOQk9YLCBmInt0aW1lLnRpbWUoKTouMGZ9LXttaWR9Lmpzb24iKQogICAgICAgIHdpdGggb3BlbihwYXRoICsgIi50bXAiLCAidyIpIGFzIGY6CiAgICAgICAgICAgIGpzb24uZHVtcChyZWMsIGYsIGluZGVudD0yKQogICAgICAgIG9zLnJlcGxhY2UocGF0aCArICIudG1wIiwgcGF0aCkKICAgICAgICBzZWxmLmFjY2VwdGVkICs9IDEKICAgICAgICBwcmludChmIltpbmJveF0gK3ttaWR9IGZyb20ge3BlZXIuZ2V0KCdsYWJlbCcpIG9yIGZwWzoxMl19IiwgZmx1c2g9VHJ1ZSkKICAgICAgICByZXR1cm4geyJvayI6IFRydWUsICJpZCI6IG1pZH0KCgpkZWYgY2xpZW50X2xvb3AoY29ubiwgYm94KToKICAgIHRyeToKICAgICAgICB3aGlsZSBUcnVlOgogICAgICAgICAgICByZXEgPSByZWN2X21zZyhjb25uKQogICAgICAgICAgICBpZiByZXEgaXMgTm9uZToKICAgICAgICAgICAgICAgIGJyZWFrCiAgICAgICAgICAgIHRyeToKICAgICAgICAgICAgICAgIHJlcGx5ID0gYm94LmhhbmRsZShyZXEpCiAgICAgICAgICAgIGV4Y2VwdCBFeGNlcHRpb24gYXMgZXhjOgogICAgICAgICAgICAgICAgcmVwbHkgPSB7Im9rIjogRmFsc2UsICJlcnJvciI6IGYiaGFuZGxlcjoge2V4Y30ifQogICAgICAgICAgICBzZW5kX21zZyhjb25uLCByZXBseSkKICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgcGFzcwogICAgZmluYWxseToKICAgICAgICB0cnk6CiAgICAgICAgICAgIGNvbm4uY2xvc2UoKQogICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgIHBhc3MKCgpkZWYgc2VydmUoKToKICAgIGJveCA9IEluYm94KCkKICAgIHNydiA9IHNvY2tldC5zb2NrZXQoc29ja2V0LkFGX0lORVQsIHNvY2tldC5TT0NLX1NUUkVBTSkKICAgIHNydi5zZXRzb2Nrb3B0KHNvY2tldC5TT0xfU09DS0VULCBzb2NrZXQuU09fUkVVU0VBRERSLCAxKQogICAgc3J2LmJpbmQoKCIxMjcuMC4wLjEiLCBMSVNURU5fUE9SVCkpCiAgICBzcnYubGlzdGVuKDE2KQogICAgcHJpbnQoZiJsaXN0ZW5pbmcgMTI3LjAuMC4xOntMSVNURU5fUE9SVH0iLCBmbHVzaD1UcnVlKQogICAgcHJpbnQoZiJvbmlvbiAgICAgIHtib3guYWRkciBvciAnKGhpZGRlbiBzZXJ2aWNlIG5vdCBjb25maWd1cmVkIHlldCknfSIsIGZsdXNoPVRydWUpCiAgICBwcmludChmImZpbmdlcnByaW50IHtib3guay5wdWJsaWMoKS5maW5nZXJwcmludH0iLCBmbHVzaD1UcnVlKQogICAgcHJpbnQoZiJwZWVycyAgICAgIHtsZW4oYm94LnBlZXJzKX0iLCBmbHVzaD1UcnVlKQogICAgdHJ5OgogICAgICAgIHdoaWxlIFRydWU6CiAgICAgICAgICAgIGNvbm4sIF8gPSBzcnYuYWNjZXB0KCkKICAgICAgICAgICAgdGhyZWFkaW5nLlRocmVhZCh0YXJnZXQ9Y2xpZW50X2xvb3AsIGFyZ3M9KGNvbm4sIGJveCksIGRhZW1vbj1UcnVlKS5zdGFydCgpCiAgICBleGNlcHQgS2V5Ym9hcmRJbnRlcnJ1cHQ6CiAgICAgICAgcGFzcwogICAgZmluYWxseToKICAgICAgICBzcnYuY2xvc2UoKQoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBjbGllbnQgLS0KZGVmIGRpYWwodGFyZ2V0X29uaW9uLCB0aW1lb3V0PTEyMCk6CiAgICAiIiJQbGFpbiBTT0NLUzUgZGlhbCB0aHJvdWdoIHRoZSBsb2NhbCB0b3IuIE5vIHRvciBBUEksIGp1c3Qgc29ja3MuIiIiCiAgICBpbXBvcnQgc29ja3MKICAgIGhvc3QgPSB0YXJnZXRfb25pb25bOi02XSBpZiB0YXJnZXRfb25pb24uZW5kc3dpdGgoIi5vbmlvbiIpIGVsc2UgdGFyZ2V0X29uaW9uCiAgICBsYXN0ID0gTm9uZQogICAgZm9yIGF0dGVtcHQgaW4gcmFuZ2UoNCk6CiAgICAgICAgcyA9IHNvY2tzLnNvY2tzb2NrZXQoKQogICAgICAgIHMuc2V0X3Byb3h5KHNvY2tzLlNPQ0tTNSwgIjEyNy4wLjAuMSIsIFNPQ0tTX1BPUlQsIHJkbnM9VHJ1ZSkKICAgICAgICBzLnNldHRpbWVvdXQobWF4KHRpbWVvdXQgLyA0LCAyMCkpCiAgICAgICAgdHJ5OgogICAgICAgICAgICBzLmNvbm5lY3QoKGhvc3QgKyAiLm9uaW9uIiwgODApKQogICAgICAgICAgICByZXR1cm4gcwogICAgICAgIGV4Y2VwdCBFeGNlcHRpb24gYXMgZXhjOgogICAgICAgICAgICBsYXN0ID0gZXhjCiAgICAgICAgICAgIHRyeToKICAgICAgICAgICAgICAgIHMuY2xvc2UoKQogICAgICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICAgICAgcGFzcwogICAgICAgICAgICB0aW1lLnNsZWVwKDIpCiAgICByYWlzZSBDb25uZWN0aW9uRXJyb3IoZiJjYW5ub3QgcmVhY2gge3RhcmdldF9vbmlvbls6MTZdfS4uLjoge2xhc3R9IikKCgpkZWYgc2VuZF90byh0YXJnZXRfb25pb24sIGJvZHksIGs9Tm9uZSk6CiAgICBrID0gayBvciBrZXlzKCkKICAgIHNvY2sgPSBkaWFsKHRhcmdldF9vbmlvbikKICAgIHRyeToKICAgICAgICBzZW5kX21zZyhzb2NrLCB7Im9wIjogImhlbGxvIn0pCiAgICAgICAgaGVsbG8gPSByZWN2X21zZyhzb2NrKQogICAgICAgIGlmIG5vdCBoZWxsbyBvciBub3QgaGVsbG8uZ2V0KCJvayIpOgogICAgICAgICAgICByYWlzZSBSdW50aW1lRXJyb3IoZiJoZWxsbyByZWZ1c2VkOiB7aGVsbG99IikKICAgICAgICBub25jZSA9IGI2NGQoaGVsbG9bIm5vbmNlIl0pCiAgICAgICAgc2VuZF9tc2coc29jaywgeyJvcCI6ICJzZW5kIiwgIm5vbmNlIjogaGVsbG9bIm5vbmNlIl0sICJib2R5IjogYm9keSwKICAgICAgICAgICAgICAgICAgICAgICAgInB1YmtleSI6IGsucHVibGljKCkudG9fZGljdCgpLAogICAgICAgICAgICAgICAgICAgICAgICAic2lnIjogYjY0ZShrLnNpZ24obm9uY2UgKyBib2R5LmVuY29kZSgidXRmLTgiKSkpfSkKICAgICAgICByZXR1cm4gcmVjdl9tc2coc29jaykKICAgIGZpbmFsbHk6CiAgICAgICAgdHJ5OgogICAgICAgICAgICBzb2NrLmNsb3NlKCkKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICBwYXNzCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIGNsaSAtLQpkZWYgY21kX3NlcnZlKGEpOgogICAgc2VydmUoKQoKCmRlZiBjbWRfd2hvYW1pKGEpOgogICAgayA9IGtleXMoKQogICAgcHJpbnQoZiJvbmlvbiAgICAgICAge29uaW9uKCkgb3IgJyhub3QgY29uZmlndXJlZCknfSIpCiAgICBwcmludChmImZpbmdlcnByaW50ICB7ay5wdWJsaWMoKS5maW5nZXJwcmludH0iKQoKCmRlZiBjbWRfYWRkX3BlZXIoYSk6CiAgICBwID0gcGVlcnMoKQogICAgZnAgPSBhLmZpbmdlcnByaW50LnN0cmlwKCkubG93ZXIoKQogICAgaWYgbGVuKGZwKSAhPSAzMjoKICAgICAgICBzeXMuZXhpdChmImZpbmdlcnByaW50IG11c3QgYmUgMzIgaGV4IGNoYXJzIChnb3Qge2xlbihmcCl9KSIpCiAgICBpZiBub3QgYS5vbmlvbi5lbmRzd2l0aCgiLm9uaW9uIik6CiAgICAgICAgc3lzLmV4aXQoIi0tb25pb24gbXVzdCBlbmQgaW4gLm9uaW9uIikKICAgIHBbZnBdID0geyJvbmlvbiI6IGEub25pb24uc3RyaXAoKSwgImxhYmVsIjogYS5sYWJlbCBvciBmcFs6MTJdLAogICAgICAgICAgICAgImFkZGVkIjogdGltZS50aW1lKCl9CiAgICBzYXZlX3BlZXJzKHApCiAgICBwcmludChmImFsbG93bGlzdGVkIHtwW2ZwXVsnbGFiZWwnXX0gKHtmcFs6MTJdfS4uLikgLT4ge2Eub25pb259IikKCgpkZWYgY21kX3BlZXJzKGEpOgogICAgcCA9IHBlZXJzKCkKICAgIGlmIG5vdCBwOgogICAgICAgIHByaW50KCIobm8gcGVlcnMgYWxsb3dsaXN0ZWQpIikKICAgIGZvciBmcCwgdiBpbiBzb3J0ZWQocC5pdGVtcygpLCBrZXk9bGFtYmRhIGt2OiBrdlsxXS5nZXQoImxhYmVsIiwgIiIpKToKICAgICAgICBwcmludChmInt2LmdldCgnbGFiZWwnLCcnKToxOH0ge2ZwWzoxNl19Li4uICB7dlsnb25pb24nXX0iKQoKCmRlZiBfbXNncyhpbmNsdWRlX2FyY2hpdmVkPUZhbHNlKToKICAgIG91dCA9IFtdCiAgICBmb3IgZCwgYXJjaCBpbiAoKElOQk9YLCBGYWxzZSksIChBUkNISVZFLCBUcnVlKSk6CiAgICAgICAgaWYgbm90IG9zLnBhdGguaXNkaXIoZCk6CiAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgaWYgYXJjaCBhbmQgbm90IGluY2x1ZGVfYXJjaGl2ZWQ6CiAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgZm9yIG4gaW4gc29ydGVkKG9zLmxpc3RkaXIoZCkpOgogICAgICAgICAgICBpZiBuLmVuZHN3aXRoKCIuanNvbiIpOgogICAgICAgICAgICAgICAgdHJ5OgogICAgICAgICAgICAgICAgICAgIHdpdGggb3Blbihvcy5wYXRoLmpvaW4oZCwgbikpIGFzIGY6CiAgICAgICAgICAgICAgICAgICAgICAgIG0gPSBqc29uLmxvYWQoZikKICAgICAgICAgICAgICAgICAgICBtWyJfYXJjaGl2ZWQiXSA9IGFyY2gKICAgICAgICAgICAgICAgICAgICBvdXQuYXBwZW5kKG0pCiAgICAgICAgICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICAgICAgICAgIHBhc3MKICAgIHJldHVybiBzb3J0ZWQob3V0LCBrZXk9bGFtYmRhIG06IG0uZ2V0KCJyZWNlaXZlZCIsIDApKQoKCmRlZiBjbWRfaW5ib3goYSk6CiAgICBtcyA9IF9tc2dzKGEuYWxsKQogICAgaWYgbm90IG1zOgogICAgICAgIHByaW50KCIoaW5ib3ggZW1wdHkpIikKICAgIGZvciBtIGluIG1zOgogICAgICAgIHdoZW4gPSB0aW1lLnN0cmZ0aW1lKCIlWS0lbS0lZCAlSDolTSIsIHRpbWUubG9jYWx0aW1lKG0uZ2V0KCJyZWNlaXZlZCIsIDApKSkKICAgICAgICBwcmludChmInttWydpZCddfSAge3doZW59ICB7bS5nZXQoJ2Zyb21fbGFiZWwnLCc/Jyk6MTZ9ICIKICAgICAgICAgICAgICBmInsobS5nZXQoJ2JvZHknKSBvciAnJykucmVwbGFjZShjaHIoMTApLCcgJylbOjYwXX0iKQoKCmRlZiBjbWRfcmVhZChhKToKICAgIGZvciBtIGluIF9tc2dzKFRydWUpOgogICAgICAgIGlmIG1bImlkIl0gPT0gYS5pZDoKICAgICAgICAgICAgcHJpbnQoanNvbi5kdW1wcyhtLCBpbmRlbnQ9MikpCiAgICAgICAgICAgIHJldHVybgogICAgc3lzLmV4aXQoZiJubyBtZXNzYWdlIHthLmlkfSIpCgoKZGVmIGNtZF9hY2soYSk6CiAgICBmb3IgbiBpbiAob3MubGlzdGRpcihJTkJPWCkgaWYgb3MucGF0aC5pc2RpcihJTkJPWCkgZWxzZSBbXSk6CiAgICAgICAgaWYgYS5pZCBpbiBuOgogICAgICAgICAgICBvcy5yZXBsYWNlKG9zLnBhdGguam9pbihJTkJPWCwgbiksIG9zLnBhdGguam9pbihBUkNISVZFLCBuKSkKICAgICAgICAgICAgcHJpbnQoZiJhcmNoaXZlZCB7YS5pZH0iKQogICAgICAgICAgICByZXR1cm4KICAgIHN5cy5leGl0KGYibm8gdW5hcmNoaXZlZCBtZXNzYWdlIHthLmlkfSIpCgoKZGVmIGNtZF9zZW5kKGEpOgogICAgcCA9IHBlZXJzKCkKICAgIHRhcmdldCA9IE5vbmUKICAgIGZvciBmcCwgdiBpbiBwLml0ZW1zKCk6CiAgICAgICAgaWYgYS50byBpbiAoZnAsIHYuZ2V0KCJsYWJlbCIpLCBmcFs6MTJdKToKICAgICAgICAgICAgdGFyZ2V0ID0gdgogICAgICAgICAgICBicmVhawogICAgaWYgdGFyZ2V0IGlzIE5vbmU6CiAgICAgICAgc3lzLmV4aXQoZiJ1bmtub3duIHBlZXIge2EudG8hcn07IHRyeTogaW5ib3hfYWdlbnQucHkgcGVlcnMiKQogICAgcmVwbHkgPSBzZW5kX3RvKHRhcmdldFsib25pb24iXSwgYS5ib2R5KQogICAgcHJpbnQoanNvbi5kdW1wcyhyZXBseSwgaW5kZW50PTIpKQogICAgc3lzLmV4aXQoMCBpZiByZXBseSBhbmQgcmVwbHkuZ2V0KCJvayIpIGVsc2UgMSkKCgpkZWYgbWFpbigpOgogICAgYXAgPSBhcmdwYXJzZS5Bcmd1bWVudFBhcnNlcihkZXNjcmlwdGlvbj1fX2RvY19fLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBmb3JtYXR0ZXJfY2xhc3M9YXJncGFyc2UuUmF3RGVzY3JpcHRpb25IZWxwRm9ybWF0dGVyKQogICAgcyA9IGFwLmFkZF9zdWJwYXJzZXJzKGRlc3Q9ImNtZCIsIHJlcXVpcmVkPVRydWUpCiAgICBzLmFkZF9wYXJzZXIoInNlcnZlIikuc2V0X2RlZmF1bHRzKGZuPWNtZF9zZXJ2ZSkKICAgIHMuYWRkX3BhcnNlcigid2hvYW1pIikuc2V0X2RlZmF1bHRzKGZuPWNtZF93aG9hbWkpCiAgICBzLmFkZF9wYXJzZXIoInBlZXJzIikuc2V0X2RlZmF1bHRzKGZuPWNtZF9wZWVycykKICAgIHAgPSBzLmFkZF9wYXJzZXIoImFkZC1wZWVyIikKICAgIHAuYWRkX2FyZ3VtZW50KCJmaW5nZXJwcmludCIpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1vbmlvbiIsIHJlcXVpcmVkPVRydWUpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1sYWJlbCIsIGRlZmF1bHQ9IiIpCiAgICBwLnNldF9kZWZhdWx0cyhmbj1jbWRfYWRkX3BlZXIpCiAgICBwID0gcy5hZGRfcGFyc2VyKCJpbmJveCIpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1hbGwiLCBhY3Rpb249InN0b3JlX3RydWUiKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX2luYm94KQogICAgcCA9IHMuYWRkX3BhcnNlcigicmVhZCIpCiAgICBwLmFkZF9hcmd1bWVudCgiaWQiKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX3JlYWQpCiAgICBwID0gcy5hZGRfcGFyc2VyKCJhY2siKQogICAgcC5hZGRfYXJndW1lbnQoImlkIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9hY2spCiAgICBwID0gcy5hZGRfcGFyc2VyKCJzZW5kIikKICAgIHAuYWRkX2FyZ3VtZW50KCItLXRvIiwgcmVxdWlyZWQ9VHJ1ZSkKICAgIHAuYWRkX2FyZ3VtZW50KCItLWJvZHkiLCByZXF1aXJlZD1UcnVlKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX3NlbmQpCiAgICBhID0gYXAucGFyc2VfYXJncygpCiAgICBhLmZuKGEpCgoKaWYgX19uYW1lX18gPT0gIl9fbWFpbl9fIjoKICAgIG1haW4oKQo='
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
