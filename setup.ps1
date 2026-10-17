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
$PAYLOAD_INBOX='IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwoiIiJpbmJveF9hZ2VudC5weSAtLSBhIHZlcmlmaWVkIG1lc3NhZ2UgaW5ib3ggYmVoaW5kIGEgdG9yIGhpZGRlbiBzZXJ2aWNlLgoKUnVucyBvbiBIRVIgbWFjaGluZS4gTGlzdGVucyBvbiBhIHBsYWluIGxvY2FsaG9zdCBUQ1AgcG9ydDsgdG9yIGZvcndhcmRzIHRoZQpoaWRkZW4gc2VydmljZSB0byBpdC4gU2VydmluZyBuZWVkcyBubyB0b3IgQVBJIGF0IGFsbCAtLSBubyBjb250cm9sIHBvcnQsIG5vCkFERF9PTklPTiwgbm8ga2V5cyB0byBtYW5hZ2UuIE9ubHkgb3V0Ym91bmQgc2VuZHMgdG91Y2ggdG9yLCB2aWEgU09DS1MuCgpTZWN1cml0eSBtb2RlbAogICAgQSBtZXNzYWdlIGlzIGFjY2VwdGVkIG9ubHkgaWYgdGhlIHNlbmRlciBwcm92ZXMgcG9zc2Vzc2lvbiBvZiBhbgogICAgYWxsb3dsaXN0ZWQgRWQyNTUxOSBrZXkgb3ZlciBhIG9uZS11c2Ugbm9uY2UuIFRoZSBzZW5kZXIncyBjbGFpbWVkIG9uaW9uCiAgICBhZGRyZXNzIGlzIG5ldmVyIHRydXN0ZWQgZm9yIHJvdXRpbmcuCgpVc2FnZQogICAgaW5ib3hfYWdlbnQucHkgc2VydmUgICAgICAgICAgICAgICAgIHJ1biB0aGUgZGFlbW9uCiAgICBpbmJveF9hZ2VudC5weSB3aG9hbWkgICAgICAgICAgICAgICAgcHJpbnQgdGhpcyBtYWNoaW5lJ3Mgb25pb24gKyBmaW5nZXJwcmludAogICAgaW5ib3hfYWdlbnQucHkgYWRkLXBlZXIgRlAgLS1vbmlvbiBBIGFsbG93IGEgcGVlciB0byBzZW5kCiAgICBpbmJveF9hZ2VudC5weSBwZWVycwogICAgaW5ib3hfYWdlbnQucHkgaW5ib3gKICAgIGluYm94X2FnZW50LnB5IHJlYWQgPGlkPgogICAgaW5ib3hfYWdlbnQucHkgYWNrIDxpZD4KICAgIGluYm94X2FnZW50LnB5IHNlbmQgLS10byBMQUJFTCAtLWJvZHkgVEVYVAoiIiIKaW1wb3J0IGFyZ3BhcnNlCmltcG9ydCBiYXNlNjQKaW1wb3J0IGpzb24KaW1wb3J0IG9zCmltcG9ydCBzZWNyZXRzCmltcG9ydCBzb2NrZXQKaW1wb3J0IHN5cwppbXBvcnQgdGhyZWFkaW5nCmltcG9ydCB0aW1lCmltcG9ydCB1dWlkCgpmcm9tIHdpcmUgaW1wb3J0IEFnZW50S2V5cywgUHVibGljSWRlbnRpdHkKCkhPTUUgPSBvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX0hPTUUiLCBvcy5wYXRoLmV4cGFuZHVzZXIoIn4vLnRvcmFnZW50cyIpKQojIFRPUkFHRU5UU19TVEFURSB3aW5zIG92ZXIgJEhPTUUvc3RhdGUgc28gdGhpcyBDTEkgY2FuIG9wZXJhdGUgb24gYSBmbGF0IHN0YXRlCiMgZGlyZWN0b3J5ICh0aGUgbGF5b3V0IGxpc3RlbmVyLnB5IHVzZXMgb24gdGhlIGJveCkuIFdpdGhvdXQgaXQgdGhlIHR3byB0b29scwojIGRpc2FncmVlIGFib3V0IHdoZXJlIGlkZW50aXR5Lmpzb24gbGl2ZXMsIGFuZCB3aG9hbWkgc2lsZW50bHkgbWludHMgYQojIHRocm93YXdheSBrZXkgYW5kIHNpZ25zIHdpdGggdGhlIHdyb25nIG9uZS4KU1RBVEUgPSBvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX1NUQVRFIikgb3Igb3MucGF0aC5qb2luKEhPTUUsICJzdGF0ZSIpCklOQk9YID0gb3MucGF0aC5qb2luKFNUQVRFLCAiaW5ib3giKQpBUkNISVZFID0gb3MucGF0aC5qb2luKFNUQVRFLCAiYXJjaGl2ZSIpClBFRVJTID0gb3MucGF0aC5qb2luKFNUQVRFLCAicGVlcnMuanNvbiIpCklERklMRSA9IG9zLnBhdGguam9pbihTVEFURSwgImlkZW50aXR5Lmpzb24iKQpIT1NUTkFNRV9GSUxFID0gb3MucGF0aC5qb2luKEhPTUUsICJocyIsICJob3N0bmFtZSIpCgpDT05GSUcgPSBvcy5wYXRoLmpvaW4oU1RBVEUsICJjb25maWcuanNvbiIpCgoKZGVmIF9pbnN0YWxsZWRfY29uZmlnKCk6CiAgICAiIiJSZWFkIHRoZSBwb3J0cyB0aGUgaW5zdGFsbGVyIGFjdHVhbGx5IGNvbmZpZ3VyZWQuCgogICAgVGhpcyBleGlzdHMgYmVjYXVzZSB0aGUgQ0xJIGFuZCB0aGUgZGFlbW9uIG11c3QgYWdyZWUgb24gdGhlIFNPQ0tTIHBvcnQgYW5kCiAgICB0aGUgZGFlbW9uIGlzIHRoZSBvbmx5IG9uZSB0aGF0IGdldHMgVE9SQUdFTlRTX1NPQ0tTIGZyb20gaXRzIHNlcnZpY2UgdW5pdC4KICAgIFRoZSBvbGQgZmFsbGJhY2sgd2FzIDkwNTAgd2hpbGUgdGhlIGluc3RhbGxlciB3cml0ZXMgOTA2MSwgc28gZXZlcnkgYmFyZQogICAgYHNlbmRgL2BpbmJveGAgZGllZCB3aXRoICJDb25uZWN0aW9uIHJlZnVzZWQiIHVudGlsIHRoZSB1c2VyIGV4cG9ydGVkIHRoZQogICAgdmFyaWFibGUgYnkgaGFuZC4gRW52IHN0aWxsIHdpbnM7IHRoZSByZWNvcmRlZCBjb25maWcgaXMgdGhlIGZhbGxiYWNrLgogICAgIiIiCiAgICB0cnk6CiAgICAgICAgd2l0aCBvcGVuKENPTkZJRykgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIGpzb24ubG9hZChmKQogICAgZXhjZXB0IChPU0Vycm9yLCBWYWx1ZUVycm9yKToKICAgICAgICByZXR1cm4ge30KCgpfY2ZnID0gX2luc3RhbGxlZF9jb25maWcoKQpMSVNURU5fUE9SVCA9IGludChvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX1BPUlQiKSBvciBfY2ZnLmdldCgibG9jYWxfcG9ydCIpIG9yIDg3OTkpClNPQ0tTX1BPUlQgPSBpbnQob3MuZW52aXJvbi5nZXQoIlRPUkFHRU5UU19TT0NLUyIpIG9yIF9jZmcuZ2V0KCJzb2Nrc19wb3J0Iikgb3IgOTA1MCkKTk9OQ0VfVFRMID0gMTgwLjAKCmI2NGUgPSBsYW1iZGEgYjogYmFzZTY0LmI2NGVuY29kZShiKS5kZWNvZGUoImFzY2lpIikKYjY0ZCA9IGxhbWJkYSBzOiBiYXNlNjQuYjY0ZGVjb2RlKHMpCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIHN0YXRlIC0tLQpkZWYgZGlycygpOgogICAgZm9yIGQgaW4gKFNUQVRFLCBJTkJPWCwgQVJDSElWRSk6CiAgICAgICAgb3MubWFrZWRpcnMoZCwgZXhpc3Rfb2s9VHJ1ZSkKCgpkZWYga2V5cyhjcmVhdGU9RmFsc2UpOgogICAgIiIiTG9hZCB0aGUgaWRlbnRpdHkuIFJldHVybnMgTm9uZSBpZiBhYnNlbnQgYW5kIGNyZWF0ZSBpcyBGYWxzZS4KCiAgICBNaW50aW5nIGlzIG9wdC1pbiBvbiBwdXJwb3NlLiBBIHJlYWQtb25seSBjb21tYW5kIHRoYXQgY3JlYXRlcyBhbiBpZGVudGl0eQogICAgaXMgYSBmb290Z3VuOiBpdCB3cml0ZXMgYSBuZXcga2V5LCBhbmQgYW55dGhpbmcgdGhhdCB0aGVuIHNpZ25zIHdpdGggaXQgaXMKICAgIHNpbGVudGx5IHVzaW5nIHRoZSB3cm9uZyBpZGVudGl0eSwgd2hpY2ggdGhlIHBlZXIgcmVqZWN0cyBpbiBhIHdheSB0aGF0CiAgICBsb29rcyBsaWtlIGEgbmV0d29yayBmYXVsdC4KICAgICIiIgogICAgZGlycygpCiAgICBpZiBvcy5wYXRoLmV4aXN0cyhJREZJTEUpOgogICAgICAgIHdpdGggb3BlbihJREZJTEUpIGFzIGY6CiAgICAgICAgICAgIHJldHVybiBBZ2VudEtleXMuZnJvbV9zZWNyZXRfZGljdChqc29uLmxvYWQoZikpCiAgICBpZiBub3QgY3JlYXRlOgogICAgICAgIHJldHVybiBOb25lCiAgICBrID0gQWdlbnRLZXlzLmdlbmVyYXRlKCkKICAgIGZkID0gb3Mub3BlbihJREZJTEUsIG9zLk9fV1JPTkxZIHwgb3MuT19DUkVBVCB8IG9zLk9fVFJVTkMsIDBvNjAwKQogICAgd2l0aCBvcy5mZG9wZW4oZmQsICJ3IikgYXMgZjoKICAgICAgICBqc29uLmR1bXAoay50b19zZWNyZXRfZGljdCgpLCBmKQogICAgcmV0dXJuIGsKCgpkZWYgbmVlZF9rZXlzKCk6CiAgICBrID0ga2V5cygpCiAgICBpZiBrIGlzIE5vbmU6CiAgICAgICAgcHJpbnQoZiJubyBpZGVudGl0eSBhdCB7SURGSUxFfSIsIGZpbGU9c3lzLnN0ZGVycikKICAgICAgICBwcmludCgiICBjcmVhdGUgb25lIHdpdGg6ICBpbmJveF9hZ2VudC5weSBpbml0IiwgZmlsZT1zeXMuc3RkZXJyKQogICAgICAgIHByaW50KCIgICh0aGUgaW5zdGFsbGVyIGRvZXMgdGhpcyBmb3IgeW91OyB3aG9hbWkgbmV2ZXIgd3JpdGVzKSIsCiAgICAgICAgICAgICAgZmlsZT1zeXMuc3RkZXJyKQogICAgICAgIHJhaXNlIFN5c3RlbUV4aXQoMikKICAgIHJldHVybiBrCgoKZGVmIHBlZXJzKCk6CiAgICBpZiBub3Qgb3MucGF0aC5leGlzdHMoUEVFUlMpOgogICAgICAgIHJldHVybiB7fQogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihQRUVSUykgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIGpzb24ubG9hZChmKQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICByZXR1cm4ge30KCgpkZWYgc2F2ZV9wZWVycyhwKToKICAgIGRpcnMoKQogICAgdG1wID0gUEVFUlMgKyAiLnRtcCIKICAgIHdpdGggb3Blbih0bXAsICJ3IikgYXMgZjoKICAgICAgICBqc29uLmR1bXAocCwgZiwgaW5kZW50PTIsIHNvcnRfa2V5cz1UcnVlKQogICAgb3MucmVwbGFjZSh0bXAsIFBFRVJTKQoKCmRlZiBvbmlvbigpOgogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihIT1NUTkFNRV9GSUxFKSBhcyBmOgogICAgICAgICAgICByZXR1cm4gZi5yZWFkKCkuc3RyaXAoKQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICByZXR1cm4gTm9uZQoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIGZyYW1pbmcgLS0KZGVmIHNlbmRfbXNnKHNvY2ssIG9iaik6CiAgICBkYXRhID0ganNvbi5kdW1wcyhvYmopLmVuY29kZSgpCiAgICBzb2NrLnNlbmRhbGwobGVuKGRhdGEpLnRvX2J5dGVzKDQsICJiaWciKSArIGRhdGEpCgoKTUFYX0ZSQU1FID0gMTYgKiAxMDI0ICogMTAyNCAgIyBzYW1lIGNlaWxpbmcgdG9yYWdlbnRzIHVzZXM7IHN0b3BzIGEgaG9zdGlsZSBoZWFkZXIKCgpkZWYgcmVjdl9tc2coc29jayk6CiAgICBoZHIgPSBfcmVhZF9leGFjdChzb2NrLCA0KQogICAgaWYgaGRyIGlzIE5vbmU6CiAgICAgICAgcmV0dXJuIE5vbmUKICAgIG4gPSBpbnQuZnJvbV9ieXRlcyhoZHIsICJiaWciKQogICAgaWYgbiA+IE1BWF9GUkFNRToKICAgICAgICByYWlzZSBWYWx1ZUVycm9yKGYiZGVjbGFyZWQgZnJhbWUge259IGV4Y2VlZHMge01BWF9GUkFNRX0iKQogICAgYm9keSA9IF9yZWFkX2V4YWN0KHNvY2ssIG4pCiAgICBpZiBib2R5IGlzIE5vbmU6CiAgICAgICAgcmV0dXJuIE5vbmUKICAgIHJldHVybiBqc29uLmxvYWRzKGJvZHkuZGVjb2RlKCkpCgoKZGVmIF9yZWFkX2V4YWN0KHNvY2ssIG4pOgogICAgYnVmID0gYiIiCiAgICB3aGlsZSBsZW4oYnVmKSA8IG46CiAgICAgICAgY2h1bmsgPSBzb2NrLnJlY3YobiAtIGxlbihidWYpKQogICAgICAgIGlmIG5vdCBjaHVuazoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKICAgICAgICBidWYgKz0gY2h1bmsKICAgIHJldHVybiBidWYKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gbm9uY2VzIC0tCmNsYXNzIE5vbmNlczoKICAgIGRlZiBfX2luaXRfXyhzZWxmKToKICAgICAgICBzZWxmLl9kLCBzZWxmLl9sb2NrID0ge30sIHRocmVhZGluZy5Mb2NrKCkKCiAgICBkZWYgaXNzdWUoc2VsZik6CiAgICAgICAgbiA9IHNlY3JldHMudG9rZW5fYnl0ZXMoMzIpCiAgICAgICAgd2l0aCBzZWxmLl9sb2NrOgogICAgICAgICAgICBub3cgPSB0aW1lLnRpbWUoKQogICAgICAgICAgICBzZWxmLl9kID0ge2s6IHYgZm9yIGssIHYgaW4gc2VsZi5fZC5pdGVtcygpIGlmIHYgPiBub3d9CiAgICAgICAgICAgIHNlbGYuX2RbYjY0ZShuKV0gPSBub3cgKyBOT05DRV9UVEwKICAgICAgICByZXR1cm4gbgoKICAgIGRlZiBjb25zdW1lKHNlbGYsIHRva2VuKToKICAgICAgICB3aXRoIHNlbGYuX2xvY2s6CiAgICAgICAgICAgIGV4cCA9IHNlbGYuX2QucG9wKHRva2VuLCBOb25lKQogICAgICAgIGlmIGV4cCBpcyBOb25lIG9yIGV4cCA8IHRpbWUudGltZSgpOgogICAgICAgICAgICByZXR1cm4gTm9uZQogICAgICAgIHRyeToKICAgICAgICAgICAgcmV0dXJuIGI2NGQodG9rZW4pCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gc2VydmVyIC0tCmNsYXNzIEluYm94OgogICAgZGVmIF9faW5pdF9fKHNlbGYpOgogICAgICAgIHNlbGYuayA9IGtleXMoY3JlYXRlPVRydWUpICAgIyBhIGRhZW1vbiBjb21pbmcgdXAgaXMgYWxsb3dlZCB0byBtaW50CiAgICAgICAgc2VsZi5ub25jZXMgPSBOb25jZXMoKQogICAgICAgIHNlbGYucGVlcnMgPSBwZWVycygpCiAgICAgICAgc2VsZi5sb2NrID0gdGhyZWFkaW5nLkxvY2soKQogICAgICAgIHNlbGYuYWNjZXB0ZWQgPSBzZWxmLnJlamVjdGVkID0gMAogICAgICAgIHNlbGYuYWRkciA9IG9uaW9uKCkKICAgICAgICBzZWxmLl9wZWVyc19tdGltZSA9IHNlbGYuX210aW1lKCkKCiAgICBkZWYgX210aW1lKHNlbGYpOgogICAgICAgIHRyeToKICAgICAgICAgICAgcmV0dXJuIG9zLnBhdGguZ2V0bXRpbWUoUEVFUlMpCiAgICAgICAgZXhjZXB0IE9TRXJyb3I6CiAgICAgICAgICAgIHJldHVybiBOb25lCgogICAgZGVmIF9yZWxvYWRfcGVlcnNfaWZfY2hhbmdlZChzZWxmKToKICAgICAgICAiIiJQaWNrIHVwIGBhZGQtcGVlcmAgd2l0aG91dCByZXN0YXJ0aW5nIHRoZSBkYWVtb24uIiIiCiAgICAgICAgbm93ID0gc2VsZi5fbXRpbWUoKQogICAgICAgIGlmIG5vdyAhPSBzZWxmLl9wZWVyc19tdGltZToKICAgICAgICAgICAgd2l0aCBzZWxmLmxvY2s6CiAgICAgICAgICAgICAgICBzZWxmLnBlZXJzID0gcGVlcnMoKQogICAgICAgICAgICAgICAgc2VsZi5fcGVlcnNfbXRpbWUgPSBub3cKICAgICAgICAgICAgcHJpbnQoZiJbaW5ib3hdIHBlZXIgbGlzdCByZWxvYWRlZCAoe2xlbihzZWxmLnBlZXJzKX0gYWxsb3dlZCkiLCBmbHVzaD1UcnVlKQoKICAgIGRlZiBoYW5kbGUoc2VsZiwgcmVxKToKICAgICAgICBvcCA9IHJlcS5nZXQoIm9wIikKICAgICAgICBpZiBvcCA9PSAicGluZyI6CiAgICAgICAgICAgIHJldHVybiB7Im9rIjogVHJ1ZSwgInNlcnZpY2UiOiAidG9yYWdlbnRzLWluYm94IiwgIm9uaW9uIjogc2VsZi5hZGRyLAogICAgICAgICAgICAgICAgICAgICJmaW5nZXJwcmludCI6IHNlbGYuay5wdWJsaWMoKS5maW5nZXJwcmludH0KICAgICAgICBpZiBvcCA9PSAiaGVsbG8iOgogICAgICAgICAgICByZXR1cm4geyJvayI6IFRydWUsICJub25jZSI6IGI2NGUoc2VsZi5ub25jZXMuaXNzdWUoKSl9CiAgICAgICAgaWYgb3AgPT0gInNlbmQiOgogICAgICAgICAgICByZXR1cm4gc2VsZi5fYWNjZXB0KHJlcSkKICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiBmInVua25vd24gb3Age29wIXJ9In0KCiAgICBkZWYgX2FjY2VwdChzZWxmLCByZXEpOgogICAgICAgIHRva2VuLCBib2R5LCBwdWIsIHNpZyA9IChyZXEuZ2V0KCJub25jZSIpLCByZXEuZ2V0KCJib2R5IiksCiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIHJlcS5nZXQoInB1YmtleSIpLCByZXEuZ2V0KCJzaWciKSkKICAgICAgICBpZiBub3QgYWxsKFt0b2tlbiwgaXNpbnN0YW5jZShib2R5LCBzdHIpLCBwdWIsIHNpZ10pOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogIm1hbGZvcm1lZCBzZW5kIn0KCiAgICAgICAgbm9uY2UgPSBzZWxmLm5vbmNlcy5jb25zdW1lKHRva2VuKQogICAgICAgIGlmIG5vbmNlIGlzIE5vbmU6CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAic3RhbGUgb3IgdW5rbm93biBub25jZSJ9CgogICAgICAgIHRyeToKICAgICAgICAgICAgc2VuZGVyID0gUHVibGljSWRlbnRpdHkuZnJvbV9kaWN0KHB1YikKICAgICAgICAgICAgc2lnbmF0dXJlID0gYjY0ZChzaWcpCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJiYWQgcHVia2V5IG9yIHNpZ25hdHVyZSBlbmNvZGluZyJ9CgogICAgICAgIGlmIG5vdCBzZW5kZXIudmVyaWZ5KG5vbmNlICsgYm9keS5lbmNvZGUoInV0Zi04IiksIHNpZ25hdHVyZSk6CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAic2lnbmF0dXJlIGRvZXMgbm90IHZlcmlmeSJ9CgogICAgICAgIGZwID0gc2VuZGVyLmZpbmdlcnByaW50CiAgICAgICAgc2VsZi5fcmVsb2FkX3BlZXJzX2lmX2NoYW5nZWQoKQogICAgICAgIHdpdGggc2VsZi5sb2NrOgogICAgICAgICAgICBwZWVyID0gc2VsZi5wZWVycy5nZXQoZnApCiAgICAgICAgaWYgcGVlciBpcyBOb25lOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogInNlbmRlciBub3Qgb24gYWxsb3dsaXN0IiwKICAgICAgICAgICAgICAgICAgICAiZmluZ2VycHJpbnQiOiBmcH0KCiAgICAgICAgbWlkID0gdXVpZC51dWlkNCgpLmhleFs6MTJdCiAgICAgICAgcmVjID0geyJpZCI6IG1pZCwgInJlY2VpdmVkIjogdGltZS50aW1lKCksICJmcm9tX2ZpbmdlcnByaW50IjogZnAsCiAgICAgICAgICAgICAgICJmcm9tX2xhYmVsIjogcGVlci5nZXQoImxhYmVsIiwgIiIpLCAiZnJvbV9vbmlvbiI6IHBlZXIuZ2V0KCJvbmlvbiIsICIiKSwKICAgICAgICAgICAgICAgImJvZHkiOiBib2R5fQogICAgICAgIHBhdGggPSBvcy5wYXRoLmpvaW4oSU5CT1gsIGYie3RpbWUudGltZSgpOi4wZn0te21pZH0uanNvbiIpCiAgICAgICAgd2l0aCBvcGVuKHBhdGggKyAiLnRtcCIsICJ3IikgYXMgZjoKICAgICAgICAgICAganNvbi5kdW1wKHJlYywgZiwgaW5kZW50PTIpCiAgICAgICAgb3MucmVwbGFjZShwYXRoICsgIi50bXAiLCBwYXRoKQogICAgICAgIHNlbGYuYWNjZXB0ZWQgKz0gMQogICAgICAgIHByaW50KGYiW2luYm94XSAre21pZH0gZnJvbSB7cGVlci5nZXQoJ2xhYmVsJykgb3IgZnBbOjEyXX0iLCBmbHVzaD1UcnVlKQogICAgICAgIHJldHVybiB7Im9rIjogVHJ1ZSwgImlkIjogbWlkfQoKCmRlZiBjbGllbnRfbG9vcChjb25uLCBib3gpOgogICAgdHJ5OgogICAgICAgIHdoaWxlIFRydWU6CiAgICAgICAgICAgIHJlcSA9IHJlY3ZfbXNnKGNvbm4pCiAgICAgICAgICAgIGlmIHJlcSBpcyBOb25lOgogICAgICAgICAgICAgICAgYnJlYWsKICAgICAgICAgICAgdHJ5OgogICAgICAgICAgICAgICAgcmVwbHkgPSBib3guaGFuZGxlKHJlcSkKICAgICAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbiBhcyBleGM6CiAgICAgICAgICAgICAgICByZXBseSA9IHsib2siOiBGYWxzZSwgImVycm9yIjogZiJoYW5kbGVyOiB7ZXhjfSJ9CiAgICAgICAgICAgIHNlbmRfbXNnKGNvbm4sIHJlcGx5KQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICBwYXNzCiAgICBmaW5hbGx5OgogICAgICAgIHRyeToKICAgICAgICAgICAgY29ubi5jbG9zZSgpCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgcGFzcwoKCmRlZiBzZXJ2ZSgpOgogICAgYm94ID0gSW5ib3goKQogICAgc3J2ID0gc29ja2V0LnNvY2tldChzb2NrZXQuQUZfSU5FVCwgc29ja2V0LlNPQ0tfU1RSRUFNKQogICAgc3J2LnNldHNvY2tvcHQoc29ja2V0LlNPTF9TT0NLRVQsIHNvY2tldC5TT19SRVVTRUFERFIsIDEpCiAgICBzcnYuYmluZCgoIjEyNy4wLjAuMSIsIExJU1RFTl9QT1JUKSkKICAgIHNydi5saXN0ZW4oMTYpCiAgICBwcmludChmImxpc3RlbmluZyAxMjcuMC4wLjE6e0xJU1RFTl9QT1JUfSIsIGZsdXNoPVRydWUpCiAgICBwcmludChmIm9uaW9uICAgICAge2JveC5hZGRyIG9yICcoaGlkZGVuIHNlcnZpY2Ugbm90IGNvbmZpZ3VyZWQgeWV0KSd9IiwgZmx1c2g9VHJ1ZSkKICAgIHByaW50KGYiZmluZ2VycHJpbnQge2JveC5rLnB1YmxpYygpLmZpbmdlcnByaW50fSIsIGZsdXNoPVRydWUpCiAgICBwcmludChmInBlZXJzICAgICAge2xlbihib3gucGVlcnMpfSIsIGZsdXNoPVRydWUpCiAgICB0cnk6CiAgICAgICAgd2hpbGUgVHJ1ZToKICAgICAgICAgICAgY29ubiwgXyA9IHNydi5hY2NlcHQoKQogICAgICAgICAgICB0aHJlYWRpbmcuVGhyZWFkKHRhcmdldD1jbGllbnRfbG9vcCwgYXJncz0oY29ubiwgYm94KSwgZGFlbW9uPVRydWUpLnN0YXJ0KCkKICAgIGV4Y2VwdCBLZXlib2FyZEludGVycnVwdDoKICAgICAgICBwYXNzCiAgICBmaW5hbGx5OgogICAgICAgIHNydi5jbG9zZSgpCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIGNsaWVudCAtLQojIEVzY2FsYXRpbmcgbGFkZGVyOiBmZXRjaGluZyBhIENPTEQgZGVzY3JpcHRvciAoYSBwZWVyIHdob3NlIHRvciBoYXMgb25seSBqdXN0CiMgcHVibGlzaGVkLCBpLmUuIGV2ZXJ5IGJyYW5kLW5ldyB1c2VyJ3MgZmlyc3QgbWVzc2FnZSkgcm91dGluZWx5IHRha2VzIGxvbmdlcgojIHRoYW4gYSBzaW5nbGUgc2hvcnQgdGltZW91dC4gQSBmbGF0IDR4MzBzIGJ1ZGdldCBwcm9kdWNlZCBhIHNwdXJpb3VzCiMgQ29ubmVjdGlvbkVycm9yIG9uIGZpcnN0IGNvbnRhY3QsIHRoZW4gc3VjY2VlZGVkIGluc3RhbnRseSBvbiByZXRyeS4KRElBTF9MQURERVIgPSBbaW50KHgpIGZvciB4IGluCiAgICAgICAgICAgICAgIG9zLmVudmlyb24uZ2V0KCJUT1JBR0VOVFNfRElBTF9MQURERVIiLCAiMzAsNjAsMTIwLDE4MCIpLnNwbGl0KCIsIildCgoKZGVmIGRpYWwodGFyZ2V0X29uaW9uLCB0aW1lb3V0PU5vbmUpOgogICAgIiIiUGxhaW4gU09DS1M1IGRpYWwgdGhyb3VnaCB0aGUgbG9jYWwgdG9yLiBObyB0b3IgQVBJLCBqdXN0IHNvY2tzLiIiIgogICAgaW1wb3J0IHNvY2tzCiAgICBob3N0ID0gdGFyZ2V0X29uaW9uWzotNl0gaWYgdGFyZ2V0X29uaW9uLmVuZHN3aXRoKCIub25pb24iKSBlbHNlIHRhcmdldF9vbmlvbgogICAgbGFzdCA9IE5vbmUKICAgIGZvciBpLCBidWRnZXQgaW4gZW51bWVyYXRlKERJQUxfTEFEREVSKToKICAgICAgICBzID0gc29ja3Muc29ja3NvY2tldCgpCiAgICAgICAgcy5zZXRfcHJveHkoc29ja3MuU09DS1M1LCAiMTI3LjAuMC4xIiwgU09DS1NfUE9SVCwgcmRucz1UcnVlKQogICAgICAgIHMuc2V0dGltZW91dChidWRnZXQpCiAgICAgICAgaWYgaToKICAgICAgICAgICAgcHJpbnQoZiIgIHJldHJ5IHtpfS97bGVuKERJQUxfTEFEREVSKSAtIDF9ICIKICAgICAgICAgICAgICAgICAgZiIod2FpdGluZyB1cCB0byB7YnVkZ2V0fXMgZm9yIHRoZSBkZXNjcmlwdG9yKSIsCiAgICAgICAgICAgICAgICAgIGZpbGU9c3lzLnN0ZGVycikKICAgICAgICB0cnk6CiAgICAgICAgICAgIHMuY29ubmVjdCgoaG9zdCArICIub25pb24iLCA4MCkpCiAgICAgICAgICAgIHJldHVybiBzCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbiBhcyBleGM6CiAgICAgICAgICAgIGxhc3QgPSBleGMKICAgICAgICAgICAgdHJ5OgogICAgICAgICAgICAgICAgcy5jbG9zZSgpCiAgICAgICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgICAgICBwYXNzCiAgICByYWlzZSBDb25uZWN0aW9uRXJyb3IoCiAgICAgICAgZiJjYW5ub3QgcmVhY2gge3RhcmdldF9vbmlvbls6MTZdfS4uLiBhZnRlciB7bGVuKERJQUxfTEFEREVSKX0gYXR0ZW1wdHM6IHtsYXN0fVxuIgogICAgICAgIGYiICBBIHBlZXIgdGhhdCBoYXMgb25seSBqdXN0IGNvbWUgb25saW5lIGNhbiB0YWtlIGEgY291cGxlIG9mIG1pbnV0ZXNcbiIKICAgICAgICBmIiAgdG8gcHVibGlzaCBpdHMgZGVzY3JpcHRvci4gUmV0cnkgaW4gYSBtaW51dGUgYmVmb3JlIGFzc3VtaW5nIGl0IGlzIGRvd24uXG4iCiAgICAgICAgZiIgIENoZWNrIHRoZSBwZWVyIGlzIHJ1bm5pbmcgYW5kIHRvciBpcyB1cCBvbiAxMjcuMC4wLjE6e1NPQ0tTX1BPUlR9LiIpCgoKZGVmIHNlbmRfdG8odGFyZ2V0X29uaW9uLCBib2R5LCBrPU5vbmUpOgogICAgayA9IGsgb3IgbmVlZF9rZXlzKCkgICAgICAgICAgICAgIyBuZXZlciBzaWduIHdpdGggYSBmcmVzaGx5IG1pbnRlZCBrZXkKICAgIHNvY2sgPSBkaWFsKHRhcmdldF9vbmlvbikKICAgIHRyeToKICAgICAgICBzZW5kX21zZyhzb2NrLCB7Im9wIjogImhlbGxvIn0pCiAgICAgICAgaGVsbG8gPSByZWN2X21zZyhzb2NrKQogICAgICAgIGlmIG5vdCBoZWxsbyBvciBub3QgaGVsbG8uZ2V0KCJvayIpOgogICAgICAgICAgICByYWlzZSBSdW50aW1lRXJyb3IoZiJoZWxsbyByZWZ1c2VkOiB7aGVsbG99IikKICAgICAgICBub25jZSA9IGI2NGQoaGVsbG9bIm5vbmNlIl0pCiAgICAgICAgc2VuZF9tc2coc29jaywgeyJvcCI6ICJzZW5kIiwgIm5vbmNlIjogaGVsbG9bIm5vbmNlIl0sICJib2R5IjogYm9keSwKICAgICAgICAgICAgICAgICAgICAgICAgInB1YmtleSI6IGsucHVibGljKCkudG9fZGljdCgpLAogICAgICAgICAgICAgICAgICAgICAgICAic2lnIjogYjY0ZShrLnNpZ24obm9uY2UgKyBib2R5LmVuY29kZSgidXRmLTgiKSkpfSkKICAgICAgICByZXR1cm4gcmVjdl9tc2coc29jaykKICAgIGZpbmFsbHk6CiAgICAgICAgdHJ5OgogICAgICAgICAgICBzb2NrLmNsb3NlKCkKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICBwYXNzCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIGNsaSAtLQpkZWYgY21kX3NlcnZlKGEpOgogICAgc2VydmUoKQoKCmRlZiBjbWRfaW5pdChhKToKICAgIGV4aXN0ZWQgPSBvcy5wYXRoLmV4aXN0cyhJREZJTEUpCiAgICBrID0ga2V5cyhjcmVhdGU9VHJ1ZSkKICAgIHByaW50KGYieydleGlzdGluZycgaWYgZXhpc3RlZCBlbHNlICdjcmVhdGVkJ30gIHtJREZJTEV9IikKICAgIHByaW50KGYiZmluZ2VycHJpbnQgIHtrLnB1YmxpYygpLmZpbmdlcnByaW50fSIpCiAgICBpZiBleGlzdGVkOgogICAgICAgIHByaW50KCJvbmlvbiAgICAgICAgdW5jaGFuZ2VkIChpZGVudGl0eSByZXVzZWQpIikKCgpkZWYgY21kX3dob2FtaShhKToKICAgIGsgPSBrZXlzKCkgICAgICAgICAgICAgICAgICAgICAgIyBuZXZlciBjcmVhdGVzCiAgICBwcmludChmIm9uaW9uICAgICAgICB7b25pb24oKSBvciAnKG5vdCBjb25maWd1cmVkKSd9IikKICAgIGlmIGsgaXMgTm9uZToKICAgICAgICBwcmludChmImZpbmdlcnByaW50ICAobm8gaWRlbnRpdHkgeWV0IC0gcnVuOiBpbmJveF9hZ2VudC5weSBpbml0KSIpCiAgICAgICAgcmFpc2UgU3lzdGVtRXhpdCgyKQogICAgcHJpbnQoZiJmaW5nZXJwcmludCAge2sucHVibGljKCkuZmluZ2VycHJpbnR9IikKCgpkZWYgY21kX2FkZF9wZWVyKGEpOgogICAgcCA9IHBlZXJzKCkKICAgIGZwID0gYS5maW5nZXJwcmludC5zdHJpcCgpLmxvd2VyKCkKICAgIGlmIGxlbihmcCkgIT0gMzI6CiAgICAgICAgc3lzLmV4aXQoZiJmaW5nZXJwcmludCBtdXN0IGJlIDMyIGhleCBjaGFycyAoZ290IHtsZW4oZnApfSkiKQogICAgaWYgbm90IGEub25pb24uZW5kc3dpdGgoIi5vbmlvbiIpOgogICAgICAgIHN5cy5leGl0KCItLW9uaW9uIG11c3QgZW5kIGluIC5vbmlvbiIpCiAgICBwW2ZwXSA9IHsib25pb24iOiBhLm9uaW9uLnN0cmlwKCksICJsYWJlbCI6IGEubGFiZWwgb3IgZnBbOjEyXSwKICAgICAgICAgICAgICJhZGRlZCI6IHRpbWUudGltZSgpfQogICAgc2F2ZV9wZWVycyhwKQogICAgcHJpbnQoZiJhbGxvd2xpc3RlZCB7cFtmcF1bJ2xhYmVsJ119ICh7ZnBbOjEyXX0uLi4pIC0+IHthLm9uaW9ufSIpCgoKZGVmIGNtZF9wZWVycyhhKToKICAgIHAgPSBwZWVycygpCiAgICBpZiBub3QgcDoKICAgICAgICBwcmludCgiKG5vIHBlZXJzIGFsbG93bGlzdGVkKSIpCiAgICBmb3IgZnAsIHYgaW4gc29ydGVkKHAuaXRlbXMoKSwga2V5PWxhbWJkYSBrdjoga3ZbMV0uZ2V0KCJsYWJlbCIsICIiKSk6CiAgICAgICAgcHJpbnQoZiJ7di5nZXQoJ2xhYmVsJywnJyk6MTh9IHtmcFs6MTZdfS4uLiAge3ZbJ29uaW9uJ119IikKCgpkZWYgX21zZ3MoaW5jbHVkZV9hcmNoaXZlZD1GYWxzZSk6CiAgICBvdXQgPSBbXQogICAgZm9yIGQsIGFyY2ggaW4gKChJTkJPWCwgRmFsc2UpLCAoQVJDSElWRSwgVHJ1ZSkpOgogICAgICAgIGlmIG5vdCBvcy5wYXRoLmlzZGlyKGQpOgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIGlmIGFyY2ggYW5kIG5vdCBpbmNsdWRlX2FyY2hpdmVkOgogICAgICAgICAgICBjb250aW51ZQogICAgICAgIGZvciBuIGluIHNvcnRlZChvcy5saXN0ZGlyKGQpKToKICAgICAgICAgICAgaWYgbi5lbmRzd2l0aCgiLmpzb24iKToKICAgICAgICAgICAgICAgIHRyeToKICAgICAgICAgICAgICAgICAgICB3aXRoIG9wZW4ob3MucGF0aC5qb2luKGQsIG4pKSBhcyBmOgogICAgICAgICAgICAgICAgICAgICAgICBtID0ganNvbi5sb2FkKGYpCiAgICAgICAgICAgICAgICAgICAgbVsiX2FyY2hpdmVkIl0gPSBhcmNoCiAgICAgICAgICAgICAgICAgICAgb3V0LmFwcGVuZChtKQogICAgICAgICAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgICAgICAgICBwYXNzCiAgICByZXR1cm4gc29ydGVkKG91dCwga2V5PWxhbWJkYSBtOiBtLmdldCgicmVjZWl2ZWQiLCAwKSkKCgpkZWYgY21kX2luYm94KGEpOgogICAgbXMgPSBfbXNncyhhLmFsbCkKICAgIGlmIG5vdCBtczoKICAgICAgICBwcmludCgiKGluYm94IGVtcHR5KSIpCiAgICBmb3IgbSBpbiBtczoKICAgICAgICB3aGVuID0gdGltZS5zdHJmdGltZSgiJVktJW0tJWQgJUg6JU0iLCB0aW1lLmxvY2FsdGltZShtLmdldCgicmVjZWl2ZWQiLCAwKSkpCiAgICAgICAgcHJpbnQoZiJ7bVsnaWQnXX0gIHt3aGVufSAge20uZ2V0KCdmcm9tX2xhYmVsJywnPycpOjE2fSAiCiAgICAgICAgICAgICAgZiJ7KG0uZ2V0KCdib2R5Jykgb3IgJycpLnJlcGxhY2UoY2hyKDEwKSwnICcpWzo2MF19IikKCgpkZWYgY21kX3JlYWQoYSk6CiAgICBmb3IgbSBpbiBfbXNncyhUcnVlKToKICAgICAgICBpZiBtWyJpZCJdID09IGEuaWQ6CiAgICAgICAgICAgIHByaW50KGpzb24uZHVtcHMobSwgaW5kZW50PTIpKQogICAgICAgICAgICByZXR1cm4KICAgIHN5cy5leGl0KGYibm8gbWVzc2FnZSB7YS5pZH0iKQoKCmRlZiBjbWRfYWNrKGEpOgogICAgZm9yIG4gaW4gKG9zLmxpc3RkaXIoSU5CT1gpIGlmIG9zLnBhdGguaXNkaXIoSU5CT1gpIGVsc2UgW10pOgogICAgICAgIGlmIGEuaWQgaW4gbjoKICAgICAgICAgICAgb3MucmVwbGFjZShvcy5wYXRoLmpvaW4oSU5CT1gsIG4pLCBvcy5wYXRoLmpvaW4oQVJDSElWRSwgbikpCiAgICAgICAgICAgIHByaW50KGYiYXJjaGl2ZWQge2EuaWR9IikKICAgICAgICAgICAgcmV0dXJuCiAgICBzeXMuZXhpdChmIm5vIHVuYXJjaGl2ZWQgbWVzc2FnZSB7YS5pZH0iKQoKCmRlZiBjbWRfc2VuZChhKToKICAgIHAgPSBwZWVycygpCiAgICB0YXJnZXQgPSBOb25lCiAgICBmb3IgZnAsIHYgaW4gcC5pdGVtcygpOgogICAgICAgIGlmIGEudG8gaW4gKGZwLCB2LmdldCgibGFiZWwiKSwgZnBbOjEyXSk6CiAgICAgICAgICAgIHRhcmdldCA9IHYKICAgICAgICAgICAgYnJlYWsKICAgIGlmIHRhcmdldCBpcyBOb25lOgogICAgICAgIHN5cy5leGl0KGYidW5rbm93biBwZWVyIHthLnRvIXJ9OyB0cnk6IGluYm94X2FnZW50LnB5IHBlZXJzIikKICAgIHJlcGx5ID0gc2VuZF90byh0YXJnZXRbIm9uaW9uIl0sIGEuYm9keSkKICAgIHByaW50KGpzb24uZHVtcHMocmVwbHksIGluZGVudD0yKSkKICAgIHN5cy5leGl0KDAgaWYgcmVwbHkgYW5kIHJlcGx5LmdldCgib2siKSBlbHNlIDEpCgoKZGVmIG1haW4oKToKICAgIGFwID0gYXJncGFyc2UuQXJndW1lbnRQYXJzZXIoZGVzY3JpcHRpb249X19kb2NfXywKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgZm9ybWF0dGVyX2NsYXNzPWFyZ3BhcnNlLlJhd0Rlc2NyaXB0aW9uSGVscEZvcm1hdHRlcikKICAgIHMgPSBhcC5hZGRfc3VicGFyc2VycyhkZXN0PSJjbWQiLCByZXF1aXJlZD1UcnVlKQogICAgcy5hZGRfcGFyc2VyKCJzZXJ2ZSIpLnNldF9kZWZhdWx0cyhmbj1jbWRfc2VydmUpCiAgICBzLmFkZF9wYXJzZXIoIndob2FtaSIpLnNldF9kZWZhdWx0cyhmbj1jbWRfd2hvYW1pKQogICAgcy5hZGRfcGFyc2VyKCJpbml0Iikuc2V0X2RlZmF1bHRzKGZuPWNtZF9pbml0KQogICAgcy5hZGRfcGFyc2VyKCJwZWVycyIpLnNldF9kZWZhdWx0cyhmbj1jbWRfcGVlcnMpCiAgICBwID0gcy5hZGRfcGFyc2VyKCJhZGQtcGVlciIpCiAgICBwLmFkZF9hcmd1bWVudCgiZmluZ2VycHJpbnQiKQogICAgcC5hZGRfYXJndW1lbnQoIi0tb25pb24iLCByZXF1aXJlZD1UcnVlKQogICAgcC5hZGRfYXJndW1lbnQoIi0tbGFiZWwiLCBkZWZhdWx0PSIiKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX2FkZF9wZWVyKQogICAgcCA9IHMuYWRkX3BhcnNlcigiaW5ib3giKQogICAgcC5hZGRfYXJndW1lbnQoIi0tYWxsIiwgYWN0aW9uPSJzdG9yZV90cnVlIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9pbmJveCkKICAgIHAgPSBzLmFkZF9wYXJzZXIoInJlYWQiKQogICAgcC5hZGRfYXJndW1lbnQoImlkIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9yZWFkKQogICAgcCA9IHMuYWRkX3BhcnNlcigiYWNrIikKICAgIHAuYWRkX2FyZ3VtZW50KCJpZCIpCiAgICBwLnNldF9kZWZhdWx0cyhmbj1jbWRfYWNrKQogICAgcCA9IHMuYWRkX3BhcnNlcigic2VuZCIpCiAgICBwLmFkZF9hcmd1bWVudCgiLS10byIsIHJlcXVpcmVkPVRydWUpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1ib2R5IiwgcmVxdWlyZWQ9VHJ1ZSkKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9zZW5kKQogICAgYSA9IGFwLnBhcnNlX2FyZ3MoKQogICAgYS5mbihhKQoKCmlmIF9fbmFtZV9fID09ICJfX21haW5fXyI6CiAgICBtYWluKCkK'
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

# tar.exe ships with Windows 10 1803+. Resolve it to the REAL Windows binary
# rather than trusting PATH: with Git Bash (MSYS2) installed, bare `tar` resolves
# to GNU tar, which cannot parse a Windows path like C:\Users\... and dies with
# "tar (child): Cannot connect to C: resolve failed" (tries C: as a hostname).
$SysRoot = if ($env:SystemRoot) { $env:SystemRoot } else { "C:\Windows" }
$Tar = "$SysRoot\System32\tar.exe"
if (-not (Test-Path $Tar)) {
  $cmd = Get-Command tar -ErrorAction SilentlyContinue
  if ($cmd) { $Tar = $cmd.Source } else {
    Die "tar.exe not found. It ships with Windows 10 1803 and later. Update Windows, or extract manually."
  }
}
if ($Tar -notmatch '\\System32\\tar\.exe$') {
  Warn "using $Tar (not the Windows built-in); if extraction fails, install a newer Windows"
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
  & $Tar -xzf $tmp -C $dest --strip-components=1
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
    & $Tar -xzf $tmp -C (Join-Path $HomeDir "tor-bin")
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

# The daemon learns its ports from its launcher; the CLI does not. Without this
# record a bare `send` fell back to SOCKS 9050 and failed with "Connection
# refused" even though tor was listening on 9061.
# PowerShell has no backslash escapes -- build the JSON by concatenation.
$cfgJson = '{"local_port": ' + $Port + ', "socks_port": ' + $Socks + '}'
$cfgJson | Set-Content -Path (Join-Path $State "config.json") -Encoding ASCII
Ok "state\config.json written (cli uses socks $Socks)"

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
  # Re-running must replace the running instance, not stack a second one beside
  # it: two tors on 9061 and two daemons on 8799 would each fail to bind, and
  # their 5s restart loops would then fight each other forever.
  # The loops are cmd.exe, so they go first -- killing tor alone just makes the
  # loop relaunch it. Everything is matched on OUR paths, never by bare name,
  # so a Tor Browser's tor.exe is never touched.
  $stopped = 0
  Get-CimInstance Win32_Process -Filter "Name='cmd.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*run-tor.cmd*" -or $_.CommandLine -like "*run-inbox.cmd*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $stopped++ }
  Get-CimInstance Win32_Process -Filter "Name='tor.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.ExecutablePath -and $_.ExecutablePath -like "*$HomeDir*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $stopped++ }
  Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*inbox_agent.py*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $stopped++ }
  if ($stopped -gt 0) {
    Ok "stopped $stopped old process(es)"
    Start-Sleep -Milliseconds 800
  }

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
# init explicitly: whoami is read-only now and must never mint an identity
& $Py (Join-Path $HomeDir "inbox_agent.py") init | Out-Null
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
