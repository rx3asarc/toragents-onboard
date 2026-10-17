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

# The daemon sources are embedded here as base64 by tools/embed.py. Fetching
# them from a ref was tried and removed: a force-moved tag served stale bytes
# from the CDN, so a pinned one-liner silently ran a mismatched installer.
PAYLOAD_INBOX='IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwoiIiJpbmJveF9hZ2VudC5weSAtLSBhIHZlcmlmaWVkIG1lc3NhZ2UgaW5ib3ggYmVoaW5kIGEgdG9yIGhpZGRlbiBzZXJ2aWNlLgoKUnVucyBvbiBIRVIgbWFjaGluZS4gTGlzdGVucyBvbiBhIHBsYWluIGxvY2FsaG9zdCBUQ1AgcG9ydDsgdG9yIGZvcndhcmRzIHRoZQpoaWRkZW4gc2VydmljZSB0byBpdC4gU2VydmluZyBuZWVkcyBubyB0b3IgQVBJIGF0IGFsbCAtLSBubyBjb250cm9sIHBvcnQsIG5vCkFERF9PTklPTiwgbm8ga2V5cyB0byBtYW5hZ2UuIE9ubHkgb3V0Ym91bmQgc2VuZHMgdG91Y2ggdG9yLCB2aWEgU09DS1MuCgpTZWN1cml0eSBtb2RlbAogICAgQSBtZXNzYWdlIGlzIGFjY2VwdGVkIG9ubHkgaWYgdGhlIHNlbmRlciBwcm92ZXMgcG9zc2Vzc2lvbiBvZiBhbgogICAgYWxsb3dsaXN0ZWQgRWQyNTUxOSBrZXkgb3ZlciBhIG9uZS11c2Ugbm9uY2UuIFRoZSBzZW5kZXIncyBjbGFpbWVkIG9uaW9uCiAgICBhZGRyZXNzIGlzIG5ldmVyIHRydXN0ZWQgZm9yIHJvdXRpbmcuCgpVc2FnZQogICAgaW5ib3hfYWdlbnQucHkgc2VydmUgICAgICAgICAgICAgICAgIHJ1biB0aGUgZGFlbW9uCiAgICBpbmJveF9hZ2VudC5weSB3aG9hbWkgICAgICAgICAgICAgICAgcHJpbnQgdGhpcyBtYWNoaW5lJ3Mgb25pb24gKyBmaW5nZXJwcmludAogICAgaW5ib3hfYWdlbnQucHkgYWRkLXBlZXIgRlAgLS1vbmlvbiBBIGFsbG93IGEgcGVlciB0byBzZW5kCiAgICBpbmJveF9hZ2VudC5weSBwZWVycwogICAgaW5ib3hfYWdlbnQucHkgaW5ib3gKICAgIGluYm94X2FnZW50LnB5IHJlYWQgPGlkPgogICAgaW5ib3hfYWdlbnQucHkgYWNrIDxpZD4KICAgIGluYm94X2FnZW50LnB5IHNlbmQgLS10byBMQUJFTCAtLWJvZHkgVEVYVAoiIiIKaW1wb3J0IGFyZ3BhcnNlCmltcG9ydCBiYXNlNjQKaW1wb3J0IGpzb24KaW1wb3J0IG9zCmltcG9ydCBzZWNyZXRzCmltcG9ydCBzb2NrZXQKaW1wb3J0IHN5cwppbXBvcnQgdGhyZWFkaW5nCmltcG9ydCB0aW1lCmltcG9ydCB1dWlkCgpmcm9tIHdpcmUgaW1wb3J0IEFnZW50S2V5cywgUHVibGljSWRlbnRpdHkKCkhPTUUgPSBvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX0hPTUUiLCBvcy5wYXRoLmV4cGFuZHVzZXIoIn4vLnRvcmFnZW50cyIpKQpTVEFURSA9IG9zLnBhdGguam9pbihIT01FLCAic3RhdGUiKQpJTkJPWCA9IG9zLnBhdGguam9pbihTVEFURSwgImluYm94IikKQVJDSElWRSA9IG9zLnBhdGguam9pbihTVEFURSwgImFyY2hpdmUiKQpQRUVSUyA9IG9zLnBhdGguam9pbihTVEFURSwgInBlZXJzLmpzb24iKQpJREZJTEUgPSBvcy5wYXRoLmpvaW4oU1RBVEUsICJpZGVudGl0eS5qc29uIikKSE9TVE5BTUVfRklMRSA9IG9zLnBhdGguam9pbihIT01FLCAiaHMiLCAiaG9zdG5hbWUiKQoKTElTVEVOX1BPUlQgPSBpbnQob3MuZW52aXJvbi5nZXQoIlRPUkFHRU5UU19QT1JUIiwgODc5OSkpClNPQ0tTX1BPUlQgPSBpbnQob3MuZW52aXJvbi5nZXQoIlRPUkFHRU5UU19TT0NLUyIsIDkwNTApKQpOT05DRV9UVEwgPSAxODAuMAoKYjY0ZSA9IGxhbWJkYSBiOiBiYXNlNjQuYjY0ZW5jb2RlKGIpLmRlY29kZSgiYXNjaWkiKQpiNjRkID0gbGFtYmRhIHM6IGJhc2U2NC5iNjRkZWNvZGUocykKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gc3RhdGUgLS0tCmRlZiBkaXJzKCk6CiAgICBmb3IgZCBpbiAoU1RBVEUsIElOQk9YLCBBUkNISVZFKToKICAgICAgICBvcy5tYWtlZGlycyhkLCBleGlzdF9vaz1UcnVlKQoKCmRlZiBrZXlzKCk6CiAgICBkaXJzKCkKICAgIGlmIG9zLnBhdGguZXhpc3RzKElERklMRSk6CiAgICAgICAgd2l0aCBvcGVuKElERklMRSkgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIEFnZW50S2V5cy5mcm9tX3NlY3JldF9kaWN0KGpzb24ubG9hZChmKSkKICAgIGsgPSBBZ2VudEtleXMuZ2VuZXJhdGUoKQogICAgZmQgPSBvcy5vcGVuKElERklMRSwgb3MuT19XUk9OTFkgfCBvcy5PX0NSRUFUIHwgb3MuT19UUlVOQywgMG82MDApCiAgICB3aXRoIG9zLmZkb3BlbihmZCwgInciKSBhcyBmOgogICAgICAgIGpzb24uZHVtcChrLnRvX3NlY3JldF9kaWN0KCksIGYpCiAgICByZXR1cm4gawoKCmRlZiBwZWVycygpOgogICAgaWYgbm90IG9zLnBhdGguZXhpc3RzKFBFRVJTKToKICAgICAgICByZXR1cm4ge30KICAgIHRyeToKICAgICAgICB3aXRoIG9wZW4oUEVFUlMpIGFzIGY6CiAgICAgICAgICAgIHJldHVybiBqc29uLmxvYWQoZikKICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgcmV0dXJuIHt9CgoKZGVmIHNhdmVfcGVlcnMocCk6CiAgICBkaXJzKCkKICAgIHRtcCA9IFBFRVJTICsgIi50bXAiCiAgICB3aXRoIG9wZW4odG1wLCAidyIpIGFzIGY6CiAgICAgICAganNvbi5kdW1wKHAsIGYsIGluZGVudD0yLCBzb3J0X2tleXM9VHJ1ZSkKICAgIG9zLnJlcGxhY2UodG1wLCBQRUVSUykKCgpkZWYgb25pb24oKToKICAgIHRyeToKICAgICAgICB3aXRoIG9wZW4oSE9TVE5BTUVfRklMRSkgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIGYucmVhZCgpLnN0cmlwKCkKICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgcmV0dXJuIE5vbmUKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBmcmFtaW5nIC0tCmRlZiBzZW5kX21zZyhzb2NrLCBvYmopOgogICAgZGF0YSA9IGpzb24uZHVtcHMob2JqKS5lbmNvZGUoKQogICAgc29jay5zZW5kYWxsKGxlbihkYXRhKS50b19ieXRlcyg0LCAiYmlnIikgKyBkYXRhKQoKCk1BWF9GUkFNRSA9IDE2ICogMTAyNCAqIDEwMjQgICMgc2FtZSBjZWlsaW5nIHRvcmFnZW50cyB1c2VzOyBzdG9wcyBhIGhvc3RpbGUgaGVhZGVyCgoKZGVmIHJlY3ZfbXNnKHNvY2spOgogICAgaGRyID0gX3JlYWRfZXhhY3Qoc29jaywgNCkKICAgIGlmIGhkciBpcyBOb25lOgogICAgICAgIHJldHVybiBOb25lCiAgICBuID0gaW50LmZyb21fYnl0ZXMoaGRyLCAiYmlnIikKICAgIGlmIG4gPiBNQVhfRlJBTUU6CiAgICAgICAgcmFpc2UgVmFsdWVFcnJvcihmImRlY2xhcmVkIGZyYW1lIHtufSBleGNlZWRzIHtNQVhfRlJBTUV9IikKICAgIGJvZHkgPSBfcmVhZF9leGFjdChzb2NrLCBuKQogICAgaWYgYm9keSBpcyBOb25lOgogICAgICAgIHJldHVybiBOb25lCiAgICByZXR1cm4ganNvbi5sb2Fkcyhib2R5LmRlY29kZSgpKQoKCmRlZiBfcmVhZF9leGFjdChzb2NrLCBuKToKICAgIGJ1ZiA9IGIiIgogICAgd2hpbGUgbGVuKGJ1ZikgPCBuOgogICAgICAgIGNodW5rID0gc29jay5yZWN2KG4gLSBsZW4oYnVmKSkKICAgICAgICBpZiBub3QgY2h1bms6CiAgICAgICAgICAgIHJldHVybiBOb25lCiAgICAgICAgYnVmICs9IGNodW5rCiAgICByZXR1cm4gYnVmCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIG5vbmNlcyAtLQpjbGFzcyBOb25jZXM6CiAgICBkZWYgX19pbml0X18oc2VsZik6CiAgICAgICAgc2VsZi5fZCwgc2VsZi5fbG9jayA9IHt9LCB0aHJlYWRpbmcuTG9jaygpCgogICAgZGVmIGlzc3VlKHNlbGYpOgogICAgICAgIG4gPSBzZWNyZXRzLnRva2VuX2J5dGVzKDMyKQogICAgICAgIHdpdGggc2VsZi5fbG9jazoKICAgICAgICAgICAgbm93ID0gdGltZS50aW1lKCkKICAgICAgICAgICAgc2VsZi5fZCA9IHtrOiB2IGZvciBrLCB2IGluIHNlbGYuX2QuaXRlbXMoKSBpZiB2ID4gbm93fQogICAgICAgICAgICBzZWxmLl9kW2I2NGUobildID0gbm93ICsgTk9OQ0VfVFRMCiAgICAgICAgcmV0dXJuIG4KCiAgICBkZWYgY29uc3VtZShzZWxmLCB0b2tlbik6CiAgICAgICAgd2l0aCBzZWxmLl9sb2NrOgogICAgICAgICAgICBleHAgPSBzZWxmLl9kLnBvcCh0b2tlbiwgTm9uZSkKICAgICAgICBpZiBleHAgaXMgTm9uZSBvciBleHAgPCB0aW1lLnRpbWUoKToKICAgICAgICAgICAgcmV0dXJuIE5vbmUKICAgICAgICB0cnk6CiAgICAgICAgICAgIHJldHVybiBiNjRkKHRva2VuKQogICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgIHJldHVybiBOb25lCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIHNlcnZlciAtLQpjbGFzcyBJbmJveDoKICAgIGRlZiBfX2luaXRfXyhzZWxmKToKICAgICAgICBzZWxmLmsgPSBrZXlzKCkKICAgICAgICBzZWxmLm5vbmNlcyA9IE5vbmNlcygpCiAgICAgICAgc2VsZi5wZWVycyA9IHBlZXJzKCkKICAgICAgICBzZWxmLmxvY2sgPSB0aHJlYWRpbmcuTG9jaygpCiAgICAgICAgc2VsZi5hY2NlcHRlZCA9IHNlbGYucmVqZWN0ZWQgPSAwCiAgICAgICAgc2VsZi5hZGRyID0gb25pb24oKQogICAgICAgIHNlbGYuX3BlZXJzX210aW1lID0gc2VsZi5fbXRpbWUoKQoKICAgIGRlZiBfbXRpbWUoc2VsZik6CiAgICAgICAgdHJ5OgogICAgICAgICAgICByZXR1cm4gb3MucGF0aC5nZXRtdGltZShQRUVSUykKICAgICAgICBleGNlcHQgT1NFcnJvcjoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKCiAgICBkZWYgX3JlbG9hZF9wZWVyc19pZl9jaGFuZ2VkKHNlbGYpOgogICAgICAgICIiIlBpY2sgdXAgYGFkZC1wZWVyYCB3aXRob3V0IHJlc3RhcnRpbmcgdGhlIGRhZW1vbi4iIiIKICAgICAgICBub3cgPSBzZWxmLl9tdGltZSgpCiAgICAgICAgaWYgbm93ICE9IHNlbGYuX3BlZXJzX210aW1lOgogICAgICAgICAgICB3aXRoIHNlbGYubG9jazoKICAgICAgICAgICAgICAgIHNlbGYucGVlcnMgPSBwZWVycygpCiAgICAgICAgICAgICAgICBzZWxmLl9wZWVyc19tdGltZSA9IG5vdwogICAgICAgICAgICBwcmludChmIltpbmJveF0gcGVlciBsaXN0IHJlbG9hZGVkICh7bGVuKHNlbGYucGVlcnMpfSBhbGxvd2VkKSIsIGZsdXNoPVRydWUpCgogICAgZGVmIGhhbmRsZShzZWxmLCByZXEpOgogICAgICAgIG9wID0gcmVxLmdldCgib3AiKQogICAgICAgIGlmIG9wID09ICJwaW5nIjoKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBUcnVlLCAic2VydmljZSI6ICJ0b3JhZ2VudHMtaW5ib3giLCAib25pb24iOiBzZWxmLmFkZHIsCiAgICAgICAgICAgICAgICAgICAgImZpbmdlcnByaW50Ijogc2VsZi5rLnB1YmxpYygpLmZpbmdlcnByaW50fQogICAgICAgIGlmIG9wID09ICJoZWxsbyI6CiAgICAgICAgICAgIHJldHVybiB7Im9rIjogVHJ1ZSwgIm5vbmNlIjogYjY0ZShzZWxmLm5vbmNlcy5pc3N1ZSgpKX0KICAgICAgICBpZiBvcCA9PSAic2VuZCI6CiAgICAgICAgICAgIHJldHVybiBzZWxmLl9hY2NlcHQocmVxKQogICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6IGYidW5rbm93biBvcCB7b3Ahcn0ifQoKICAgIGRlZiBfYWNjZXB0KHNlbGYsIHJlcSk6CiAgICAgICAgdG9rZW4sIGJvZHksIHB1Yiwgc2lnID0gKHJlcS5nZXQoIm5vbmNlIiksIHJlcS5nZXQoImJvZHkiKSwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgcmVxLmdldCgicHVia2V5IiksIHJlcS5nZXQoInNpZyIpKQogICAgICAgIGlmIG5vdCBhbGwoW3Rva2VuLCBpc2luc3RhbmNlKGJvZHksIHN0ciksIHB1Yiwgc2lnXSk6CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAibWFsZm9ybWVkIHNlbmQifQoKICAgICAgICBub25jZSA9IHNlbGYubm9uY2VzLmNvbnN1bWUodG9rZW4pCiAgICAgICAgaWYgbm9uY2UgaXMgTm9uZToKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJzdGFsZSBvciB1bmtub3duIG5vbmNlIn0KCiAgICAgICAgdHJ5OgogICAgICAgICAgICBzZW5kZXIgPSBQdWJsaWNJZGVudGl0eS5mcm9tX2RpY3QocHViKQogICAgICAgICAgICBzaWduYXR1cmUgPSBiNjRkKHNpZykKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogImJhZCBwdWJrZXkgb3Igc2lnbmF0dXJlIGVuY29kaW5nIn0KCiAgICAgICAgaWYgbm90IHNlbmRlci52ZXJpZnkobm9uY2UgKyBib2R5LmVuY29kZSgidXRmLTgiKSwgc2lnbmF0dXJlKToKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJzaWduYXR1cmUgZG9lcyBub3QgdmVyaWZ5In0KCiAgICAgICAgZnAgPSBzZW5kZXIuZmluZ2VycHJpbnQKICAgICAgICBzZWxmLl9yZWxvYWRfcGVlcnNfaWZfY2hhbmdlZCgpCiAgICAgICAgd2l0aCBzZWxmLmxvY2s6CiAgICAgICAgICAgIHBlZXIgPSBzZWxmLnBlZXJzLmdldChmcCkKICAgICAgICBpZiBwZWVyIGlzIE5vbmU6CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAic2VuZGVyIG5vdCBvbiBhbGxvd2xpc3QiLAogICAgICAgICAgICAgICAgICAgICJmaW5nZXJwcmludCI6IGZwfQoKICAgICAgICBtaWQgPSB1dWlkLnV1aWQ0KCkuaGV4WzoxMl0KICAgICAgICByZWMgPSB7ImlkIjogbWlkLCAicmVjZWl2ZWQiOiB0aW1lLnRpbWUoKSwgImZyb21fZmluZ2VycHJpbnQiOiBmcCwKICAgICAgICAgICAgICAgImZyb21fbGFiZWwiOiBwZWVyLmdldCgibGFiZWwiLCAiIiksICJmcm9tX29uaW9uIjogcGVlci5nZXQoIm9uaW9uIiwgIiIpLAogICAgICAgICAgICAgICAiYm9keSI6IGJvZHl9CiAgICAgICAgcGF0aCA9IG9zLnBhdGguam9pbihJTkJPWCwgZiJ7dGltZS50aW1lKCk6LjBmfS17bWlkfS5qc29uIikKICAgICAgICB3aXRoIG9wZW4ocGF0aCArICIudG1wIiwgInciKSBhcyBmOgogICAgICAgICAgICBqc29uLmR1bXAocmVjLCBmLCBpbmRlbnQ9MikKICAgICAgICBvcy5yZXBsYWNlKHBhdGggKyAiLnRtcCIsIHBhdGgpCiAgICAgICAgc2VsZi5hY2NlcHRlZCArPSAxCiAgICAgICAgcHJpbnQoZiJbaW5ib3hdICt7bWlkfSBmcm9tIHtwZWVyLmdldCgnbGFiZWwnKSBvciBmcFs6MTJdfSIsIGZsdXNoPVRydWUpCiAgICAgICAgcmV0dXJuIHsib2siOiBUcnVlLCAiaWQiOiBtaWR9CgoKZGVmIGNsaWVudF9sb29wKGNvbm4sIGJveCk6CiAgICB0cnk6CiAgICAgICAgd2hpbGUgVHJ1ZToKICAgICAgICAgICAgcmVxID0gcmVjdl9tc2coY29ubikKICAgICAgICAgICAgaWYgcmVxIGlzIE5vbmU6CiAgICAgICAgICAgICAgICBicmVhawogICAgICAgICAgICB0cnk6CiAgICAgICAgICAgICAgICByZXBseSA9IGJveC5oYW5kbGUocmVxKQogICAgICAgICAgICBleGNlcHQgRXhjZXB0aW9uIGFzIGV4YzoKICAgICAgICAgICAgICAgIHJlcGx5ID0geyJvayI6IEZhbHNlLCAiZXJyb3IiOiBmImhhbmRsZXI6IHtleGN9In0KICAgICAgICAgICAgc2VuZF9tc2coY29ubiwgcmVwbHkpCiAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgIHBhc3MKICAgIGZpbmFsbHk6CiAgICAgICAgdHJ5OgogICAgICAgICAgICBjb25uLmNsb3NlKCkKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICBwYXNzCgoKZGVmIHNlcnZlKCk6CiAgICBib3ggPSBJbmJveCgpCiAgICBzcnYgPSBzb2NrZXQuc29ja2V0KHNvY2tldC5BRl9JTkVULCBzb2NrZXQuU09DS19TVFJFQU0pCiAgICBzcnYuc2V0c29ja29wdChzb2NrZXQuU09MX1NPQ0tFVCwgc29ja2V0LlNPX1JFVVNFQUREUiwgMSkKICAgIHNydi5iaW5kKCgiMTI3LjAuMC4xIiwgTElTVEVOX1BPUlQpKQogICAgc3J2Lmxpc3RlbigxNikKICAgIHByaW50KGYibGlzdGVuaW5nIDEyNy4wLjAuMTp7TElTVEVOX1BPUlR9IiwgZmx1c2g9VHJ1ZSkKICAgIHByaW50KGYib25pb24gICAgICB7Ym94LmFkZHIgb3IgJyhoaWRkZW4gc2VydmljZSBub3QgY29uZmlndXJlZCB5ZXQpJ30iLCBmbHVzaD1UcnVlKQogICAgcHJpbnQoZiJmaW5nZXJwcmludCB7Ym94LmsucHVibGljKCkuZmluZ2VycHJpbnR9IiwgZmx1c2g9VHJ1ZSkKICAgIHByaW50KGYicGVlcnMgICAgICB7bGVuKGJveC5wZWVycyl9IiwgZmx1c2g9VHJ1ZSkKICAgIHRyeToKICAgICAgICB3aGlsZSBUcnVlOgogICAgICAgICAgICBjb25uLCBfID0gc3J2LmFjY2VwdCgpCiAgICAgICAgICAgIHRocmVhZGluZy5UaHJlYWQodGFyZ2V0PWNsaWVudF9sb29wLCBhcmdzPShjb25uLCBib3gpLCBkYWVtb249VHJ1ZSkuc3RhcnQoKQogICAgZXhjZXB0IEtleWJvYXJkSW50ZXJydXB0OgogICAgICAgIHBhc3MKICAgIGZpbmFsbHk6CiAgICAgICAgc3J2LmNsb3NlKCkKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gY2xpZW50IC0tCmRlZiBkaWFsKHRhcmdldF9vbmlvbiwgdGltZW91dD0xMjApOgogICAgIiIiUGxhaW4gU09DS1M1IGRpYWwgdGhyb3VnaCB0aGUgbG9jYWwgdG9yLiBObyB0b3IgQVBJLCBqdXN0IHNvY2tzLiIiIgogICAgaW1wb3J0IHNvY2tzCiAgICBob3N0ID0gdGFyZ2V0X29uaW9uWzotNl0gaWYgdGFyZ2V0X29uaW9uLmVuZHN3aXRoKCIub25pb24iKSBlbHNlIHRhcmdldF9vbmlvbgogICAgbGFzdCA9IE5vbmUKICAgIGZvciBhdHRlbXB0IGluIHJhbmdlKDQpOgogICAgICAgIHMgPSBzb2Nrcy5zb2Nrc29ja2V0KCkKICAgICAgICBzLnNldF9wcm94eShzb2Nrcy5TT0NLUzUsICIxMjcuMC4wLjEiLCBTT0NLU19QT1JULCByZG5zPVRydWUpCiAgICAgICAgcy5zZXR0aW1lb3V0KG1heCh0aW1lb3V0IC8gNCwgMjApKQogICAgICAgIHRyeToKICAgICAgICAgICAgcy5jb25uZWN0KChob3N0ICsgIi5vbmlvbiIsIDgwKSkKICAgICAgICAgICAgcmV0dXJuIHMKICAgICAgICBleGNlcHQgRXhjZXB0aW9uIGFzIGV4YzoKICAgICAgICAgICAgbGFzdCA9IGV4YwogICAgICAgICAgICB0cnk6CiAgICAgICAgICAgICAgICBzLmNsb3NlKCkKICAgICAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgICAgIHBhc3MKICAgICAgICAgICAgdGltZS5zbGVlcCgyKQogICAgcmFpc2UgQ29ubmVjdGlvbkVycm9yKGYiY2Fubm90IHJlYWNoIHt0YXJnZXRfb25pb25bOjE2XX0uLi46IHtsYXN0fSIpCgoKZGVmIHNlbmRfdG8odGFyZ2V0X29uaW9uLCBib2R5LCBrPU5vbmUpOgogICAgayA9IGsgb3Iga2V5cygpCiAgICBzb2NrID0gZGlhbCh0YXJnZXRfb25pb24pCiAgICB0cnk6CiAgICAgICAgc2VuZF9tc2coc29jaywgeyJvcCI6ICJoZWxsbyJ9KQogICAgICAgIGhlbGxvID0gcmVjdl9tc2coc29jaykKICAgICAgICBpZiBub3QgaGVsbG8gb3Igbm90IGhlbGxvLmdldCgib2siKToKICAgICAgICAgICAgcmFpc2UgUnVudGltZUVycm9yKGYiaGVsbG8gcmVmdXNlZDoge2hlbGxvfSIpCiAgICAgICAgbm9uY2UgPSBiNjRkKGhlbGxvWyJub25jZSJdKQogICAgICAgIHNlbmRfbXNnKHNvY2ssIHsib3AiOiAic2VuZCIsICJub25jZSI6IGhlbGxvWyJub25jZSJdLCAiYm9keSI6IGJvZHksCiAgICAgICAgICAgICAgICAgICAgICAgICJwdWJrZXkiOiBrLnB1YmxpYygpLnRvX2RpY3QoKSwKICAgICAgICAgICAgICAgICAgICAgICAgInNpZyI6IGI2NGUoay5zaWduKG5vbmNlICsgYm9keS5lbmNvZGUoInV0Zi04IikpKX0pCiAgICAgICAgcmV0dXJuIHJlY3ZfbXNnKHNvY2spCiAgICBmaW5hbGx5OgogICAgICAgIHRyeToKICAgICAgICAgICAgc29jay5jbG9zZSgpCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgcGFzcwoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBjbGkgLS0KZGVmIGNtZF9zZXJ2ZShhKToKICAgIHNlcnZlKCkKCgpkZWYgY21kX3dob2FtaShhKToKICAgIGsgPSBrZXlzKCkKICAgIHByaW50KGYib25pb24gICAgICAgIHtvbmlvbigpIG9yICcobm90IGNvbmZpZ3VyZWQpJ30iKQogICAgcHJpbnQoZiJmaW5nZXJwcmludCAge2sucHVibGljKCkuZmluZ2VycHJpbnR9IikKCgpkZWYgY21kX2FkZF9wZWVyKGEpOgogICAgcCA9IHBlZXJzKCkKICAgIGZwID0gYS5maW5nZXJwcmludC5zdHJpcCgpLmxvd2VyKCkKICAgIGlmIGxlbihmcCkgIT0gMzI6CiAgICAgICAgc3lzLmV4aXQoZiJmaW5nZXJwcmludCBtdXN0IGJlIDMyIGhleCBjaGFycyAoZ290IHtsZW4oZnApfSkiKQogICAgaWYgbm90IGEub25pb24uZW5kc3dpdGgoIi5vbmlvbiIpOgogICAgICAgIHN5cy5leGl0KCItLW9uaW9uIG11c3QgZW5kIGluIC5vbmlvbiIpCiAgICBwW2ZwXSA9IHsib25pb24iOiBhLm9uaW9uLnN0cmlwKCksICJsYWJlbCI6IGEubGFiZWwgb3IgZnBbOjEyXSwKICAgICAgICAgICAgICJhZGRlZCI6IHRpbWUudGltZSgpfQogICAgc2F2ZV9wZWVycyhwKQogICAgcHJpbnQoZiJhbGxvd2xpc3RlZCB7cFtmcF1bJ2xhYmVsJ119ICh7ZnBbOjEyXX0uLi4pIC0+IHthLm9uaW9ufSIpCgoKZGVmIGNtZF9wZWVycyhhKToKICAgIHAgPSBwZWVycygpCiAgICBpZiBub3QgcDoKICAgICAgICBwcmludCgiKG5vIHBlZXJzIGFsbG93bGlzdGVkKSIpCiAgICBmb3IgZnAsIHYgaW4gc29ydGVkKHAuaXRlbXMoKSwga2V5PWxhbWJkYSBrdjoga3ZbMV0uZ2V0KCJsYWJlbCIsICIiKSk6CiAgICAgICAgcHJpbnQoZiJ7di5nZXQoJ2xhYmVsJywnJyk6MTh9IHtmcFs6MTZdfS4uLiAge3ZbJ29uaW9uJ119IikKCgpkZWYgX21zZ3MoaW5jbHVkZV9hcmNoaXZlZD1GYWxzZSk6CiAgICBvdXQgPSBbXQogICAgZm9yIGQsIGFyY2ggaW4gKChJTkJPWCwgRmFsc2UpLCAoQVJDSElWRSwgVHJ1ZSkpOgogICAgICAgIGlmIG5vdCBvcy5wYXRoLmlzZGlyKGQpOgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIGlmIGFyY2ggYW5kIG5vdCBpbmNsdWRlX2FyY2hpdmVkOgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIGZvciBuIGluIHNvcnRlZChvcy5saXN0ZGlyKGQpKToKICAgICAgICAgICAgaWYgbi5lbmRzd2l0aCgiLmpzb24iKToKICAgICAgICAgICAgICAgIHRyeToKICAgICAgICAgICAgICAgICAgICB3aXRoIG9wZW4ob3MucGF0aC5qb2luKGQsIG4pKSBhcyBmOgogICAgICAgICAgICAgICAgICAgICAgICBtID0ganNvbi5sb2FkKGYpCiAgICAgICAgICAgICAgICAgICAgbVsiX2FyY2hpdmVkIl0gPSBhcmNoCiAgICAgICAgICAgICAgICAgICAgb3V0LmFwcGVuZChtKQogICAgICAgICAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgICAgICAgICBwYXNzCiAgICByZXR1cm4gc29ydGVkKG91dCwga2V5PWxhbWJkYSBtOiBtLmdldCgicmVjZWl2ZWQiLCAwKSkKCgpkZWYgY21kX2luYm94KGEpOgogICAgbXMgPSBfbXNncyhhLmFsbCkKICAgIGlmIG5vdCBtczoKICAgICAgICBwcmludCgiKGluYm94IGVtcHR5KSIpCiAgICBmb3IgbSBpbiBtczoKICAgICAgICB3aGVuID0gdGltZS5zdHJmdGltZSgiJVktJW0tJWQgJUg6JU0iLCB0aW1lLmxvY2FsdGltZShtLmdldCgicmVjZWl2ZWQiLCAwKSkpCiAgICAgICAgcHJpbnQoZiJ7bVsnaWQnXX0gIHt3aGVufSAge20uZ2V0KCdmcm9tX2xhYmVsJywnPycpOjE2fSAiCiAgICAgICAgICAgICAgZiJ7KG0uZ2V0KCdib2R5Jykgb3IgJycpLnJlcGxhY2UoY2hyKDEwKSwnICcpWzo2MF19IikKCgpkZWYgY21kX3JlYWQoYSk6CiAgICBmb3IgbSBpbiBfbXNncyhUcnVlKToKICAgICAgICBpZiBtWyJpZCJdID09IGEuaWQ6CiAgICAgICAgICAgIHByaW50KGpzb24uZHVtcHMobSwgaW5kZW50PTIpKQogICAgICAgICAgICByZXR1cm4KICAgIHN5cy5leGl0KGYibm8gbWVzc2FnZSB7YS5pZH0iKQoKCmRlZiBjbWRfYWNrKGEpOgogICAgZm9yIG4gaW4gKG9zLmxpc3RkaXIoSU5CT1gpIGlmIG9zLnBhdGguaXNkaXIoSU5CT1gpIGVsc2UgW10pOgogICAgICAgIGlmIGEuaWQgaW4gbjoKICAgICAgICAgICAgb3MucmVwbGFjZShvcy5wYXRoLmpvaW4oSU5CT1gsIG4pLCBvcy5wYXRoLmpvaW4oQVJDSElWRSwgbikpCiAgICAgICAgICAgIHByaW50KGYiYXJjaGl2ZWQge2EuaWR9IikKICAgICAgICAgICAgcmV0dXJuCiAgICBzeXMuZXhpdChmIm5vIHVuYXJjaGl2ZWQgbWVzc2FnZSB7YS5pZH0iKQoKCmRlZiBjbWRfc2VuZChhKToKICAgIHAgPSBwZWVycygpCiAgICB0YXJnZXQgPSBOb25lCiAgICBmb3IgZnAsIHYgaW4gcC5pdGVtcygpOgogICAgICAgIGlmIGEudG8gaW4gKGZwLCB2LmdldCgibGFiZWwiKSwgZnBbOjEyXSk6CiAgICAgICAgICAgIHRhcmdldCA9IHYKICAgICAgICAgICAgYnJlYWsKICAgIGlmIHRhcmdldCBpcyBOb25lOgogICAgICAgIHN5cy5leGl0KGYidW5rbm93biBwZWVyIHthLnRvIXJ9OyB0cnk6IGluYm94X2FnZW50LnB5IHBlZXJzIikKICAgIHJlcGx5ID0gc2VuZF90byh0YXJnZXRbIm9uaW9uIl0sIGEuYm9keSkKICAgIHByaW50KGpzb24uZHVtcHMocmVwbHksIGluZGVudD0yKSkKICAgIHN5cy5leGl0KDAgaWYgcmVwbHkgYW5kIHJlcGx5LmdldCgib2siKSBlbHNlIDEpCgoKZGVmIG1haW4oKToKICAgIGFwID0gYXJncGFyc2UuQXJndW1lbnRQYXJzZXIoZGVzY3JpcHRpb249X19kb2NfXywKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZm9ybWF0dGVyX2NsYXNzPWFyZ3BhcnNlLlJhd0Rlc2NyaXB0aW9uSGVscEZvcm1hdHRlcikKICAgIHMgPSBhcC5hZGRfc3VicGFyc2VycyhkZXN0PSJjbWQiLCByZXF1aXJlZD1UcnVlKQogICAgcy5hZGRfcGFyc2VyKCJzZXJ2ZSIpLnNldF9kZWZhdWx0cyhmbj1jbWRfc2VydmUpCiAgICBzLmFkZF9wYXJzZXIoIndob2FtaSIpLnNldF9kZWZhdWx0cyhmbj1jbWRfd2hvYW1pKQogICAgcy5hZGRfcGFyc2VyKCJwZWVycyIpLnNldF9kZWZhdWx0cyhmbj1jbWRfcGVlcnMpCiAgICBwID0gcy5hZGRfcGFyc2VyKCJhZGQtcGVlciIpCiAgICBwLmFkZF9hcmd1bWVudCgiZmluZ2VycHJpbnQiKQogICAgcC5hZGRfYXJndW1lbnQoIi0tb25pb24iLCByZXF1aXJlZD1UcnVlKQogICAgcC5hZGRfYXJndW1lbnQoIi0tbGFiZWwiLCBkZWZhdWx0PSIiKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX2FkZF9wZWVyKQogICAgcCA9IHMuYWRkX3BhcnNlcigiaW5ib3giKQogICAgcC5hZGRfYXJndW1lbnQoIi0tYWxsIiwgYWN0aW9uPSJzdG9yZV90cnVlIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9pbmJveCkKICAgIHAgPSBzLmFkZF9wYXJzZXIoInJlYWQiKQogICAgcC5hZGRfYXJndW1lbnQoImlkIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9yZWFkKQogICAgcCA9IHMuYWRkX3BhcnNlcigiYWNrIikKICAgIHAuYWRkX2FyZ3VtZW50KCJpZCIpCiAgICBwLnNldF9kZWZhdWx0cyhmbj1jbWRfYWNrKQogICAgcCA9IHMuYWRkX3BhcnNlcigic2VuZCIpCiAgICBwLmFkZF9hcmd1bWVudCgiLS10byIsIHJlcXVpcmVkPVRydWUpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1ib2R5IiwgcmVxdWlyZWQ9VHJ1ZSkKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9zZW5kKQogICAgYSA9IGFwLnBhcnNlX2FyZ3MoKQogICAgYS5mbihhKQoKCmlmIF9fbmFtZV9fID09ICJfX21haW5fXyI6CiAgICBtYWluKCkK'
PAYLOAD_WIRE='IiIid2lyZS5weSAtLSB0aGUgb25seSBjcnlwdG8gdGhlIGluYm94IG5lZWRzLiBQeU5hQ2wsIG5vdGhpbmcgZWxzZS4KCkRlbGliZXJhdGVseSBpZGVudGljYWwgaW4gZm9ybWF0IHRvIHRvcmFnZW50cy5jcnlwdG8gc28gYW4gaWRlbnRpdHkgY3JlYXRlZCBieQplaXRoZXIgaW1wbGVtZW50YXRpb24gaXMgcmVhZGFibGUgYnkgdGhlIG90aGVyOiBzYW1lIHNlZWQvYm94IEpTT04sIHNhbWUKYmxha2UyYih2ZXJpZnl8fGJveCwgMTYpIGZpbmdlcnByaW50LiBQeU5hQ2wgZG9lcyBhbGwgdGhlIHJlYWwgd29yazsgdGhpcyBmaWxlCmp1c3QgbmFtZXMgdGhpbmdzLgoiIiIKaW1wb3J0IGJhc2U2NAoKaW1wb3J0IG5hY2wuaGFzaApmcm9tIG5hY2wuZW5jb2RpbmcgaW1wb3J0IFJhd0VuY29kZXIKZnJvbSBuYWNsLnB1YmxpYyBpbXBvcnQgUHJpdmF0ZUtleSwgUHVibGljS2V5LCBTZWFsZWRCb3gKZnJvbSBuYWNsLnNpZ25pbmcgaW1wb3J0IFNpZ25pbmdLZXksIFZlcmlmeUtleQoKYjY0ZSA9IGxhbWJkYSBiOiBiYXNlNjQuYjY0ZW5jb2RlKGIpLmRlY29kZSgiYXNjaWkiKQpiNjRkID0gbGFtYmRhIHM6IGJhc2U2NC5iNjRkZWNvZGUocykKCgpjbGFzcyBQdWJsaWNJZGVudGl0eToKICAgICIiIlNvbWVvbmUgZWxzZSdzIHB1YmxpYyBoYWxmOiB2ZXJpZnkgdGhlaXIgc2lnbmF0dXJlcywgc2VhbCBib3hlcyB0byB0aGVtLiIiIgoKICAgIGRlZiBfX2luaXRfXyhzZWxmLCB2ZXJpZnlfa2V5OiBieXRlcywgYm94X2tleTogYnl0ZXMpOgogICAgICAgIHNlbGYuX3ZlcmlmeSA9IFZlcmlmeUtleSh2ZXJpZnlfa2V5KQogICAgICAgIHNlbGYuX2JveCA9IFB1YmxpY0tleShib3hfa2V5KQoKICAgIEBwcm9wZXJ0eQogICAgZGVmIHZlcmlmeV9rZXkoc2VsZikgLT4gYnl0ZXM6CiAgICAgICAgcmV0dXJuIGJ5dGVzKHNlbGYuX3ZlcmlmeSkKCiAgICBAcHJvcGVydHkKICAgIGRlZiBib3hfa2V5KHNlbGYpIC0+IGJ5dGVzOgogICAgICAgIHJldHVybiBieXRlcyhzZWxmLl9ib3gpCgogICAgQHByb3BlcnR5CiAgICBkZWYgZmluZ2VycHJpbnQoc2VsZikgLT4gc3RyOgogICAgICAgIHJldHVybiBuYWNsLmhhc2guYmxha2UyYigKICAgICAgICAgICAgc2VsZi52ZXJpZnlfa2V5ICsgc2VsZi5ib3hfa2V5LCBkaWdlc3Rfc2l6ZT0xNiwgZW5jb2Rlcj1SYXdFbmNvZGVyCiAgICAgICAgKS5oZXgoKQoKICAgIGRlZiB2ZXJpZnkoc2VsZiwgbWVzc2FnZTogYnl0ZXMsIHNpZ25hdHVyZTogYnl0ZXMpIC0+IGJvb2w6CiAgICAgICAgdHJ5OgogICAgICAgICAgICBzZWxmLl92ZXJpZnkudmVyaWZ5KG1lc3NhZ2UsIHNpZ25hdHVyZSkKICAgICAgICAgICAgcmV0dXJuIFRydWUKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICByZXR1cm4gRmFsc2UKCiAgICBkZWYgdG9fZGljdChzZWxmKSAtPiBkaWN0OgogICAgICAgIHJldHVybiB7InZlcmlmeSI6IGI2NGUoc2VsZi52ZXJpZnlfa2V5KSwgImJveCI6IGI2NGUoc2VsZi5ib3hfa2V5KX0KCiAgICBAY2xhc3NtZXRob2QKICAgIGRlZiBmcm9tX2RpY3QoY2xzLCBkOiBkaWN0KSAtPiAiUHVibGljSWRlbnRpdHkiOgogICAgICAgIHJldHVybiBjbHMoYjY0ZChkWyJ2ZXJpZnkiXSksIGI2NGQoZFsiYm94Il0pKQoKICAgIGRlZiBfX2VxX18oc2VsZiwgb3RoZXIpOgogICAgICAgIHJldHVybiBpc2luc3RhbmNlKG90aGVyLCBQdWJsaWNJZGVudGl0eSkgYW5kIHNlbGYudG9fZGljdCgpID09IG90aGVyLnRvX2RpY3QoKQoKICAgIGRlZiBfX2hhc2hfXyhzZWxmKToKICAgICAgICByZXR1cm4gaGFzaCgoc2VsZi52ZXJpZnlfa2V5LCBzZWxmLmJveF9rZXkpKQoKCmNsYXNzIEFnZW50S2V5czoKICAgICIiIk91ciBwcml2YXRlIGlkZW50aXR5LiBOZXZlciBsZWF2ZXMgdGhpcyBtYWNoaW5lLiIiIgoKICAgIGRlZiBfX2luaXRfXyhzZWxmLCBzaWduaW5nX2tleTogU2lnbmluZ0tleSwgYm94X2tleTogUHJpdmF0ZUtleSk6CiAgICAgICAgc2VsZi5fc2lnbmluZyA9IHNpZ25pbmdfa2V5CiAgICAgICAgc2VsZi5fYm94ID0gYm94X2tleQoKICAgIEBjbGFzc21ldGhvZAogICAgZGVmIGdlbmVyYXRlKGNscykgLT4gIkFnZW50S2V5cyI6CiAgICAgICAgcmV0dXJuIGNscyhTaWduaW5nS2V5LmdlbmVyYXRlKCksIFByaXZhdGVLZXkuZ2VuZXJhdGUoKSkKCiAgICBkZWYgcHVibGljKHNlbGYpIC0+IFB1YmxpY0lkZW50aXR5OgogICAgICAgIHJldHVybiBQdWJsaWNJZGVudGl0eShieXRlcyhzZWxmLl9zaWduaW5nLnZlcmlmeV9rZXkpLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICBieXRlcyhzZWxmLl9ib3gucHVibGljX2tleSkpCgogICAgZGVmIHNpZ24oc2VsZiwgbWVzc2FnZTogYnl0ZXMpIC0+IGJ5dGVzOgogICAgICAgIHJldHVybiBzZWxmLl9zaWduaW5nLnNpZ24obWVzc2FnZSkuc2lnbmF0dXJlCgogICAgZGVmIHRvX3NlY3JldF9kaWN0KHNlbGYpIC0+IGRpY3Q6CiAgICAgICAgcmV0dXJuIHsic2VlZCI6IGI2NGUoc2VsZi5fc2lnbmluZy5lbmNvZGUoKSksICJib3giOiBiNjRlKGJ5dGVzKHNlbGYuX2JveCkpfQoKICAgIEBjbGFzc21ldGhvZAogICAgZGVmIGZyb21fc2VjcmV0X2RpY3QoY2xzLCBkOiBkaWN0KSAtPiAiQWdlbnRLZXlzIjoKICAgICAgICByZXR1cm4gY2xzKFNpZ25pbmdLZXkoYjY0ZChkWyJzZWVkIl0pKSwgUHJpdmF0ZUtleShiNjRkKGRbImJveCJdKSkpCgogICAgZGVmIHNlYWwoc2VsZiwgcmVjaXBpZW50OiBQdWJsaWNJZGVudGl0eSwgcGxhaW50ZXh0OiBieXRlcykgLT4gYnl0ZXM6CiAgICAgICAgcmV0dXJuIFNlYWxlZEJveChyZWNpcGllbnQuX2JveCkuZW5jcnlwdChwbGFpbnRleHQpCgogICAgZGVmIG9wZW5fc2VhbGVkKHNlbGYsIHNlYWxlZDogYnl0ZXMpIC0+IGJ5dGVzOgogICAgICAgIHJldHVybiBTZWFsZWRCb3goc2VsZi5fYm94KS5kZWNyeXB0KHNlYWxlZCkKCgpkZWYgc2VhbF90byhyZWNpcGllbnQ6IFB1YmxpY0lkZW50aXR5LCBwbGFpbnRleHQ6IGJ5dGVzKSAtPiBieXRlczoKICAgIHJldHVybiBTZWFsZWRCb3gocmVjaXBpZW50Ll9ib3gpLmVuY3J5cHQocGxhaW50ZXh0KQoKCmRlZiBvcGVuX3NlYWxlZChrZXlzOiBBZ2VudEtleXMsIHNlYWxlZDogYnl0ZXMpIC0+IGJ5dGVzOgogICAgcmV0dXJuIFNlYWxlZEJveChrZXlzLl9ib3gpLmRlY3J5cHQoc2VhbGVkKQo='

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
