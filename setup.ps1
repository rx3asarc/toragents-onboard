# toragents setup for Windows
#
#   powershell -ExecutionPolicy Bypass -Command "& { iwr <URL>/setup.ps1 -UseBasicParsing | iex }" -- -PeerOnion <addr> -PeerFp <fp>
#
# or, more reliably, download and run it:
#   powershell -ExecutionPolicy Bypass -File setup.ps1 -PeerOnion <addr> -PeerFp <fp>
#
# Zero prerequisites: portable CPython and the official tor binary are both
# downloaded. No admin, no package manager, no Python install, no WSL.
#
# Windows has no bash, which is why this entry point is PowerShell. The macOS
# and Linux entry point is setup.sh.

[CmdletBinding()]
param(
  [string]$PeerOnion = "",
  [string]$PeerFp    = "",
  [string]$PeerLabel = "peer",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

# Bumped on release; these are only used when a component must be fetched.
$PBS_TAG      = if ($env:TORAGENTS_PBS_TAG) { $env:TORAGENTS_PBS_TAG } else { "20261013" }
$PBS_VER      = if ($env:TORAGENTS_PBS_VER) { $env:TORAGENTS_PBS_VER } else { "3.11.17" }
$TOR_BUNDLE   = if ($env:TORAGENTS_TOR_BUNDLE) { $env:TORAGENTS_TOR_BUNDLE } else { "15.0.25" }

# Filled in by tools/embed.py -- the daemon sources travel inside this script.
$PAYLOAD_INBOX='IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwoiIiJpbmJveF9hZ2VudC5weSAtLSBhIHZlcmlmaWVkIG1lc3NhZ2UgaW5ib3ggYmVoaW5kIGEgdG9yIGhpZGRlbiBzZXJ2aWNlLgoKUnVucyBvbiBIRVIgbWFjaGluZS4gTGlzdGVucyBvbiBhIHBsYWluIGxvY2FsaG9zdCBUQ1AgcG9ydDsgdG9yIGZvcndhcmRzIHRoZQpoaWRkZW4gc2VydmljZSB0byBpdC4gU2VydmluZyBuZWVkcyBubyB0b3IgQVBJIGF0IGFsbCAtLSBubyBjb250cm9sIHBvcnQsIG5vCkFERF9PTklPTiwgbm8ga2V5cyB0byBtYW5hZ2UuIE9ubHkgb3V0Ym91bmQgc2VuZHMgdG91Y2ggdG9yLCB2aWEgU09DS1MuCgpTZWN1cml0eSBtb2RlbAogICAgQSBtZXNzYWdlIGlzIGFjY2VwdGVkIG9ubHkgaWYgdGhlIHNlbmRlciBwcm92ZXMgcG9zc2Vzc2lvbiBvZiBhbgogICAgYWxsb3dsaXN0ZWQgRWQyNTUxOSBrZXkgb3ZlciBhIG9uZS11c2Ugbm9uY2UuIFRoZSBzZW5kZXIncyBjbGFpbWVkIG9uaW9uCiAgICBhZGRyZXNzIGlzIG5ldmVyIHRydXN0ZWQgZm9yIHJvdXRpbmcuCgpVc2FnZQogICAgaW5ib3hfYWdlbnQucHkgc2VydmUgICAgICAgICAgICAgICAgIHJ1biB0aGUgZGFlbW9uCiAgICBpbmJveF9hZ2VudC5weSB3aG9hbWkgICAgICAgICAgICAgICAgcHJpbnQgdGhpcyBtYWNoaW5lJ3Mgb25pb24gKyBmaW5nZXJwcmludAogICAgaW5ib3hfYWdlbnQucHkgYWRkLXBlZXIgRlAgLS1vbmlvbiBBIGFsbG93IGEgcGVlciB0byBzZW5kCiAgICBpbmJveF9hZ2VudC5weSBwZWVycwogICAgaW5ib3hfYWdlbnQucHkgaW5ib3gKICAgIGluYm94X2FnZW50LnB5IHJlYWQgPGlkPgogICAgaW5ib3hfYWdlbnQucHkgYWNrIDxpZD4KICAgIGluYm94X2FnZW50LnB5IHNlbmQgLS10byBMQUJFTCAtLWJvZHkgVEVYVAoiIiIKaW1wb3J0IGFyZ3BhcnNlCmltcG9ydCBiYXNlNjQKaW1wb3J0IGpzb24KaW1wb3J0IG9zCmltcG9ydCBzZWNyZXRzCmltcG9ydCBzb2NrZXQKaW1wb3J0IHN5cwppbXBvcnQgdGhyZWFkaW5nCmltcG9ydCB0aW1lCmltcG9ydCB1dWlkCgpmcm9tIHdpcmUgaW1wb3J0IEFnZW50S2V5cywgUHVibGljSWRlbnRpdHkKCkhPTUUgPSBvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX0hPTUUiLCBvcy5wYXRoLmV4cGFuZHVzZXIoIn4vLnRvcmFnZW50cyIpKQpTVEFURSA9IG9zLnBhdGguam9pbihIT01FLCAic3RhdGUiKQpJTkJPWCA9IG9zLnBhdGguam9pbihTVEFURSwgImluYm94IikKQVJDSElWRSA9IG9zLnBhdGguam9pbihTVEFURSwgImFyY2hpdmUiKQpQRUVSUyA9IG9zLnBhdGguam9pbihTVEFURSwgInBlZXJzLmpzb24iKQpJREZJTEUgPSBvcy5wYXRoLmpvaW4oU1RBVEUsICJpZGVudGl0eS5qc29uIikKSE9TVE5BTUVfRklMRSA9IG9zLnBhdGguam9pbihIT01FLCAiaHMiLCAiaG9zdG5hbWUiKQoKTElTVEVOX1BPUlQgPSBpbnQob3MuZW52aXJvbi5nZXQoIlRPUkFHRU5UU19QT1JUIiwgODc5OSkpClNPQ0tTX1BPUlQgPSBpbnQob3MuZW52aXJvbi5nZXQoIlRPUkFHRU5UU19TT0NLUyIsIDkwNTApKQpOT05DRV9UVEwgPSAxODAuMAoKYjY0ZSA9IGxhbWJkYSBiOiBiYXNlNjQuYjY0ZW5jb2RlKGIpLmRlY29kZSgiYXNjaWkiKQpiNjRkID0gbGFtYmRhIHM6IGJhc2U2NC5iNjRkZWNvZGUocykKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gc3RhdGUgLS0tCmRlZiBkaXJzKCk6CiAgICBmb3IgZCBpbiAoU1RBVEUsIElOQk9YLCBBUkNISVZFKToKICAgICAgICBvcy5tYWtlZGlycyhkLCBleGlzdF9vaz1UcnVlKQoKCmRlZiBrZXlzKCk6CiAgICBkaXJzKCkKICAgIGlmIG9zLnBhdGguZXhpc3RzKElERklMRSk6CiAgICAgICAgd2l0aCBvcGVuKElERklMRSkgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIEFnZW50S2V5cy5mcm9tX3NlY3JldF9kaWN0KGpzb24ubG9hZChmKSkKICAgIGsgPSBBZ2VudEtleXMuZ2VuZXJhdGUoKQogICAgZmQgPSBvcy5vcGVuKElERklMRSwgb3MuT19XUk9OTFkgfCBvcy5PX0NSRUFUIHwgb3MuT19UUlVOQywgMG82MDApCiAgICB3aXRoIG9zLmZkb3BlbihmZCwgInciKSBhcyBmOgogICAgICAgIGpzb24uZHVtcChrLnRvX3NlY3JldF9kaWN0KCksIGYpCiAgICByZXR1cm4gawoKCmRlZiBwZWVycygpOgogICAgaWYgbm90IG9zLnBhdGguZXhpc3RzKFBFRVJTKToKICAgICAgICByZXR1cm4ge30KICAgIHRyeToKICAgICAgICB3aXRoIG9wZW4oUEVFUlMpIGFzIGY6CiAgICAgICAgICAgIHJldHVybiBqc29uLmxvYWQoZikKICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgcmV0dXJuIHt9CgoKZGVmIHNhdmVfcGVlcnMocCk6CiAgICBkaXJzKCkKICAgIHRtcCA9IFBFRVJTICsgIi50bXAiCiAgICB3aXRoIG9wZW4odG1wLCAidyIpIGFzIGY6CiAgICAgICAganNvbi5kdW1wKHAsIGYsIGluZGVudD0yLCBzb3J0X2tleXM9VHJ1ZSkKICAgIG9zLnJlcGxhY2UodG1wLCBQRUVSUykKCgpkZWYgb25pb24oKToKICAgIHRyeToKICAgICAgICB3aXRoIG9wZW4oSE9TVE5BTUVfRklMRSkgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIGYucmVhZCgpLnN0cmlwKCkKICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgcmV0dXJuIE5vbmUKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBmcmFtaW5nIC0tCmRlZiBzZW5kX21zZyhzb2NrLCBvYmopOgogICAgZGF0YSA9IGpzb24uZHVtcHMob2JqKS5lbmNvZGUoKQogICAgc29jay5zZW5kYWxsKGxlbihkYXRhKS50b19ieXRlcyg0LCAiYmlnIikgKyBkYXRhKQoKCk1BWF9GUkFNRSA9IDE2ICogMTAyNCAqIDEwMjQgICMgc2FtZSBjZWlsaW5nIHRvcmFnZW50cyB1c2VzOyBzdG9wcyBhIGhvc3RpbGUgaGVhZGVyCgoKZGVmIHJlY3ZfbXNnKHNvY2spOgogICAgaGRyID0gX3JlYWRfZXhhY3Qoc29jaywgNCkKICAgIGlmIGhkciBpcyBOb25lOgogICAgICAgIHJldHVybiBOb25lCiAgICBuID0gaW50LmZyb21fYnl0ZXMoaGRyLCAiYmlnIikKICAgIGlmIG4gPiBNQVhfRlJBTUU6CiAgICAgICAgcmFpc2UgVmFsdWVFcnJvcihmImRlY2xhcmVkIGZyYW1lIHtufSBleGNlZWRzIHtNQVhfRlJBTUV9IikKICAgIGJvZHkgPSBfcmVhZF9leGFjdChzb2NrLCBuKQogICAgaWYgYm9keSBpcyBOb25lOgogICAgICAgIHJldHVybiBOb25lCiAgICByZXR1cm4ganNvbi5sb2Fkcyhib2R5LmRlY29kZSgpKQoKCmRlZiBfcmVhZF9leGFjdChzb2NrLCBuKToKICAgIGJ1ZiA9IGIiIgogICAgd2hpbGUgbGVuKGJ1ZikgPCBuOgogICAgICAgIGNodW5rID0gc29jay5yZWN2KG4gLSBsZW4oYnVmKSkKICAgICAgICBpZiBub3QgY2h1bms6CiAgICAgICAgICAgIHJldHVybiBOb25lCiAgICAgICAgYnVmICs9IGNodW5rCiAgICByZXR1cm4gYnVmCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIG5vbmNlcyAtLQpjbGFzcyBOb25jZXM6CiAgICBkZWYgX19pbml0X18oc2VsZik6CiAgICAgICAgc2VsZi5fZCwgc2VsZi5fbG9jayA9IHt9LCB0aHJlYWRpbmcuTG9jaygpCgogICAgZGVmIGlzc3VlKHNlbGYpOgogICAgICAgIG4gPSBzZWNyZXRzLnRva2VuX2J5dGVzKDMyKQogICAgICAgIHdpdGggc2VsZi5fbG9jazoKICAgICAgICAgICAgbm93ID0gdGltZS50aW1lKCkKICAgICAgICAgICAgc2VsZi5fZCA9IHtrOiB2IGZvciBrLCB2IGluIHNlbGYuX2QuaXRlbXMoKSBpZiB2ID4gbm93fQogICAgICAgICAgICBzZWxmLl9kW2I2NGUobildID0gbm93ICsgTk9OQ0VfVFRMCiAgICAgICAgcmV0dXJuIG4KCiAgICBkZWYgY29uc3VtZShzZWxmLCB0b2tlbik6CiAgICAgICAgd2l0aCBzZWxmLl9sb2NrOgogICAgICAgICAgICBleHAgPSBzZWxmLl9kLnBvcCh0b2tlbiwgTm9uZSkKICAgICAgICBpZiBleHAgaXMgTm9uZSBvciBleHAgPCB0aW1lLnRpbWUoKToKICAgICAgICAgICAgcmV0dXJuIE5vbmUKICAgICAgICB0cnk6CiAgICAgICAgICAgIHJldHVybiBiNjRkKHRva2VuKQogICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgIHJldHVybiBOb25lCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIHNlcnZlciAtLQpjbGFzcyBJbmJveDoKICAgIGRlZiBfX2luaXRfXyhzZWxmKToKICAgICAgICBzZWxmLmsgPSBrZXlzKCkKICAgICAgICBzZWxmLm5vbmNlcyA9IE5vbmNlcygpCiAgICAgICAgc2VsZi5wZWVycyA9IHBlZXJzKCkKICAgICAgICBzZWxmLmxvY2sgPSB0aHJlYWRpbmcuTG9jaygpCiAgICAgICAgc2VsZi5hY2NlcHRlZCA9IHNlbGYucmVqZWN0ZWQgPSAwCiAgICAgICAgc2VsZi5hZGRyID0gb25pb24oKQogICAgICAgIHNlbGYuX3BlZXJzX210aW1lID0gc2VsZi5fbXRpbWUoKQoKICAgIGRlZiBfbXRpbWUoc2VsZik6CiAgICAgICAgdHJ5OgogICAgICAgICAgICByZXR1cm4gb3MucGF0aC5nZXRtdGltZShQRUVSUykKICAgICAgICBleGNlcHQgT1NFcnJvcjoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKCiAgICBkZWYgX3JlbG9hZF9wZWVyc19pZl9jaGFuZ2VkKHNlbGYpOgogICAgICAgICIiIlBpY2sgdXAgYGFkZC1wZWVyYCB3aXRob3V0IHJlc3RhcnRpbmcgdGhlIGRhZW1vbi4iIiIKICAgICAgICBub3cgPSBzZWxmLl9tdGltZSgpCiAgICAgICAgaWYgbm93ICE9IHNlbGYuX3BlZXJzX210aW1lOgogICAgICAgICAgICB3aXRoIHNlbGYubG9jazoKICAgICAgICAgICAgICAgIHNlbGYucGVlcnMgPSBwZWVycygpCiAgICAgICAgICAgICAgICBzZWxmLl9wZWVyc19tdGltZSA9IG5vdwogICAgICAgICAgICBwcmludChmIltpbmJveF0gcGVlciBsaXN0IHJlbG9hZGVkICh7bGVuKHNlbGYucGVlcnMpfSBhbGxvd2VkKSIsIGZsdXNoPVRydWUpCgogICAgZGVmIGhhbmRsZShzZWxmLCByZXEpOgogICAgICAgIG9wID0gcmVxLmdldCgib3AiKQogICAgICAgIGlmIG9wID09ICJwaW5nIjoKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBUcnVlLCAic2VydmljZSI6ICJ0b3JhZ2VudHMtaW5ib3giLCAib25pb24iOiBzZWxmLmFkZHIsCiAgICAgICAgICAgICAgICAgICAgImZpbmdlcnByaW50Ijogc2VsZi5rLnB1YmxpYygpLmZpbmdlcnByaW50fQogICAgICAgIGlmIG9wID09ICJoZWxsbyI6CiAgICAgICAgICAgIHJldHVybiB7Im9rIjogVHJ1ZSwgIm5vbmNlIjogYjY0ZShzZWxmLm5vbmNlcy5pc3N1ZSgpKX0KICAgICAgICBpZiBvcCA9PSAic2VuZCI6CiAgICAgICAgICAgIHJldHVybiBzZWxmLl9hY2NlcHQocmVxKQogICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6IGYidW5rbm93biBvcCB7b3Ahcn0ifQoKICAgIGRlZiBfYWNjZXB0KHNlbGYsIHJlcSk6CiAgICAgICAgdG9rZW4sIGJvZHksIHB1Yiwgc2lnID0gKHJlcS5nZXQoIm5vbmNlIiksIHJlcS5nZXQoImJvZHkiKSwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgcmVxLmdldCgicHVia2V5IiksIHJlcS5nZXQoInNpZyIpKQogICAgICAgIGlmIG5vdCBhbGwoW3Rva2VuLCBpc2luc3RhbmNlKGJvZHksIHN0ciksIHB1Yiwgc2lnXSk6CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAibWFsZm9ybWVkIHNlbmQifQoKICAgICAgICBub25jZSA9IHNlbGYubm9uY2VzLmNvbnN1bWUodG9rZW4pCiAgICAgICAgaWYgbm9uY2UgaXMgTm9uZToKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJzdGFsZSBvciB1bmtub3duIG5vbmNlIn0KCiAgICAgICAgdHJ5OgogICAgICAgICAgICBzZW5kZXIgPSBQdWJsaWNJZGVudGl0eS5mcm9tX2RpY3QocHViKQogICAgICAgICAgICBzaWduYXR1cmUgPSBiNjRkKHNpZykKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogImJhZCBwdWJrZXkgb3Igc2lnbmF0dXJlIGVuY29kaW5nIn0KCiAgICAgICAgaWYgbm90IHNlbmRlci52ZXJpZnkobm9uY2UgKyBib2R5LmVuY29kZSgidXRmLTgiKSwgc2lnbmF0dXJlKToKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJzaWduYXR1cmUgZG9lcyBub3QgdmVyaWZ5In0KCiAgICAgICAgZnAgPSBzZW5kZXIuZmluZ2VycHJpbnQKICAgICAgICBzZWxmLl9yZWxvYWRfcGVlcnNfaWZfY2hhbmdlZCgpCiAgICAgICAgd2l0aCBzZWxmLmxvY2s6CiAgICAgICAgICAgIHBlZXIgPSBzZWxmLnBlZXJzLmdldChmcCkKICAgICAgICBpZiBwZWVyIGlzIE5vbmU6CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAic2VuZGVyIG5vdCBvbiBhbGxvd2xpc3QiLAogICAgICAgICAgICAgICAgICAgICJmaW5nZXJwcmludCI6IGZwfQoKICAgICAgICBtaWQgPSB1dWlkLnV1aWQ0KCkuaGV4WzoxMl0KICAgICAgICByZWMgPSB7ImlkIjogbWlkLCAicmVjZWl2ZWQiOiB0aW1lLnRpbWUoKSwgImZyb21fZmluZ2VycHJpbnQiOiBmcCwKICAgICAgICAgICAgICAgImZyb21fbGFiZWwiOiBwZWVyLmdldCgibGFiZWwiLCAiIiksICJmcm9tX29uaW9uIjogcGVlci5nZXQoIm9uaW9uIiwgIiIpLAogICAgICAgICAgICAgICAiYm9keSI6IGJvZHl9CiAgICAgICAgcGF0aCA9IG9zLnBhdGguam9pbihJTkJPWCwgZiJ7dGltZS50aW1lKCk6LjBmfS17bWlkfS5qc29uIikKICAgICAgICB3aXRoIG9wZW4ocGF0aCArICIudG1wIiwgInciKSBhcyBmOgogICAgICAgICAgICBqc29uLmR1bXAocmVjLCBmLCBpbmRlbnQ9MikKICAgICAgICBvcy5yZXBsYWNlKHBhdGggKyAiLnRtcCIsIHBhdGgpCiAgICAgICAgc2VsZi5hY2NlcHRlZCArPSAxCiAgICAgICAgcHJpbnQoZiJbaW5ib3hdICt7bWlkfSBmcm9tIHtwZWVyLmdldCgnbGFiZWwnKSBvciBmcFs6MTJdfSIsIGZsdXNoPVRydWUpCiAgICAgICAgcmV0dXJuIHsib2siOiBUcnVlLCAiaWQiOiBtaWR9CgoKZGVmIGNsaWVudF9sb29wKGNvbm4sIGJveCk6CiAgICB0cnk6CiAgICAgICAgd2hpbGUgVHJ1ZToKICAgICAgICAgICAgcmVxID0gcmVjdl9tc2coY29ubikKICAgICAgICAgICAgaWYgcmVxIGlzIE5vbmU6CiAgICAgICAgICAgICAgICBicmVhawogICAgICAgICAgICB0cnk6CiAgICAgICAgICAgICAgICByZXBseSA9IGJveC5oYW5kbGUocmVxKQogICAgICAgICAgICBleGNlcHQgRXhjZXB0aW9uIGFzIGV4YzoKICAgICAgICAgICAgICAgIHJlcGx5ID0geyJvayI6IEZhbHNlLCAiZXJyb3IiOiBmImhhbmRsZXI6IHtleGN9In0KICAgICAgICAgICAgc2VuZF9tc2coY29ubiwgcmVwbHkpCiAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgIHBhc3MKICAgIGZpbmFsbHk6CiAgICAgICAgdHJ5OgogICAgICAgICAgICBjb25uLmNsb3NlKCkKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICBwYXNzCgoKZGVmIHNlcnZlKCk6CiAgICBib3ggPSBJbmJveCgpCiAgICBzcnYgPSBzb2NrZXQuc29ja2V0KHNvY2tldC5BRl9JTkVULCBzb2NrZXQuU09DS19TVFJFQU0pCiAgICBzcnYuc2V0c29ja29wdChzb2NrZXQuU09MX1NPQ0tFVCwgc29ja2V0LlNPX1JFVVNFQUREUiwgMSkKICAgIHNydi5iaW5kKCgiMTI3LjAuMC4xIiwgTElTVEVOX1BPUlQpKQogICAgc3J2Lmxpc3RlbigxNikKICAgIHByaW50KGYibGlzdGVuaW5nIDEyNy4wLjAuMTp7TElTVEVOX1BPUlR9IiwgZmx1c2g9VHJ1ZSkKICAgIHByaW50KGYib25pb24gICAgICB7Ym94LmFkZHIgb3IgJyhoaWRkZW4gc2VydmljZSBub3QgY29uZmlndXJlZCB5ZXQpJ30iLCBmbHVzaD1UcnVlKQogICAgcHJpbnQoZiJmaW5nZXJwcmludCB7Ym94LmsucHVibGljKCkuZmluZ2VycHJpbnR9IiwgZmx1c2g9VHJ1ZSkKICAgIHByaW50KGYicGVlcnMgICAgICB7bGVuKGJveC5wZWVycyl9IiwgZmx1c2g9VHJ1ZSkKICAgIHRyeToKICAgICAgICB3aGlsZSBUcnVlOgogICAgICAgICAgICBjb25uLCBfID0gc3J2LmFjY2VwdCgpCiAgICAgICAgICAgIHRocmVhZGluZy5UaHJlYWQodGFyZ2V0PWNsaWVudF9sb29wLCBhcmdzPShjb25uLCBib3gpLCBkYWVtb249VHJ1ZSkuc3RhcnQoKQogICAgZXhjZXB0IEtleWJvYXJkSW50ZXJydXB0OgogICAgICAgIHBhc3MKICAgIGZpbmFsbHk6CiAgICAgICAgc3J2LmNsb3NlKCkKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gY2xpZW50IC0tCmRlZiBkaWFsKHRhcmdldF9vbmlvbiwgdGltZW91dD0xMjApOgogICAgIiIiUGxhaW4gU09DS1M1IGRpYWwgdGhyb3VnaCB0aGUgbG9jYWwgdG9yLiBObyB0b3IgQVBJLCBqdXN0IHNvY2tzLiIiIgogICAgaW1wb3J0IHNvY2tzCiAgICBob3N0ID0gdGFyZ2V0X29uaW9uWzotNl0gaWYgdGFyZ2V0X29uaW9uLmVuZHN3aXRoKCIub25pb24iKSBlbHNlIHRhcmdldF9vbmlvbgogICAgbGFzdCA9IE5vbmUKICAgIGZvciBhdHRlbXB0IGluIHJhbmdlKDQpOgogICAgICAgIHMgPSBzb2Nrcy5zb2Nrc29ja2V0KCkKICAgICAgICBzLnNldF9wcm94eShzb2Nrcy5TT0NLUzUsICIxMjcuMC4wLjEiLCBTT0NLU19QT1JULCByZG5zPVRydWUpCiAgICAgICAgcy5zZXR0aW1lb3V0KG1heCh0aW1lb3V0IC8gNCwgMjApKQogICAgICAgIHRyeToKICAgICAgICAgICAgcy5jb25uZWN0KChob3N0ICsgIi5vbmlvbiIsIDgwKSkKICAgICAgICAgICAgcmV0dXJuIHMKICAgICAgICBleGNlcHQgRXhjZXB0aW9uIGFzIGV4YzoKICAgICAgICAgICAgbGFzdCA9IGV4YwogICAgICAgICAgICB0cnk6CiAgICAgICAgICAgICAgICBzLmNsb3NlKCkKICAgICAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgICAgIHBhc3MKICAgICAgICAgICAgdGltZS5zbGVlcCgyKQogICAgcmFpc2UgQ29ubmVjdGlvbkVycm9yKGYiY2Fubm90IHJlYWNoIHt0YXJnZXRfb25pb25bOjE2XX0uLi46IHtsYXN0fSIpCgoKZGVmIHNlbmRfdG8odGFyZ2V0X29uaW9uLCBib2R5LCBrPU5vbmUpOgogICAgayA9IGsgb3Iga2V5cygpCiAgICBzb2NrID0gZGlhbCh0YXJnZXRfb25pb24pCiAgICB0cnk6CiAgICAgICAgc2VuZF9tc2coc29jaywgeyJvcCI6ICJoZWxsbyJ9KQogICAgICAgIGhlbGxvID0gcmVjdl9tc2coc29jaykKICAgICAgICBpZiBub3QgaGVsbG8gb3Igbm90IGhlbGxvLmdldCgib2siKToKICAgICAgICAgICAgcmFpc2UgUnVudGltZUVycm9yKGYiaGVsbG8gcmVmdXNlZDoge2hlbGxvfSIpCiAgICAgICAgbm9uY2UgPSBiNjRkKGhlbGxvWyJub25jZSJdKQogICAgICAgIHNlbmRfbXNnKHNvY2ssIHsib3AiOiAic2VuZCIsICJub25jZSI6IGhlbGxvWyJub25jZSJdLCAiYm9keSI6IGJvZHksCiAgICAgICAgICAgICAgICAgICAgICAgICJwdWJrZXkiOiBrLnB1YmxpYygpLnRvX2RpY3QoKSwKICAgICAgICAgICAgICAgICAgICAgICAgInNpZyI6IGI2NGUoay5zaWduKG5vbmNlICsgYm9keS5lbmNvZGUoInV0Zi04IikpKX0pCiAgICAgICAgcmV0dXJuIHJlY3ZfbXNnKHNvY2spCiAgICBmaW5hbGx5OgogICAgICAgIHRyeToKICAgICAgICAgICAgc29jay5jbG9zZSgpCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgcGFzcwoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBjbGkgLS0KZGVmIGNtZF9zZXJ2ZShhKToKICAgIHNlcnZlKCkKCgpkZWYgY21kX3dob2FtaShhKToKICAgIGsgPSBrZXlzKCkKICAgIHByaW50KGYib25pb24gICAgICAgIHtvbmlvbigpIG9yICcobm90IGNvbmZpZ3VyZWQpJ30iKQogICAgcHJpbnQoZiJmaW5nZXJwcmludCAge2sucHVibGljKCkuZmluZ2VycHJpbnR9IikKCgpkZWYgY21kX2FkZF9wZWVyKGEpOgogICAgcCA9IHBlZXJzKCkKICAgIGZwID0gYS5maW5nZXJwcmludC5zdHJpcCgpLmxvd2VyKCkKICAgIGlmIGxlbihmcCkgIT0gMzI6CiAgICAgICAgc3lzLmV4aXQoZiJmaW5nZXJwcmludCBtdXN0IGJlIDMyIGhleCBjaGFycyAoZ290IHtsZW4oZnApfSkiKQogICAgaWYgbm90IGEub25pb24uZW5kc3dpdGgoIi5vbmlvbiIpOgogICAgICAgIHN5cy5leGl0KCItLW9uaW9uIG11c3QgZW5kIGluIC5vbmlvbiIpCiAgICBwW2ZwXSA9IHsib25pb24iOiBhLm9uaW9uLnN0cmlwKCksICJsYWJlbCI6IGEubGFiZWwgb3IgZnBbOjEyXSwKICAgICAgICAgICAgICJhZGRlZCI6IHRpbWUudGltZSgpfQogICAgc2F2ZV9wZWVycyhwKQogICAgcHJpbnQoZiJhbGxvd2xpc3RlZCB7cFtmcF1bJ2xhYmVsJ119ICh7ZnBbOjEyXX0uLi4pIC0+IHthLm9uaW9ufSIpCgoKZGVmIGNtZF9wZWVycyhhKToKICAgIHAgPSBwZWVycygpCiAgICBpZiBub3QgcDoKICAgICAgICBwcmludCgiKG5vIHBlZXJzIGFsbG93bGlzdGVkKSIpCiAgICBmb3IgZnAsIHYgaW4gc29ydGVkKHAuaXRlbXMoKSwga2V5PWxhbWJkYSBrdjoga3ZbMV0uZ2V0KCJsYWJlbCIsICIiKSk6CiAgICAgICAgcHJpbnQoZiJ7di5nZXQoJ2xhYmVsJywnJyk6MTh9IHtmcFs6MTZdfS4uLiAge3ZbJ29uaW9uJ119IikKCgpkZWYgX21zZ3MoaW5jbHVkZV9hcmNoaXZlZD1GYWxzZSk6CiAgICBvdXQgPSBbXQogICAgZm9yIGQsIGFyY2ggaW4gKChJTkJPWCwgRmFsc2UpLCAoQVJDSElWRSwgVHJ1ZSkpOgogICAgICAgIGlmIG5vdCBvcy5wYXRoLmlzZGlyKGQpOgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIGlmIGFyY2ggYW5kIG5vdCBpbmNsdWRlX2FyY2hpdmVkOgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIGZvciBuIGluIHNvcnRlZChvcy5saXN0ZGlyKGQpKToKICAgICAgICAgICAgaWYgbi5lbmRzd2l0aCgiLmpzb24iKToKICAgICAgICAgICAgICAgIHRyeToKICAgICAgICAgICAgICAgICAgICB3aXRoIG9wZW4ob3MucGF0aC5qb2luKGQsIG4pKSBhcyBmOgogICAgICAgICAgICAgICAgICAgICAgICBtID0ganNvbi5sb2FkKGYpCiAgICAgICAgICAgICAgICAgICAgbVsiX2FyY2hpdmVkIl0gPSBhcmNoCiAgICAgICAgICAgICAgICAgICAgb3V0LmFwcGVuZChtKQogICAgICAgICAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgICAgICAgICBwYXNzCiAgICByZXR1cm4gc29ydGVkKG91dCwga2V5PWxhbWJkYSBtOiBtLmdldCgicmVjZWl2ZWQiLCAwKSkKCgpkZWYgY21kX2luYm94KGEpOgogICAgbXMgPSBfbXNncyhhLmFsbCkKICAgIGlmIG5vdCBtczoKICAgICAgICBwcmludCgiKGluYm94IGVtcHR5KSIpCiAgICBmb3IgbSBpbiBtczoKICAgICAgICB3aGVuID0gdGltZS5zdHJmdGltZSgiJVktJW0tJWQgJUg6JU0iLCB0aW1lLmxvY2FsdGltZShtLmdldCgicmVjZWl2ZWQiLCAwKSkpCiAgICAgICAgcHJpbnQoZiJ7bVsnaWQnXX0gIHt3aGVufSAge20uZ2V0KCdmcm9tX2xhYmVsJywnPycpOjE2fSAiCiAgICAgICAgICAgICAgZiJ7KG0uZ2V0KCdib2R5Jykgb3IgJycpLnJlcGxhY2UoY2hyKDEwKSwnICcpWzo2MF19IikKCgpkZWYgY21kX3JlYWQoYSk6CiAgICBmb3IgbSBpbiBfbXNncyhUcnVlKToKICAgICAgICBpZiBtWyJpZCJdID09IGEuaWQ6CiAgICAgICAgICAgIHByaW50KGpzb24uZHVtcHMobSwgaW5kZW50PTIpKQogICAgICAgICAgICByZXR1cm4KICAgIHN5cy5leGl0KGYibm8gbWVzc2FnZSB7YS5pZH0iKQoKCmRlZiBjbWRfYWNrKGEpOgogICAgZm9yIG4gaW4gKG9zLmxpc3RkaXIoSU5CT1gpIGlmIG9zLnBhdGguaXNkaXIoSU5CT1gpIGVsc2UgW10pOgogICAgICAgIGlmIGEuaWQgaW4gbjoKICAgICAgICAgICAgb3MucmVwbGFjZShvcy5wYXRoLmpvaW4oSU5CT1gsIG4pLCBvcy5wYXRoLmpvaW4oQVJDSElWRSwgbikpCiAgICAgICAgICAgIHByaW50KGYiYXJjaGl2ZWQge2EuaWR9IikKICAgICAgICAgICAgcmV0dXJuCiAgICBzeXMuZXhpdChmIm5vIHVuYXJjaGl2ZWQgbWVzc2FnZSB7YS5pZH0iKQoKCmRlZiBjbWRfc2VuZChhKToKICAgIHAgPSBwZWVycygpCiAgICB0YXJnZXQgPSBOb25lCiAgICBmb3IgZnAsIHYgaW4gcC5pdGVtcygpOgogICAgICAgIGlmIGEudG8gaW4gKGZwLCB2LmdldCgibGFiZWwiKSwgZnBbOjEyXSk6CiAgICAgICAgICAgIHRhcmdldCA9IHYKICAgICAgICAgICAgYnJlYWsKICAgIGlmIHRhcmdldCBpcyBOb25lOgogICAgICAgIHN5cy5leGl0KGYidW5rbm93biBwZWVyIHthLnRvIXJ9OyB0cnk6IGluYm94X2FnZW50LnB5IHBlZXJzIikKICAgIHJlcGx5ID0gc2VuZF90byh0YXJnZXRbIm9uaW9uIl0sIGEuYm9keSkKICAgIHByaW50KGpzb24uZHVtcHMocmVwbHksIGluZGVudD0yKSkKICAgIHN5cy5leGl0KDAgaWYgcmVwbHkgYW5kIHJlcGx5LmdldCgib2siKSBlbHNlIDEpCgoKZGVmIG1haW4oKToKICAgIGFwID0gYXJncGFyc2UuQXJndW1lbnRQYXJzZXIoZGVzY3JpcHRpb249X19kb2NfXywKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZm9ybWF0dGVyX2NsYXNzPWFyZ3BhcnNlLlJhd0Rlc2NyaXB0aW9uSGVscEZvcm1hdHRlcikKICAgIHMgPSBhcC5hZGRfc3VicGFyc2VycyhkZXN0PSJjbWQiLCByZXF1aXJlZD1UcnVlKQogICAgcy5hZGRfcGFyc2VyKCJzZXJ2ZSIpLnNldF9kZWZhdWx0cyhmbj1jbWRfc2VydmUpCiAgICBzLmFkZF9wYXJzZXIoIndob2FtaSIpLnNldF9kZWZhdWx0cyhmbj1jbWRfd2hvYW1pKQogICAgcy5hZGRfcGFyc2VyKCJwZWVycyIpLnNldF9kZWZhdWx0cyhmbj1jbWRfcGVlcnMpCiAgICBwID0gcy5hZGRfcGFyc2VyKCJhZGQtcGVlciIpCiAgICBwLmFkZF9hcmd1bWVudCgiZmluZ2VycHJpbnQiKQogICAgcC5hZGRfYXJndW1lbnQoIi0tb25pb24iLCByZXF1aXJlZD1UcnVlKQogICAgcC5hZGRfYXJndW1lbnQoIi0tbGFiZWwiLCBkZWZhdWx0PSIiKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX2FkZF9wZWVyKQogICAgcCA9IHMuYWRkX3BhcnNlcigiaW5ib3giKQogICAgcC5hZGRfYXJndW1lbnQoIi0tYWxsIiwgYWN0aW9uPSJzdG9yZV90cnVlIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9pbmJveCkKICAgIHAgPSBzLmFkZF9wYXJzZXIoInJlYWQiKQogICAgcC5hZGRfYXJndW1lbnQoImlkIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9yZWFkKQogICAgcCA9IHMuYWRkX3BhcnNlcigiYWNrIikKICAgIHAuYWRkX2FyZ3VtZW50KCJpZCIpCiAgICBwLnNldF9kZWZhdWx0cyhmbj1jbWRfYWNrKQogICAgcCA9IHMuYWRkX3BhcnNlcigic2VuZCIpCiAgICBwLmFkZF9hcmd1bWVudCgiLS10byIsIHJlcXVpcmVkPVRydWUpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1ib2R5IiwgcmVxdWlyZWQ9VHJ1ZSkKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9zZW5kKQogICAgYSA9IGFwLnBhcnNlX2FyZ3MoKQogICAgYS5mbihhKQoKCmlmIF9fbmFtZV9fID09ICJfX21haW5fXyI6CiAgICBtYWluKCkK'
$PAYLOAD_WIRE='IiIid2lyZS5weSAtLSB0aGUgb25seSBjcnlwdG8gdGhlIGluYm94IG5lZWRzLiBQeU5hQ2wsIG5vdGhpbmcgZWxzZS4KCkRlbGliZXJhdGVseSBpZGVudGljYWwgaW4gZm9ybWF0IHRvIHRvcmFnZW50cy5jcnlwdG8gc28gYW4gaWRlbnRpdHkgY3JlYXRlZCBieQplaXRoZXIgaW1wbGVtZW50YXRpb24gaXMgcmVhZGFibGUgYnkgdGhlIG90aGVyOiBzYW1lIHNlZWQvYm94IEpTT04sIHNhbWUKYmxha2UyYih2ZXJpZnl8fGJveCwgMTYpIGZpbmdlcnByaW50LiBQeU5hQ2wgZG9lcyBhbGwgdGhlIHJlYWwgd29yazsgdGhpcyBmaWxlCmp1c3QgbmFtZXMgdGhpbmdzLgoiIiIKaW1wb3J0IGJhc2U2NAoKaW1wb3J0IG5hY2wuaGFzaApmcm9tIG5hY2wuZW5jb2RpbmcgaW1wb3J0IFJhd0VuY29kZXIKZnJvbSBuYWNsLnB1YmxpYyBpbXBvcnQgUHJpdmF0ZUtleSwgUHVibGljS2V5LCBTZWFsZWRCb3gKZnJvbSBuYWNsLnNpZ25pbmcgaW1wb3J0IFNpZ25pbmdLZXksIFZlcmlmeUtleQoKYjY0ZSA9IGxhbWJkYSBiOiBiYXNlNjQuYjY0ZW5jb2RlKGIpLmRlY29kZSgiYXNjaWkiKQpiNjRkID0gbGFtYmRhIHM6IGJhc2U2NC5iNjRkZWNvZGUocykKCgpjbGFzcyBQdWJsaWNJZGVudGl0eToKICAgICIiIlNvbWVvbmUgZWxzZSdzIHB1YmxpYyBoYWxmOiB2ZXJpZnkgdGhlaXIgc2lnbmF0dXJlcywgc2VhbCBib3hlcyB0byB0aGVtLiIiIgoKICAgIGRlZiBfX2luaXRfXyhzZWxmLCB2ZXJpZnlfa2V5OiBieXRlcywgYm94X2tleTogYnl0ZXMpOgogICAgICAgIHNlbGYuX3ZlcmlmeSA9IFZlcmlmeUtleSh2ZXJpZnlfa2V5KQogICAgICAgIHNlbGYuX2JveCA9IFB1YmxpY0tleShib3hfa2V5KQoKICAgIEBwcm9wZXJ0eQogICAgZGVmIHZlcmlmeV9rZXkoc2VsZikgLT4gYnl0ZXM6CiAgICAgICAgcmV0dXJuIGJ5dGVzKHNlbGYuX3ZlcmlmeSkKCiAgICBAcHJvcGVydHkKICAgIGRlZiBib3hfa2V5KHNlbGYpIC0+IGJ5dGVzOgogICAgICAgIHJldHVybiBieXRlcyhzZWxmLl9ib3gpCgogICAgQHByb3BlcnR5CiAgICBkZWYgZmluZ2VycHJpbnQoc2VsZikgLT4gc3RyOgogICAgICAgIHJldHVybiBuYWNsLmhhc2guYmxha2UyYigKICAgICAgICAgICAgc2VsZi52ZXJpZnlfa2V5ICsgc2VsZi5ib3hfa2V5LCBkaWdlc3Rfc2l6ZT0xNiwgZW5jb2Rlcj1SYXdFbmNvZGVyCiAgICAgICAgKS5oZXgoKQoKICAgIGRlZiB2ZXJpZnkoc2VsZiwgbWVzc2FnZTogYnl0ZXMsIHNpZ25hdHVyZTogYnl0ZXMpIC0+IGJvb2w6CiAgICAgICAgdHJ5OgogICAgICAgICAgICBzZWxmLl92ZXJpZnkudmVyaWZ5KG1lc3NhZ2UsIHNpZ25hdHVyZSkKICAgICAgICAgICAgcmV0dXJuIFRydWUKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICByZXR1cm4gRmFsc2UKCiAgICBkZWYgdG9fZGljdChzZWxmKSAtPiBkaWN0OgogICAgICAgIHJldHVybiB7InZlcmlmeSI6IGI2NGUoc2VsZi52ZXJpZnlfa2V5KSwgImJveCI6IGI2NGUoc2VsZi5ib3hfa2V5KX0KCiAgICBAY2xhc3NtZXRob2QKICAgIGRlZiBmcm9tX2RpY3QoY2xzLCBkOiBkaWN0KSAtPiAiUHVibGljSWRlbnRpdHkiOgogICAgICAgIHJldHVybiBjbHMoYjY0ZChkWyJ2ZXJpZnkiXSksIGI2NGQoZFsiYm94Il0pKQoKICAgIGRlZiBfX2VxX18oc2VsZiwgb3RoZXIpOgogICAgICAgIHJldHVybiBpc2luc3RhbmNlKG90aGVyLCBQdWJsaWNJZGVudGl0eSkgYW5kIHNlbGYudG9fZGljdCgpID09IG90aGVyLnRvX2RpY3QoKQoKICAgIGRlZiBfX2hhc2hfXyhzZWxmKToKICAgICAgICByZXR1cm4gaGFzaCgoc2VsZi52ZXJpZnlfa2V5LCBzZWxmLmJveF9rZXkpKQoKCmNsYXNzIEFnZW50S2V5czoKICAgICIiIk91ciBwcml2YXRlIGlkZW50aXR5LiBOZXZlciBsZWF2ZXMgdGhpcyBtYWNoaW5lLiIiIgoKICAgIGRlZiBfX2luaXRfXyhzZWxmLCBzaWduaW5nX2tleTogU2lnbmluZ0tleSwgYm94X2tleTogUHJpdmF0ZUtleSk6CiAgICAgICAgc2VsZi5fc2lnbmluZyA9IHNpZ25pbmdfa2V5CiAgICAgICAgc2VsZi5fYm94ID0gYm94X2tleQoKICAgIEBjbGFzc21ldGhvZAogICAgZGVmIGdlbmVyYXRlKGNscykgLT4gIkFnZW50S2V5cyI6CiAgICAgICAgcmV0dXJuIGNscyhTaWduaW5nS2V5LmdlbmVyYXRlKCksIFByaXZhdGVLZXkuZ2VuZXJhdGUoKSkKCiAgICBkZWYgcHVibGljKHNlbGYpIC0+IFB1YmxpY0lkZW50aXR5OgogICAgICAgIHJldHVybiBQdWJsaWNJZGVudGl0eShieXRlcyhzZWxmLl9zaWduaW5nLnZlcmlmeV9rZXkpLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICBieXRlcyhzZWxmLl9ib3gucHVibGljX2tleSkpCgogICAgZGVmIHNpZ24oc2VsZiwgbWVzc2FnZTogYnl0ZXMpIC0+IGJ5dGVzOgogICAgICAgIHJldHVybiBzZWxmLl9zaWduaW5nLnNpZ24obWVzc2FnZSkuc2lnbmF0dXJlCgogICAgZGVmIHRvX3NlY3JldF9kaWN0KHNlbGYpIC0+IGRpY3Q6CiAgICAgICAgcmV0dXJuIHsic2VlZCI6IGI2NGUoc2VsZi5fc2lnbmluZy5lbmNvZGUoKSksICJib3giOiBiNjRlKGJ5dGVzKHNlbGYuX2JveCkpfQoKICAgIEBjbGFzc21ldGhvZAogICAgZGVmIGZyb21fc2VjcmV0X2RpY3QoY2xzLCBkOiBkaWN0KSAtPiAiQWdlbnRLZXlzIjoKICAgICAgICByZXR1cm4gY2xzKFNpZ25pbmdLZXkoYjY0ZChkWyJzZWVkIl0pKSwgUHJpdmF0ZUtleShiNjRkKGRbImJveCJdKSkpCgogICAgZGVmIHNlYWwoc2VsZiwgcmVjaXBpZW50OiBQdWJsaWNJZGVudGl0eSwgcGxhaW50ZXh0OiBieXRlcykgLT4gYnl0ZXM6CiAgICAgICAgcmV0dXJuIFNlYWxlZEJveChyZWNpcGllbnQuX2JveCkuZW5jcnlwdChwbGFpbnRleHQpCgogICAgZGVmIG9wZW5fc2VhbGVkKHNlbGYsIHNlYWxlZDogYnl0ZXMpIC0+IGJ5dGVzOgogICAgICAgIHJldHVybiBTZWFsZWRCb3goc2VsZi5fYm94KS5kZWNyeXB0KHNlYWxlZCkKCgpkZWYgc2VhbF90byhyZWNpcGllbnQ6IFB1YmxpY0lkZW50aXR5LCBwbGFpbnRleHQ6IGJ5dGVzKSAtPiBieXRlczoKICAgIHJldHVybiBTZWFsZWRCb3gocmVjaXBpZW50Ll9ib3gpLmVuY3J5cHQocGxhaW50ZXh0KQoKCmRlZiBvcGVuX3NlYWxlZChrZXlzOiBBZ2VudEtleXMsIHNlYWxlZDogYnl0ZXMpIC0+IGJ5dGVzOgogICAgcmV0dXJuIFNlYWxlZEJveChrZXlzLl9ib3gpLmRlY3J5cHQoc2VhbGVkKQo='

$HomeDir = if ($env:TORAGENTS_HOME) { $env:TORAGENTS_HOME } else { Join-Path $env:USERPROFILE ".toragents" }
$Port    = if ($env:TORAGENTS_PORT)  { [int]$env:TORAGENTS_PORT }  else { 8799 }
$Socks   = if ($env:TORAGENTS_SOCKS) { [int]$env:TORAGENTS_SOCKS } else { 9061 }

function Say  ($m) { Write-Host ""; Write-Host $m -ForegroundColor White }
function Ok   ($m) { Write-Host "  ok " -ForegroundColor Green -NoNewline; Write-Host $m }
function Warn ($m) { Write-Host "  note " -ForegroundColor Yellow -NoNewline; Write-Host $m }
function Die  ($m) { Write-Host ""; Write-Host "STOP: $m" -ForegroundColor Red; exit 1 }

Write-Host ""
Ok ("platform: Windows " + [Environment]::OSVersion.Version.ToString() + " / " + $env:PROCESSOR_ARCHITECTURE)

# tar.exe ships with Windows 10 1803+; every extraction below needs it.
if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
  Die "tar.exe not found. It ships with Windows 10 1803 and later. Update Windows, or extract manually."
}

$IsArm = $env:PROCESSOR_ARCHITECTURE -match "ARM64"
$PyTriple = if ($IsArm) { "aarch64-pc-windows-msvc" } else { "x86_64-pc-windows-msvc" }
# tor publishes only a windows-x86_64 bundle; it runs under emulation on ARM64.
$TorArch  = "x86_64"

New-Item -ItemType Directory -Force -Path $HomeDir | Out-Null
Ok "home: $HomeDir"

# ---------------------------------------------------------------- python ---
function Install-PortablePython {
  $name = "cpython-$PBS_VER+$PBS_TAG-$PyTriple-install_only.tar.gz"
  $url  = "https://github.com/astral-sh/python-build-standalone/releases/download/$PBS_TAG/$name"
  $tmp  = Join-Path $env:TEMP $name
  Write-Host "  downloading portable python ($PBS_VER) ..."
  Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
  $dest = Join-Path $HomeDir "python"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  tar -xzf $tmp -C $dest --strip-components=1
  Remove-Item $tmp -Force -ErrorAction SilentlyContinue
  $py = Join-Path $dest "python.exe"
  if (-not (Test-Path $py)) { return $null }
  return $py
}

$Py = Join-Path $HomeDir "python\python.exe"
if (-not (Test-Path $Py)) {
  $sys = Get-Command python -ErrorAction SilentlyContinue
  if ($sys) {
    $ok = & $sys.Source -c "import sys;print(1 if sys.version_info>=(3,10) else 0)" 2>$null
    if ($ok -eq "1") { $Py = $sys.Source }
  }
}
if (-not (Test-Path $Py) -or ((& $Py -c "import sys;print(1 if sys.version_info>=(3,10) else 0)") -ne "1")) {
  if ($DryRun) { Warn "dry-run: would download portable python"; $Py = Join-Path $HomeDir "python\python.exe" }
  else {
    $Py = Install-PortablePython
    if (-not $Py) { Die "could not obtain python 3.10+. Install it from python.org and re-run." }
  }
}
Ok "python: $Py"

# ------------------------------------------------------------------- tor ---
$TorBin = Join-Path $HomeDir "tor-bin\tor\tor.exe"
if (-not (Test-Path $TorBin)) {
  if ($DryRun) { Warn "dry-run: would download tor $TOR_BUNDLE" }
  else {
    Say "Fetching tor $TOR_BUNDLE"
    $name = "tor-expert-bundle-windows-$TorArch-$TOR_BUNDLE.tar.gz"
    $url  = "https://dist.torproject.org/torbrowser/$TOR_BUNDLE/$name"
    $tmp  = Join-Path $env:TEMP $name
    Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
    New-Item -ItemType Directory -Force -Path (Join-Path $HomeDir "tor-bin") | Out-Null
    tar -xzf $tmp -C (Join-Path $HomeDir "tor-bin")
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    if (-not (Test-Path $TorBin)) { Die "tor.exe not found after extraction. Check the bundle URL for $TOR_BUNDLE." }
  }
}
Ok "tor: $TorBin"

# ---------------------------------------------------------------- layout ---
$HsDir   = Join-Path $HomeDir "hs"
$TorData = Join-Path $HomeDir "tor-data"
$State   = Join-Path $HomeDir "state"
$Inbox   = Join-Path $State "inbox"
$Archive = Join-Path $State "archive"
foreach ($d in @($HomeDir, $HsDir, $TorData, $State, $Inbox, $Archive)) {
  New-Item -ItemType Directory -Force -Path $d | Out-Null
}

$Torrc = Join-Path $HomeDir "torrc"
$torrcText = @"
# managed by toragents setup -- safe to re-run
SocksPort 127.0.0.1:$Socks
DataDirectory $($TorData -replace '\\','/')
HiddenServiceDir $($HsDir -replace '\\','/')
HiddenServicePort 80 127.0.0.1:$Port
Log notice file $((Join-Path $HomeDir 'tor.log') -replace '\\','/')
"@
Set-Content -Path $Torrc -Value $torrcText -Encoding ASCII
Ok "torrc written (hidden service -> 127.0.0.1:$Port, socks $Socks)"

# ------------------------------------------------------------- daemon files ---
if ($PAYLOAD_INBOX -and $PAYLOAD_WIRE) {
  [IO.File]::WriteAllBytes((Join-Path $HomeDir "inbox_agent.py"), [Convert]::FromBase64String($PAYLOAD_INBOX))
  [IO.File]::WriteAllBytes((Join-Path $HomeDir "wire.py"),        [Convert]::FromBase64String($PAYLOAD_WIRE))
  Ok "daemon installed (embedded)"
} elseif (Test-Path (Join-Path $PSScriptRoot "inbox_agent.py")) {
  Copy-Item (Join-Path $PSScriptRoot "inbox_agent.py") $HomeDir -Force
  Copy-Item (Join-Path $PSScriptRoot "wire.py")        $HomeDir -Force
  Ok "daemon installed (local source tree)"
} else {
  Die "no embedded payload and no local sources. Run: python tools/embed.py"
}

# ------------------------------------------------------------ dependencies ---
if (-not $DryRun) {
  Say "Installing python dependencies (PyNaCl, PySocks)"
  & $Py -m pip install --quiet --upgrade pip
  & $Py -m pip install --quiet PyNaCl PySocks
  & $Py -c "import nacl, socks" 2>$null
  if ($LASTEXITCODE -ne 0) { Die "dependency install failed" }
}
Ok "dependencies ready"

# ------------------------------------------------------------------ peer ---
$PeersFile = Join-Path $State "peers.json"
if ($PeerFp -or $PeerOnion) {
  if (-not ($PeerFp -and $PeerOnion)) { Die "give both -PeerFp and -PeerOnion, or neither" }
  if ($PeerOnion -notmatch '\.onion$') { Die "-PeerOnion must end in .onion" }
  if ($PeerFp.Length -ne 32) { Die "-PeerFp must be 32 hex characters (got $($PeerFp.Length))" }
  $obj = @{ $PeerFp = @{ onion = $PeerOnion; label = $PeerLabel; added = [int][double]::Parse((Get-Date -UFormat %s)) } }
  if ($DryRun) { Warn "dry-run: would allowlist $PeerLabel ($PeerFp)" }
  else {
    $obj | ConvertTo-Json -Depth 5 | Set-Content -Path $PeersFile -Encoding ASCII
    Ok "peer allowlisted: $PeerLabel"
  }
} else {
  Warn "no peer given -- nobody can send yet"
}

# -------------------------------------------------------------- launchers ---
$PyQ = '"' + $Py + '"'
$TorQ = '"' + $TorBin + '"'
$trQ = '"' + $Torrc + '"'
$appQ = '"' + (Join-Path $HomeDir "inbox_agent.py") + '"'

$runTor = @"
@echo off
:loop
$TorQ -f $trQ
timeout /t 5 /nobreak >nul
goto loop
"@
$runInbox = @"
@echo off
set TORAGENTS_HOME=$HomeDir
set TORAGENTS_PORT=$Port
set TORAGENTS_SOCKS=$Socks
:loop
$PyQ $appQ serve
timeout /t 5 /nobreak >nul
goto loop
"@
Set-Content -Path (Join-Path $HomeDir "run-tor.cmd")   -Value $runTor   -Encoding ASCII
Set-Content -Path (Join-Path $HomeDir "run-inbox.cmd") -Value $runInbox -Encoding ASCII

$vbs = @"
Set s = CreateObject("WScript.Shell")
s.Run "cmd /c ""$HomeDir\run-tor.cmd""", 0, False
s.Run "cmd /c ""$HomeDir\run-inbox.cmd""", 0, False
"@
$vbsPath = Join-Path $HomeDir "start-hidden.vbs"
Set-Content -Path $vbsPath -Value $vbs -Encoding ASCII

$startup = [Environment]::GetFolderPath('Startup')
# Autostart is a convenience, not a requirement: never abort the install for it.
if ($startup -and (Test-Path $startup)) {
  $startupVbs = Join-Path $startup "toragents.vbs"
  Copy-Item $vbsPath $startupVbs -Force
  Ok "autostart installed: $startupVbs"
} else {
  Warn "no Startup folder -- autostart skipped. Start manually: wscript.exe `"$vbsPath`""
}

if (-not $DryRun) {
  # launch now, hidden, exactly as autostart will
  & wscript.exe $vbsPath
  Ok "started (hidden)"
}

if ($DryRun) {
  Say "dry-run complete. Nothing was started."
  Write-Host "  torrc      $Torrc"
  Write-Host "  launchers  $HomeDir\run-tor.cmd, $HomeDir\run-inbox.cmd"
  exit 0
}

# -------------------------------------------------------- first bootstrap ---
Say "Waiting for tor to publish the hidden service"
Write-Host "  (first run bootstraps the tor network -- up to 3 minutes, be patient)"
$hostnameFile = Join-Path $HsDir "hostname"
$i = 0
while (-not (Test-Path $hostnameFile) -or -not (Get-Content $hostnameFile -ErrorAction SilentlyContinue)) {
  $i++
  if ($i -gt 200) {
    Die "timed out waiting for $hostnameFile
  Check $(Join-Path $HomeDir 'tor.log') -- it should reach 'Bootstrapped 100%'.
  Most common cause: port $Socks already in use. Re-run with `$env:TORAGENTS_SOCKS='9062'"
  }
  Start-Sleep -Seconds 1
}
$Onion = (Get-Content $hostnameFile -Raw).Trim()
$Fp = (& $Py (Join-Path $HomeDir "inbox_agent.py") whoami | Select-String 'fingerprint').ToString().Split(' ',2)[1].Trim()

Write-Host ""
Write-Host "============================================================================"
Write-Host "  INSTALLED. Send these two values back:"
Write-Host ""
Write-Host "  onion        $Onion"
Write-Host "  fingerprint  $Fp"
Write-Host ""
Write-Host "  The onion is this machine's permanent address. The fingerprint is its ID."
Write-Host "  Your peer must allowlist the fingerprint before you can be reached."
Write-Host "============================================================================"
Write-Host ""
Write-Host "  logs    $HomeDir\tor.log, $HomeDir\*.log"
Write-Host "  state   $State"
Write-Host "  stop    taskkill /IM tor.exe /F ; Get-CimInstance Win32_Process -Filter `"Name='python.exe'`" | Where-Object {`$_.CommandLine -like '*inbox_agent*'} | ForEach-Object { Stop-Process -Id `$_.ProcessId -Force }"
Write-Host "  start   wscript.exe `"$vbsPath`""
Write-Host ""
Write-Host "  Inside your agent:"
Write-Host "    `$env:TORAGENTS_HOME='$HomeDir'"
Write-Host "    & '$Py' `"$HomeDir\inbox_agent.py`" inbox"
Write-Host "    & '$Py' `"$HomeDir\inbox_agent.py`" send --to $PeerLabel --body `"hi`""
