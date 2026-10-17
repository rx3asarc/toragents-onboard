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
$PAYLOAD_INBOX='IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwoiIiJpbmJveF9hZ2VudC5weSAtLSBhIHZlcmlmaWVkIG1lc3NhZ2UgaW5ib3ggYmVoaW5kIGEgdG9yIGhpZGRlbiBzZXJ2aWNlLgoKUnVucyBvbiBIRVIgbWFjaGluZS4gTGlzdGVucyBvbiBhIHBsYWluIGxvY2FsaG9zdCBUQ1AgcG9ydDsgdG9yIGZvcndhcmRzIHRoZQpoaWRkZW4gc2VydmljZSB0byBpdC4gU2VydmluZyBuZWVkcyBubyB0b3IgQVBJIGF0IGFsbCAtLSBubyBjb250cm9sIHBvcnQsIG5vCkFERF9PTklPTiwgbm8ga2V5cyB0byBtYW5hZ2UuIE9ubHkgb3V0Ym91bmQgc2VuZHMgdG91Y2ggdG9yLCB2aWEgU09DS1MuCgpTZWN1cml0eSBtb2RlbAogICAgQSBtZXNzYWdlIGlzIGFjY2VwdGVkIG9ubHkgaWYgdGhlIHNlbmRlciBwcm92ZXMgcG9zc2Vzc2lvbiBvZiBhbgogICAgYWxsb3dsaXN0ZWQgRWQyNTUxOSBrZXkgb3ZlciBhIG9uZS11c2Ugbm9uY2UuIFRoZSBzZW5kZXIncyBjbGFpbWVkIG9uaW9uCiAgICBhZGRyZXNzIGlzIG5ldmVyIHRydXN0ZWQgZm9yIHJvdXRpbmcuCgpVc2FnZQogICAgaW5ib3hfYWdlbnQucHkgc2VydmUgICAgICAgICAgICAgICAgIHJ1biB0aGUgZGFlbW9uCiAgICBpbmJveF9hZ2VudC5weSB3aG9hbWkgICAgICAgICAgICAgICAgcHJpbnQgdGhpcyBtYWNoaW5lJ3Mgb25pb24gKyBmaW5nZXJwcmludAogICAgaW5ib3hfYWdlbnQucHkgYWRkLXBlZXIgRlAgLS1vbmlvbiBBIGFsbG93IGEgcGVlciB0byBzZW5kCiAgICBpbmJveF9hZ2VudC5weSBwZWVycwogICAgaW5ib3hfYWdlbnQucHkgaW5ib3gKICAgIGluYm94X2FnZW50LnB5IHJlYWQgPGlkPgogICAgaW5ib3hfYWdlbnQucHkgYWNrIDxpZD4KICAgIGluYm94X2FnZW50LnB5IHNlbmQgLS10byBMQUJFTCAtLWJvZHkgVEVYVAoiIiIKaW1wb3J0IGFyZ3BhcnNlCmltcG9ydCBiYXNlNjQKaW1wb3J0IGpzb24KaW1wb3J0IG9zCmltcG9ydCBzZWNyZXRzCmltcG9ydCBzb2NrZXQKaW1wb3J0IHN5cwppbXBvcnQgdGhyZWFkaW5nCmltcG9ydCB0aW1lCmltcG9ydCB1dWlkCgpmcm9tIHdpcmUgaW1wb3J0IEFnZW50S2V5cywgUHVibGljSWRlbnRpdHkKCkhPTUUgPSBvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX0hPTUUiLCBvcy5wYXRoLmV4cGFuZHVzZXIoIn4vLnRvcmFnZW50cyIpKQojIFRPUkFHRU5UU19TVEFURSB3aW5zIG92ZXIgJEhPTUUvc3RhdGUgc28gdGhpcyBDTEkgY2FuIG9wZXJhdGUgb24gYSBmbGF0IHN0YXRlCiMgZGlyZWN0b3J5ICh0aGUgbGF5b3V0IGxpc3RlbmVyLnB5IHVzZXMgb24gdGhlIGJveCkuIFdpdGhvdXQgaXQgdGhlIHR3byB0b29scwojIGRpc2FncmVlIGFib3V0IHdoZXJlIGlkZW50aXR5Lmpzb24gbGl2ZXMsIGFuZCB3aG9hbWkgc2lsZW50bHkgbWludHMgYQojIHRocm93YXdheSBrZXkgYW5kIHNpZ25zIHdpdGggdGhlIHdyb25nIG9uZS4KU1RBVEUgPSBvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX1NUQVRFIikgb3Igb3MucGF0aC5qb2luKEhPTUUsICJzdGF0ZSIpCklOQk9YID0gb3MucGF0aC5qb2luKFNUQVRFLCAiaW5ib3giKQpBUkNISVZFID0gb3MucGF0aC5qb2luKFNUQVRFLCAiYXJjaGl2ZSIpClBFRVJTID0gb3MucGF0aC5qb2luKFNUQVRFLCAicGVlcnMuanNvbiIpCklERklMRSA9IG9zLnBhdGguam9pbihTVEFURSwgImlkZW50aXR5Lmpzb24iKQpIT1NUTkFNRV9GSUxFID0gb3MucGF0aC5qb2luKEhPTUUsICJocyIsICJob3N0bmFtZSIpCgpDT05GSUcgPSBvcy5wYXRoLmpvaW4oU1RBVEUsICJjb25maWcuanNvbiIpCgoKZGVmIF9pbnN0YWxsZWRfY29uZmlnKCk6CiAgICAiIiJSZWFkIHRoZSBwb3J0cyB0aGUgaW5zdGFsbGVyIGFjdHVhbGx5IGNvbmZpZ3VyZWQuCgogICAgVGhpcyBleGlzdHMgYmVjYXVzZSB0aGUgQ0xJIGFuZCB0aGUgZGFlbW9uIG11c3QgYWdyZWUgb24gdGhlIFNPQ0tTIHBvcnQgYW5kCiAgICB0aGUgZGFlbW9uIGlzIHRoZSBvbmx5IG9uZSB0aGF0IGdldHMgVE9SQUdFTlRTX1NPQ0tTIGZyb20gaXRzIHNlcnZpY2UgdW5pdC4KICAgIFRoZSBvbGQgZmFsbGJhY2sgd2FzIDkwNTAgd2hpbGUgdGhlIGluc3RhbGxlciB3cml0ZXMgOTA2MSwgc28gZXZlcnkgYmFyZQogICAgYHNlbmRgL2BpbmJveGAgZGllZCB3aXRoICJDb25uZWN0aW9uIHJlZnVzZWQiIHVudGlsIHRoZSB1c2VyIGV4cG9ydGVkIHRoZQogICAgdmFyaWFibGUgYnkgaGFuZC4gRW52IHN0aWxsIHdpbnM7IHRoZSByZWNvcmRlZCBjb25maWcgaXMgdGhlIGZhbGxiYWNrLgogICAgIiIiCiAgICB0cnk6CiAgICAgICAgd2l0aCBvcGVuKENPTkZJRykgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIGpzb24ubG9hZChmKQogICAgZXhjZXB0IChPU0Vycm9yLCBWYWx1ZUVycm9yKToKICAgICAgICByZXR1cm4ge30KCgpfY2ZnID0gX2luc3RhbGxlZF9jb25maWcoKQpMSVNURU5fUE9SVCA9IGludChvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX1BPUlQiKSBvciBfY2ZnLmdldCgibG9jYWxfcG9ydCIpIG9yIDg3OTkpClNPQ0tTX1BPUlQgPSBpbnQob3MuZW52aXJvbi5nZXQoIlRPUkFHRU5UU19TT0NLUyIpIG9yIF9jZmcuZ2V0KCJzb2Nrc19wb3J0Iikgb3IgOTA1MCkKTk9OQ0VfVFRMID0gMTgwLjAKCmI2NGUgPSBsYW1iZGEgYjogYmFzZTY0LmI2NGVuY29kZShiKS5kZWNvZGUoImFzY2lpIikKYjY0ZCA9IGxhbWJkYSBzOiBiYXNlNjQuYjY0ZGVjb2RlKHMpCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIHN0YXRlIC0tLQpkZWYgZGlycygpOgogICAgZm9yIGQgaW4gKFNUQVRFLCBJTkJPWCwgQVJDSElWRSk6CiAgICAgICAgb3MubWFrZWRpcnMoZCwgZXhpc3Rfb2s9VHJ1ZSkKCgpkZWYga2V5cyhjcmVhdGU9RmFsc2UpOgogICAgIiIiTG9hZCB0aGUgaWRlbnRpdHkuIFJldHVybnMgTm9uZSBpZiBhYnNlbnQgYW5kIGNyZWF0ZSBpcyBGYWxzZS4KCiAgICBNaW50aW5nIGlzIG9wdC1pbiBvbiBwdXJwb3NlLiBBIHJlYWQtb25seSBjb21tYW5kIHRoYXQgY3JlYXRlcyBhbiBpZGVudGl0eQogICAgaXMgYSBmb290Z3VuOiBpdCB3cml0ZXMgYSBuZXcga2V5LCBhbmQgYW55dGhpbmcgdGhhdCB0aGVuIHNpZ25zIHdpdGggaXQgaXMKICAgIHNpbGVudGx5IHVzaW5nIHRoZSB3cm9uZyBpZGVudGl0eSwgd2hpY2ggdGhlIHBlZXIgcmVqZWN0cyBpbiBhIHdheSB0aGF0CiAgICBsb29rcyBsaWtlIGEgbmV0d29yayBmYXVsdC4KICAgICIiIgogICAgZGlycygpCiAgICBpZiBvcy5wYXRoLmV4aXN0cyhJREZJTEUpOgogICAgICAgIHdpdGggb3BlbihJREZJTEUpIGFzIGY6CiAgICAgICAgICAgIHJldHVybiBBZ2VudEtleXMuZnJvbV9zZWNyZXRfZGljdChqc29uLmxvYWQoZikpCiAgICBpZiBub3QgY3JlYXRlOgogICAgICAgIHJldHVybiBOb25lCiAgICBrID0gQWdlbnRLZXlzLmdlbmVyYXRlKCkKICAgIGZkID0gb3Mub3BlbihJREZJTEUsIG9zLk9fV1JPTkxZIHwgb3MuT19DUkVBVCB8IG9zLk9fVFJVTkMsIDBvNjAwKQogICAgd2l0aCBvcy5mZG9wZW4oZmQsICJ3IikgYXMgZjoKICAgICAgICBqc29uLmR1bXAoay50b19zZWNyZXRfZGljdCgpLCBmKQogICAgcmV0dXJuIGsKCgpkZWYgbmVlZF9rZXlzKCk6CiAgICBrID0ga2V5cygpCiAgICBpZiBrIGlzIE5vbmU6CiAgICAgICAgcHJpbnQoZiJubyBpZGVudGl0eSBhdCB7SURGSUxFfSIsIGZpbGU9c3lzLnN0ZGVycikKICAgICAgICBwcmludCgiICBjcmVhdGUgb25lIHdpdGg6ICBpbmJveF9hZ2VudC5weSBpbml0IiwgZmlsZT1zeXMuc3RkZXJyKQogICAgICAgIHByaW50KCIgICh0aGUgaW5zdGFsbGVyIGRvZXMgdGhpcyBmb3IgeW91OyB3aG9hbWkgbmV2ZXIgd3JpdGVzKSIsCiAgICAgICAgICAgICAgZmlsZT1zeXMuc3RkZXJyKQogICAgICAgIHJhaXNlIFN5c3RlbUV4aXQoMikKICAgIHJldHVybiBrCgoKZGVmIHBlZXJzKCk6CiAgICBpZiBub3Qgb3MucGF0aC5leGlzdHMoUEVFUlMpOgogICAgICAgIHJldHVybiB7fQogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihQRUVSUykgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIGpzb24ubG9hZChmKQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICByZXR1cm4ge30KCgpkZWYgc2F2ZV9wZWVycyhwKToKICAgIGRpcnMoKQogICAgdG1wID0gUEVFUlMgKyAiLnRtcCIKICAgIHdpdGggb3Blbih0bXAsICJ3IikgYXMgZjoKICAgICAgICBqc29uLmR1bXAocCwgZiwgaW5kZW50PTIsIHNvcnRfa2V5cz1UcnVlKQogICAgb3MucmVwbGFjZSh0bXAsIFBFRVJTKQoKCmRlZiBvbmlvbigpOgogICAgIiIiUmVzb2x2ZSBvdXIgb25pb24gYWRkcmVzcyB3aXRob3V0IGV2ZXIgdGFsa2luZyB0byB0b3IuCgogICAgVHdvIGxheW91dHMgZXhpc3Q6CiAgICAgIC0gc3RhdGljIEhpZGRlblNlcnZpY2VEaXIgKGV2ZXJ5IGluc3RhbGwgdGhpcyBzY3JpcHQgbWFrZXMpOiB0b3Igd3JpdGVzCiAgICAgICAgJEhPTUUvaHMvaG9zdG5hbWUsIHdoaWNoIHdpbnMuCiAgICAgIC0gQUREX09OSU9OIChhIGRhZW1vbiB0aGF0IHJlZ2lzdGVycyB0aHJvdWdoIHRoZSBjb250cm9sIHBvcnQpOiB0b3Iga2VlcHMKICAgICAgICBubyBob3N0bmFtZSBmaWxlLCBzbyB0aGF0IGRhZW1vbiByZWNvcmRzIHRoZSBhZGRyZXNzIGl0IGdvdCBpbgogICAgICAgICRTVEFURS9vbmlvbi50eHQuCgogICAgVGhpcyBtdXN0IHN0YXkgcmVhZC1vbmx5IGFuZCB3b3JrIHdpdGggdG9yIHN0b3BwZWQ6IGR1cmluZyBhIGN1dG92ZXIgdGhpcwogICAgaXMgdGhlIGV2aWRlbmNlIGFuIG9wZXJhdG9yIHJlYWRzLCBhbmQgIm9uaW9uIChub3QgY29uZmlndXJlZCkiIG9uIGEKICAgIGhlYWx0aHkgbWlncmF0aW9uIHdvdWxkIGludml0ZSBhIGZhbHNlIHJvbGxiYWNrLgogICAgIiIiCiAgICBmb3IgcGF0aCBpbiAoSE9TVE5BTUVfRklMRSwgb3MucGF0aC5qb2luKFNUQVRFLCAib25pb24udHh0IikpOgogICAgICAgIHRyeToKICAgICAgICAgICAgd2l0aCBvcGVuKHBhdGgpIGFzIGY6CiAgICAgICAgICAgICAgICB2YWwgPSBmLnJlYWQoKS5zdHJpcCgpCiAgICAgICAgICAgIGlmIHZhbDoKICAgICAgICAgICAgICAgIHJldHVybiB2YWwKICAgICAgICBleGNlcHQgT1NFcnJvcjoKICAgICAgICAgICAgY29udGludWUKICAgIHJldHVybiBOb25lCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gZnJhbWluZyAtLQpkZWYgc2VuZF9tc2coc29jaywgb2JqKToKICAgIGRhdGEgPSBqc29uLmR1bXBzKG9iaikuZW5jb2RlKCkKICAgIHNvY2suc2VuZGFsbChsZW4oZGF0YSkudG9fYnl0ZXMoNCwgImJpZyIpICsgZGF0YSkKCgpNQVhfRlJBTUUgPSAxNiAqIDEwMjQgKiAxMDI0ICAjIHNhbWUgY2VpbGluZyB0b3JhZ2VudHMgdXNlczsgc3RvcHMgYSBob3N0aWxlIGhlYWRlcgoKCmRlZiByZWN2X21zZyhzb2NrKToKICAgIGhkciA9IF9yZWFkX2V4YWN0KHNvY2ssIDQpCiAgICBpZiBoZHIgaXMgTm9uZToKICAgICAgICByZXR1cm4gTm9uZQogICAgbiA9IGludC5mcm9tX2J5dGVzKGhkciwgImJpZyIpCiAgICBpZiBuID4gTUFYX0ZSQU1FOgogICAgICAgIHJhaXNlIFZhbHVlRXJyb3IoZiJkZWNsYXJlZCBmcmFtZSB7bn0gZXhjZWVkcyB7TUFYX0ZSQU1FfSIpCiAgICBib2R5ID0gX3JlYWRfZXhhY3Qoc29jaywgbikKICAgIGlmIGJvZHkgaXMgTm9uZToKICAgICAgICByZXR1cm4gTm9uZQogICAgcmV0dXJuIGpzb24ubG9hZHMoYm9keS5kZWNvZGUoKSkKCgpkZWYgX3JlYWRfZXhhY3Qoc29jaywgbik6CiAgICBidWYgPSBiIiIKICAgIHdoaWxlIGxlbihidWYpIDwgbjoKICAgICAgICBjaHVuayA9IHNvY2sucmVjdihuIC0gbGVuKGJ1ZikpCiAgICAgICAgaWYgbm90IGNodW5rOgogICAgICAgICAgICByZXR1cm4gTm9uZQogICAgICAgIGJ1ZiArPSBjaHVuawogICAgcmV0dXJuIGJ1ZgoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBub25jZXMgLS0KY2xhc3MgTm9uY2VzOgogICAgZGVmIF9faW5pdF9fKHNlbGYpOgogICAgICAgIHNlbGYuX2QsIHNlbGYuX2xvY2sgPSB7fSwgdGhyZWFkaW5nLkxvY2soKQoKICAgIGRlZiBpc3N1ZShzZWxmKToKICAgICAgICBuID0gc2VjcmV0cy50b2tlbl9ieXRlcygzMikKICAgICAgICB3aXRoIHNlbGYuX2xvY2s6CiAgICAgICAgICAgIG5vdyA9IHRpbWUudGltZSgpCiAgICAgICAgICAgIHNlbGYuX2QgPSB7azogdiBmb3IgaywgdiBpbiBzZWxmLl9kLml0ZW1zKCkgaWYgdiA+IG5vd30KICAgICAgICAgICAgc2VsZi5fZFtiNjRlKG4pXSA9IG5vdyArIE5PTkNFX1RUTAogICAgICAgIHJldHVybiBuCgogICAgZGVmIGNvbnN1bWUoc2VsZiwgdG9rZW4pOgogICAgICAgIHdpdGggc2VsZi5fbG9jazoKICAgICAgICAgICAgZXhwID0gc2VsZi5fZC5wb3AodG9rZW4sIE5vbmUpCiAgICAgICAgaWYgZXhwIGlzIE5vbmUgb3IgZXhwIDwgdGltZS50aW1lKCk6CiAgICAgICAgICAgIHJldHVybiBOb25lCiAgICAgICAgdHJ5OgogICAgICAgICAgICByZXR1cm4gYjY0ZCh0b2tlbikKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICByZXR1cm4gTm9uZQoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBzZXJ2ZXIgLS0KY2xhc3MgSW5ib3g6CiAgICBkZWYgX19pbml0X18oc2VsZik6CiAgICAgICAgc2VsZi5rID0ga2V5cyhjcmVhdGU9VHJ1ZSkgICAjIGEgZGFlbW9uIGNvbWluZyB1cCBpcyBhbGxvd2VkIHRvIG1pbnQKICAgICAgICBzZWxmLm5vbmNlcyA9IE5vbmNlcygpCiAgICAgICAgc2VsZi5wZWVycyA9IHBlZXJzKCkKICAgICAgICBzZWxmLmxvY2sgPSB0aHJlYWRpbmcuTG9jaygpCiAgICAgICAgc2VsZi5hY2NlcHRlZCA9IHNlbGYucmVqZWN0ZWQgPSAwCiAgICAgICAgc2VsZi5hZGRyID0gb25pb24oKQogICAgICAgIHNlbGYuX3BlZXJzX210aW1lID0gc2VsZi5fbXRpbWUoKQoKICAgIGRlZiBfbXRpbWUoc2VsZik6CiAgICAgICAgdHJ5OgogICAgICAgICAgICByZXR1cm4gb3MucGF0aC5nZXRtdGltZShQRUVSUykKICAgICAgICBleGNlcHQgT1NFcnJvcjoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKCiAgICBkZWYgX3JlbG9hZF9wZWVyc19pZl9jaGFuZ2VkKHNlbGYpOgogICAgICAgICIiIlBpY2sgdXAgYGFkZC1wZWVyYCB3aXRob3V0IHJlc3RhcnRpbmcgdGhlIGRhZW1vbi4iIiIKICAgICAgICBub3cgPSBzZWxmLl9tdGltZSgpCiAgICAgICAgaWYgbm93ICE9IHNlbGYuX3BlZXJzX210aW1lOgogICAgICAgICAgICB3aXRoIHNlbGYubG9jazoKICAgICAgICAgICAgICAgIHNlbGYucGVlcnMgPSBwZWVycygpCiAgICAgICAgICAgICAgICBzZWxmLl9wZWVyc19tdGltZSA9IG5vdwogICAgICAgICAgICBwcmludChmIltpbmJveF0gcGVlciBsaXN0IHJlbG9hZGVkICh7bGVuKHNlbGYucGVlcnMpfSBhbGxvd2VkKSIsIGZsdXNoPVRydWUpCgogICAgZGVmIGhhbmRsZShzZWxmLCByZXEpOgogICAgICAgIG9wID0gcmVxLmdldCgib3AiKQogICAgICAgIGlmIG9wID09ICJwaW5nIjoKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBUcnVlLCAic2VydmljZSI6ICJ0b3JhZ2VudHMtaW5ib3giLCAib25pb24iOiBzZWxmLmFkZHIsCiAgICAgICAgICAgICAgICAgICAgImZpbmdlcnByaW50Ijogc2VsZi5rLnB1YmxpYygpLmZpbmdlcnByaW50fQogICAgICAgIGlmIG9wID09ICJoZWxsbyI6CiAgICAgICAgICAgIHJldHVybiB7Im9rIjogVHJ1ZSwgIm5vbmNlIjogYjY0ZShzZWxmLm5vbmNlcy5pc3N1ZSgpKX0KICAgICAgICBpZiBvcCA9PSAic2VuZCI6CiAgICAgICAgICAgIHJldHVybiBzZWxmLl9hY2NlcHQocmVxKQogICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6IGYidW5rbm93biBvcCB7b3Ahcn0ifQoKICAgIGRlZiBfYWNjZXB0KHNlbGYsIHJlcSk6CiAgICAgICAgdG9rZW4sIGJvZHksIHB1Yiwgc2lnID0gKHJlcS5nZXQoIm5vbmNlIiksIHJlcS5nZXQoImJvZHkiKSwKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgcmVxLmdldCgicHVia2V5IiksIHJlcS5nZXQoInNpZyIpKQogICAgICAgIGlmIG5vdCBhbGwoW3Rva2VuLCBpc2luc3RhbmNlKGJvZHksIHN0ciksIHB1Yiwgc2lnXSk6CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAibWFsZm9ybWVkIHNlbmQifQoKICAgICAgICBub25jZSA9IHNlbGYubm9uY2VzLmNvbnN1bWUodG9rZW4pCiAgICAgICAgaWYgbm9uY2UgaXMgTm9uZToKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJzdGFsZSBvciB1bmtub3duIG5vbmNlIn0KCiAgICAgICAgdHJ5OgogICAgICAgICAgICBzZW5kZXIgPSBQdWJsaWNJZGVudGl0eS5mcm9tX2RpY3QocHViKQogICAgICAgICAgICBzaWduYXR1cmUgPSBiNjRkKHNpZykKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogImJhZCBwdWJrZXkgb3Igc2lnbmF0dXJlIGVuY29kaW5nIn0KCiAgICAgICAgaWYgbm90IHNlbmRlci52ZXJpZnkobm9uY2UgKyBib2R5LmVuY29kZSgidXRmLTgiKSwgc2lnbmF0dXJlKToKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJzaWduYXR1cmUgZG9lcyBub3QgdmVyaWZ5In0KCiAgICAgICAgZnAgPSBzZW5kZXIuZmluZ2VycHJpbnQKICAgICAgICBzZWxmLl9yZWxvYWRfcGVlcnNfaWZfY2hhbmdlZCgpCiAgICAgICAgd2l0aCBzZWxmLmxvY2s6CiAgICAgICAgICAgIHBlZXIgPSBzZWxmLnBlZXJzLmdldChmcCkKICAgICAgICBpZiBwZWVyIGlzIE5vbmU6CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAic2VuZGVyIG5vdCBvbiBhbGxvd2xpc3QiLAogICAgICAgICAgICAgICAgICAgICJmaW5nZXJwcmludCI6IGZwfQoKICAgICAgICBtaWQgPSB1dWlkLnV1aWQ0KCkuaGV4WzoxMl0KICAgICAgICByZWMgPSB7ImlkIjogbWlkLCAicmVjZWl2ZWQiOiB0aW1lLnRpbWUoKSwgImZyb21fZmluZ2VycHJpbnQiOiBmcCwKICAgICAgICAgICAgICAgImZyb21fbGFiZWwiOiBwZWVyLmdldCgibGFiZWwiLCAiIiksICJmcm9tX29uaW9uIjogcGVlci5nZXQoIm9uaW9uIiwgIiIpLAogICAgICAgICAgICAgICAiYm9keSI6IGJvZHl9CiAgICAgICAgcGF0aCA9IG9zLnBhdGguam9pbihJTkJPWCwgZiJ7dGltZS50aW1lKCk6LjBmfS17bWlkfS5qc29uIikKICAgICAgICB3aXRoIG9wZW4ocGF0aCArICIudG1wIiwgInciKSBhcyBmOgogICAgICAgICAgICBqc29uLmR1bXAocmVjLCBmLCBpbmRlbnQ9MikKICAgICAgICBvcy5yZXBsYWNlKHBhdGggKyAiLnRtcCIsIHBhdGgpCiAgICAgICAgc2VsZi5hY2NlcHRlZCArPSAxCiAgICAgICAgcHJpbnQoZiJbaW5ib3hdICt7bWlkfSBmcm9tIHtwZWVyLmdldCgnbGFiZWwnKSBvciBmcFs6MTJdfSIsIGZsdXNoPVRydWUpCiAgICAgICAgcmV0dXJuIHsib2siOiBUcnVlLCAiaWQiOiBtaWR9CgoKZGVmIGNsaWVudF9sb29wKGNvbm4sIGJveCk6CiAgICB0cnk6CiAgICAgICAgd2hpbGUgVHJ1ZToKICAgICAgICAgICAgcmVxID0gcmVjdl9tc2coY29ubikKICAgICAgICAgICAgaWYgcmVxIGlzIE5vbmU6CiAgICAgICAgICAgICAgICBicmVhawogICAgICAgICAgICB0cnk6CiAgICAgICAgICAgICAgICByZXBseSA9IGJveC5oYW5kbGUocmVxKQogICAgICAgICAgICBleGNlcHQgRXhjZXB0aW9uIGFzIGV4YzoKICAgICAgICAgICAgICAgIHJlcGx5ID0geyJvayI6IEZhbHNlLCAiZXJyb3IiOiBmImhhbmRsZXI6IHtleGN9In0KICAgICAgICAgICAgc2VuZF9tc2coY29ubiwgcmVwbHkpCiAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgIHBhc3MKICAgIGZpbmFsbHk6CiAgICAgICAgdHJ5OgogICAgICAgICAgICBjb25uLmNsb3NlKCkKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICBwYXNzCgoKZGVmIHNlcnZlKCk6CiAgICBib3ggPSBJbmJveCgpCiAgICBzcnYgPSBzb2NrZXQuc29ja2V0KHNvY2tldC5BRl9JTkVULCBzb2NrZXQuU09DS19TVFJFQU0pCiAgICBzcnYuc2V0c29ja29wdChzb2NrZXQuU09MX1NPQ0tFVCwgc29ja2V0LlNPX1JFVVNFQUREUiwgMSkKICAgIHNydi5iaW5kKCgiMTI3LjAuMC4xIiwgTElTVEVOX1BPUlQpKQogICAgc3J2Lmxpc3RlbigxNikKICAgIHByaW50KGYibGlzdGVuaW5nIDEyNy4wLjAuMTp7TElTVEVOX1BPUlR9IiwgZmx1c2g9VHJ1ZSkKICAgIHByaW50KGYib25pb24gICAgICB7Ym94LmFkZHIgb3IgJyhoaWRkZW4gc2VydmljZSBub3QgY29uZmlndXJlZCB5ZXQpJ30iLCBmbHVzaD1UcnVlKQogICAgcHJpbnQoZiJmaW5nZXJwcmludCB7Ym94LmsucHVibGljKCkuZmluZ2VycHJpbnR9IiwgZmx1c2g9VHJ1ZSkKICAgIHByaW50KGYicGVlcnMgICAgICB7bGVuKGJveC5wZWVycyl9IiwgZmx1c2g9VHJ1ZSkKICAgIHRyeToKICAgICAgICB3aGlsZSBUcnVlOgogICAgICAgICAgICBjb25uLCBfID0gc3J2LmFjY2VwdCgpCiAgICAgICAgICAgIHRocmVhZGluZy5UaHJlYWQodGFyZ2V0PWNsaWVudF9sb29wLCBhcmdzPShjb25uLCBib3gpLCBkYWVtb249VHJ1ZSkuc3RhcnQoKQogICAgZXhjZXB0IEtleWJvYXJkSW50ZXJydXB0OgogICAgICAgIHBhc3MKICAgIGZpbmFsbHk6CiAgICAgICAgc3J2LmNsb3NlKCkKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gY2xpZW50IC0tCiMgRXNjYWxhdGluZyBsYWRkZXI6IGZldGNoaW5nIGEgQ09MRCBkZXNjcmlwdG9yIChhIHBlZXIgd2hvc2UgdG9yIGhhcyBvbmx5IGp1c3QKIyBwdWJsaXNoZWQsIGkuZS4gZXZlcnkgYnJhbmQtbmV3IHVzZXIncyBmaXJzdCBtZXNzYWdlKSByb3V0aW5lbHkgdGFrZXMgbG9uZ2VyCiMgdGhhbiBhIHNpbmdsZSBzaG9ydCB0aW1lb3V0LiBBIGZsYXQgNHgzMHMgYnVkZ2V0IHByb2R1Y2VkIGEgc3B1cmlvdXMKIyBDb25uZWN0aW9uRXJyb3Igb24gZmlyc3QgY29udGFjdCwgdGhlbiBzdWNjZWVkZWQgaW5zdGFudGx5IG9uIHJldHJ5LgpESUFMX0xBRERFUiA9IFtpbnQoeCkgZm9yIHggaW4KICAgICAgICAgICAgICAgb3MuZW52aXJvbi5nZXQoIlRPUkFHRU5UU19ESUFMX0xBRERFUiIsICIzMCw2MCwxMjAsMTgwIikuc3BsaXQoIiwiKV0KCgpkZWYgZGlhbCh0YXJnZXRfb25pb24sIHRpbWVvdXQ9Tm9uZSk6CiAgICAiIiJQbGFpbiBTT0NLUzUgZGlhbCB0aHJvdWdoIHRoZSBsb2NhbCB0b3IuIE5vIHRvciBBUEksIGp1c3Qgc29ja3MuIiIiCiAgICBpbXBvcnQgc29ja3MKICAgIGhvc3QgPSB0YXJnZXRfb25pb25bOi02XSBpZiB0YXJnZXRfb25pb24uZW5kc3dpdGgoIi5vbmlvbiIpIGVsc2UgdGFyZ2V0X29uaW9uCiAgICBsYXN0ID0gTm9uZQogICAgZm9yIGksIGJ1ZGdldCBpbiBlbnVtZXJhdGUoRElBTF9MQURERVIpOgogICAgICAgIHMgPSBzb2Nrcy5zb2Nrc29ja2V0KCkKICAgICAgICBzLnNldF9wcm94eShzb2Nrcy5TT0NLUzUsICIxMjcuMC4wLjEiLCBTT0NLU19QT1JULCByZG5zPVRydWUpCiAgICAgICAgcy5zZXR0aW1lb3V0KGJ1ZGdldCkKICAgICAgICBpZiBpOgogICAgICAgICAgICBwcmludChmIiAgcmV0cnkge2l9L3tsZW4oRElBTF9MQURERVIpIC0gMX0gIgogICAgICAgICAgICAgICAgICBmIih3YWl0aW5nIHVwIHRvIHtidWRnZXR9cyBmb3IgdGhlIGRlc2NyaXB0b3IpIiwKICAgICAgICAgICAgICAgICAgZmlsZT1zeXMuc3RkZXJyKQogICAgICAgIHRyeToKICAgICAgICAgICAgcy5jb25uZWN0KChob3N0ICsgIi5vbmlvbiIsIDgwKSkKICAgICAgICAgICAgcmV0dXJuIHMKICAgICAgICBleGNlcHQgRXhjZXB0aW9uIGFzIGV4YzoKICAgICAgICAgICAgbGFzdCA9IGV4YwogICAgICAgICAgICB0cnk6CiAgICAgICAgICAgICAgICBzLmNsb3NlKCkKICAgICAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgICAgIHBhc3MKICAgIHJhaXNlIENvbm5lY3Rpb25FcnJvcigKICAgICAgICBmImNhbm5vdCByZWFjaCB7dGFyZ2V0X29uaW9uWzoxNl19Li4uIGFmdGVyIHtsZW4oRElBTF9MQURERVIpfSBhdHRlbXB0czoge2xhc3R9XG4iCiAgICAgICAgZiIgIEEgcGVlciB0aGF0IGhhcyBvbmx5IGp1c3QgY29tZSBvbmxpbmUgY2FuIHRha2UgYSBjb3VwbGUgb2YgbWludXRlc1xuIgogICAgICAgIGYiICB0byBwdWJsaXNoIGl0cyBkZXNjcmlwdG9yLiBSZXRyeSBpbiBhIG1pbnV0ZSBiZWZvcmUgYXNzdW1pbmcgaXQgaXMgZG93bi5cbiIKICAgICAgICBmIiAgQ2hlY2sgdGhlIHBlZXIgaXMgcnVubmluZyBhbmQgdG9yIGlzIHVwIG9uIDEyNy4wLjAuMTp7U09DS1NfUE9SVH0uIikKCgpkZWYgc2VuZF90byh0YXJnZXRfb25pb24sIGJvZHksIGs9Tm9uZSk6CiAgICBrID0gayBvciBuZWVkX2tleXMoKSAgICAgICAgICAgICAjIG5ldmVyIHNpZ24gd2l0aCBhIGZyZXNobHkgbWludGVkIGtleQogICAgc29jayA9IGRpYWwodGFyZ2V0X29uaW9uKQogICAgdHJ5OgogICAgICAgIHNlbmRfbXNnKHNvY2ssIHsib3AiOiAiaGVsbG8ifSkKICAgICAgICBoZWxsbyA9IHJlY3ZfbXNnKHNvY2spCiAgICAgICAgaWYgbm90IGhlbGxvIG9yIG5vdCBoZWxsby5nZXQoIm9rIik6CiAgICAgICAgICAgIHJhaXNlIFJ1bnRpbWVFcnJvcihmImhlbGxvIHJlZnVzZWQ6IHtoZWxsb30iKQogICAgICAgIG5vbmNlID0gYjY0ZChoZWxsb1sibm9uY2UiXSkKICAgICAgICBzZW5kX21zZyhzb2NrLCB7Im9wIjogInNlbmQiLCAibm9uY2UiOiBoZWxsb1sibm9uY2UiXSwgImJvZHkiOiBib2R5LAogICAgICAgICAgICAgICAgICAgICAgICAicHVia2V5Ijogay5wdWJsaWMoKS50b19kaWN0KCksCiAgICAgICAgICAgICAgICAgICAgICAgICJzaWciOiBiNjRlKGsuc2lnbihub25jZSArIGJvZHkuZW5jb2RlKCJ1dGYtOCIpKSl9KQogICAgICAgIHJldHVybiByZWN2X21zZyhzb2NrKQogICAgZmluYWxseToKICAgICAgICB0cnk6CiAgICAgICAgICAgIHNvY2suY2xvc2UoKQogICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgIHBhc3MKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gY2xpIC0tCmRlZiBjbWRfc2VydmUoYSk6CiAgICBzZXJ2ZSgpCgoKZGVmIGNtZF9pbml0KGEpOgogICAgZXhpc3RlZCA9IG9zLnBhdGguZXhpc3RzKElERklMRSkKICAgIGsgPSBrZXlzKGNyZWF0ZT1UcnVlKQogICAgcHJpbnQoZiJ7J2V4aXN0aW5nJyBpZiBleGlzdGVkIGVsc2UgJ2NyZWF0ZWQnfSAge0lERklMRX0iKQogICAgcHJpbnQoZiJmaW5nZXJwcmludCAge2sucHVibGljKCkuZmluZ2VycHJpbnR9IikKICAgIGlmIGV4aXN0ZWQ6CiAgICAgICAgcHJpbnQoIm9uaW9uICAgICAgICB1bmNoYW5nZWQgKGlkZW50aXR5IHJldXNlZCkiKQoKCmRlZiBjbWRfd2hvYW1pKGEpOgogICAgayA9IGtleXMoKSAgICAgICAgICAgICAgICAgICAgICAjIG5ldmVyIGNyZWF0ZXMKICAgIHByaW50KGYib25pb24gICAgICAgIHtvbmlvbigpIG9yICcobm90IGNvbmZpZ3VyZWQpJ30iKQogICAgaWYgayBpcyBOb25lOgogICAgICAgIHByaW50KGYiZmluZ2VycHJpbnQgIChubyBpZGVudGl0eSB5ZXQgLSBydW46IGluYm94X2FnZW50LnB5IGluaXQpIikKICAgICAgICByYWlzZSBTeXN0ZW1FeGl0KDIpCiAgICBwcmludChmImZpbmdlcnByaW50ICB7ay5wdWJsaWMoKS5maW5nZXJwcmludH0iKQoKCmRlZiBjbWRfYWRkX3BlZXIoYSk6CiAgICBwID0gcGVlcnMoKQogICAgZnAgPSBhLmZpbmdlcnByaW50LnN0cmlwKCkubG93ZXIoKQogICAgaWYgbGVuKGZwKSAhPSAzMjoKICAgICAgICBzeXMuZXhpdChmImZpbmdlcnByaW50IG11c3QgYmUgMzIgaGV4IGNoYXJzIChnb3Qge2xlbihmcCl9KSIpCiAgICBpZiBub3QgYS5vbmlvbi5lbmRzd2l0aCgiLm9uaW9uIik6CiAgICAgICAgc3lzLmV4aXQoIi0tb25pb24gbXVzdCBlbmQgaW4gLm9uaW9uIikKICAgIHBbZnBdID0geyJvbmlvbiI6IGEub25pb24uc3RyaXAoKSwgImxhYmVsIjogYS5sYWJlbCBvciBmcFs6MTJdLAogICAgICAgICAgICAgImFkZGVkIjogdGltZS50aW1lKCl9CiAgICBzYXZlX3BlZXJzKHApCiAgICBwcmludChmImFsbG93bGlzdGVkIHtwW2ZwXVsnbGFiZWwnXX0gKHtmcFs6MTJdfS4uLikgLT4ge2Eub25pb259IikKCgpkZWYgY21kX3BlZXJzKGEpOgogICAgcCA9IHBlZXJzKCkKICAgIGlmIG5vdCBwOgogICAgICAgIHByaW50KCIobm8gcGVlcnMgYWxsb3dsaXN0ZWQpIikKICAgIGZvciBmcCwgdiBpbiBzb3J0ZWQocC5pdGVtcygpLCBrZXk9bGFtYmRhIGt2OiBrdlsxXS5nZXQoImxhYmVsIiwgIiIpKToKICAgICAgICBwcmludChmInt2LmdldCgnbGFiZWwnLCcnKToxOH0ge2ZwWzoxNl19Li4uICB7dlsnb25pb24nXX0iKQoKCmRlZiBfbXNncyhpbmNsdWRlX2FyY2hpdmVkPUZhbHNlKToKICAgIG91dCA9IFtdCiAgICBmb3IgZCwgYXJjaCBpbiAoKElOQk9YLCBGYWxzZSksIChBUkNISVZFLCBUcnVlKSk6CiAgICAgICAgaWYgbm90IG9zLnBhdGguaXNkaXIoZCk6CiAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgaWYgYXJjaCBhbmQgbm90IGluY2x1ZGVfYXJjaGl2ZWQ6CiAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgZm9yIG4gaW4gc29ydGVkKG9zLmxpc3RkaXIoZCkpOgogICAgICAgICAgICBpZiBuLmVuZHN3aXRoKCIuanNvbiIpOgogICAgICAgICAgICAgICAgdHJ5OgogICAgICAgICAgICAgICAgICAgIHdpdGggb3Blbihvcy5wYXRoLmpvaW4oZCwgbikpIGFzIGY6CiAgICAgICAgICAgICAgICAgICAgICAgIG0gPSBqc29uLmxvYWQoZikKICAgICAgICAgICAgICAgICAgICBtWyJfYXJjaGl2ZWQiXSA9IGFyY2gKICAgICAgICAgICAgICAgICAgICBvdXQuYXBwZW5kKG0pCiAgICAgICAgICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICAgICAgICAgIHBhc3MKICAgIHJldHVybiBzb3J0ZWQob3V0LCBrZXk9bGFtYmRhIG06IG0uZ2V0KCJyZWNlaXZlZCIsIDApKQoKCmRlZiBjbWRfaW5ib3goYSk6CiAgICBtcyA9IF9tc2dzKGEuYWxsKQogICAgaWYgbm90IG1zOgogICAgICAgIHByaW50KCIoaW5ib3ggZW1wdHkpIikKICAgIGZvciBtIGluIG1zOgogICAgICAgIHdoZW4gPSB0aW1lLnN0cmZ0aW1lKCIlWS0lbS0lZCAlSDolTSIsIHRpbWUubG9jYWx0aW1lKG0uZ2V0KCJyZWNlaXZlZCIsIDApKSkKICAgICAgICBwcmludChmInttWydpZCddfSAge3doZW59ICB7bS5nZXQoJ2Zyb21fbGFiZWwnLCc/Jyk6MTZ9ICIKICAgICAgICAgICAgICBmInsobS5nZXQoJ2JvZHknKSBvciAnJykucmVwbGFjZShjaHIoMTApLCcgJylbOjYwXX0iKQoKCmRlZiBjbWRfcmVhZChhKToKICAgIGZvciBtIGluIF9tc2dzKFRydWUpOgogICAgICAgIGlmIG1bImlkIl0gPT0gYS5pZDoKICAgICAgICAgICAgcHJpbnQoanNvbi5kdW1wcyhtLCBpbmRlbnQ9MikpCiAgICAgICAgICAgIHJldHVybgogICAgc3lzLmV4aXQoZiJubyBtZXNzYWdlIHthLmlkfSIpCgoKZGVmIGNtZF9hY2soYSk6CiAgICBmb3IgbiBpbiAob3MubGlzdGRpcihJTkJPWCkgaWYgb3MucGF0aC5pc2RpcihJTkJPWCkgZWxzZSBbXSk6CiAgICAgICAgaWYgYS5pZCBpbiBuOgogICAgICAgICAgICBvcy5yZXBsYWNlKG9zLnBhdGguam9pbihJTkJPWCwgbiksIG9zLnBhdGguam9pbihBUkNISVZFLCBuKSkKICAgICAgICAgICAgcHJpbnQoZiJhcmNoaXZlZCB7YS5pZH0iKQogICAgICAgICAgICByZXR1cm4KICAgIHN5cy5leGl0KGYibm8gdW5hcmNoaXZlZCBtZXNzYWdlIHthLmlkfSIpCgoKZGVmIGNtZF9zZW5kKGEpOgogICAgcCA9IHBlZXJzKCkKICAgIHRhcmdldCA9IE5vbmUKICAgIGZvciBmcCwgdiBpbiBwLml0ZW1zKCk6CiAgICAgICAgaWYgYS50byBpbiAoZnAsIHYuZ2V0KCJsYWJlbCIpLCBmcFs6MTJdKToKICAgICAgICAgICAgdGFyZ2V0ID0gdgogICAgICAgICAgICBicmVhawogICAgaWYgdGFyZ2V0IGlzIE5vbmU6CiAgICAgICAgc3lzLmV4aXQoZiJ1bmtub3duIHBlZXIge2EudG8hcn07IHRyeTogaW5ib3hfYWdlbnQucHkgcGVlcnMiKQogICAgcmVwbHkgPSBzZW5kX3RvKHRhcmdldFsib25pb24iXSwgYS5ib2R5KQogICAgcHJpbnQoanNvbi5kdW1wcyhyZXBseSwgaW5kZW50PTIpKQogICAgc3lzLmV4aXQoMCBpZiByZXBseSBhbmQgcmVwbHkuZ2V0KCJvayIpIGVsc2UgMSkKCgpkZWYgbWFpbigpOgogICAgYXAgPSBhcmdwYXJzZS5Bcmd1bWVudFBhcnNlcihkZXNjcmlwdGlvbj1fX2RvY19fLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBmb3JtYXR0ZXJfY2xhc3M9YXJncGFyc2UuUmF3RGVzY3JpcHRpb25IZWxwRm9ybWF0dGVyKQogICAgcyA9IGFwLmFkZF9zdWJwYXJzZXJzKGRlc3Q9ImNtZCIsIHJlcXVpcmVkPVRydWUpCiAgICBzLmFkZF9wYXJzZXIoInNlcnZlIikuc2V0X2RlZmF1bHRzKGZuPWNtZF9zZXJ2ZSkKICAgIHMuYWRkX3BhcnNlcigid2hvYW1pIikuc2V0X2RlZmF1bHRzKGZuPWNtZF93aG9hbWkpCiAgICBzLmFkZF9wYXJzZXIoImluaXQiKS5zZXRfZGVmYXVsdHMoZm49Y21kX2luaXQpCiAgICBzLmFkZF9wYXJzZXIoInBlZXJzIikuc2V0X2RlZmF1bHRzKGZuPWNtZF9wZWVycykKICAgIHAgPSBzLmFkZF9wYXJzZXIoImFkZC1wZWVyIikKICAgIHAuYWRkX2FyZ3VtZW50KCJmaW5nZXJwcmludCIpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1vbmlvbiIsIHJlcXVpcmVkPVRydWUpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1sYWJlbCIsIGRlZmF1bHQ9IiIpCiAgICBwLnNldF9kZWZhdWx0cyhmbj1jbWRfYWRkX3BlZXIpCiAgICBwID0gcy5hZGRfcGFyc2VyKCJpbmJveCIpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1hbGwiLCBhY3Rpb249InN0b3JlX3RydWUiKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX2luYm94KQogICAgcCA9IHMuYWRkX3BhcnNlcigicmVhZCIpCiAgICBwLmFkZF9hcmd1bWVudCgiaWQiKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX3JlYWQpCiAgICBwID0gcy5hZGRfcGFyc2VyKCJhY2siKQogICAgcC5hZGRfYXJndW1lbnQoImlkIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9hY2spCiAgICBwID0gcy5hZGRfcGFyc2VyKCJzZW5kIikKICAgIHAuYWRkX2FyZ3VtZW50KCItLXRvIiwgcmVxdWlyZWQ9VHJ1ZSkKICAgIHAuYWRkX2FyZ3VtZW50KCItLWJvZHkiLCByZXF1aXJlZD1UcnVlKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX3NlbmQpCiAgICBhID0gYXAucGFyc2VfYXJncygpCiAgICBhLmZuKGEpCgoKaWYgX19uYW1lX18gPT0gIl9fbWFpbl9fIjoKICAgIG1haW4oKQo='
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
