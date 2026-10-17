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
$PAYLOAD_INBOX='IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwoiIiJpbmJveF9hZ2VudC5weSAtLSBhIHZlcmlmaWVkIG1lc3NhZ2UgaW5ib3ggYmVoaW5kIGEgdG9yIGhpZGRlbiBzZXJ2aWNlLgoKUnVucyBvbiBIRVIgbWFjaGluZS4gTGlzdGVucyBvbiBhIHBsYWluIGxvY2FsaG9zdCBUQ1AgcG9ydDsgdG9yIGZvcndhcmRzIHRoZQpoaWRkZW4gc2VydmljZSB0byBpdC4gU2VydmluZyBuZWVkcyBubyB0b3IgQVBJIGF0IGFsbCAtLSBubyBjb250cm9sIHBvcnQsIG5vCkFERF9PTklPTiwgbm8ga2V5cyB0byBtYW5hZ2UuIE9ubHkgb3V0Ym91bmQgc2VuZHMgdG91Y2ggdG9yLCB2aWEgU09DS1MuCgpTZWN1cml0eSBtb2RlbAogICAgQSBtZXNzYWdlIGlzIGFjY2VwdGVkIG9ubHkgaWYgdGhlIHNlbmRlciBwcm92ZXMgcG9zc2Vzc2lvbiBvZiBhbgogICAgYWxsb3dsaXN0ZWQgRWQyNTUxOSBrZXkgb3ZlciBhIG9uZS11c2Ugbm9uY2UuIFRoZSBzZW5kZXIncyBjbGFpbWVkIG9uaW9uCiAgICBhZGRyZXNzIGlzIG5ldmVyIHRydXN0ZWQgZm9yIHJvdXRpbmcuCgpVc2FnZQogICAgaW5ib3hfYWdlbnQucHkgc2VydmUgICAgICAgICAgICAgICAgIHJ1biB0aGUgZGFlbW9uCiAgICBpbmJveF9hZ2VudC5weSB3aG9hbWkgICAgICAgICAgICAgICAgcHJpbnQgdGhpcyBtYWNoaW5lJ3Mgb25pb24gKyBmaW5nZXJwcmludAogICAgaW5ib3hfYWdlbnQucHkgYWRkLXBlZXIgRlAgLS1vbmlvbiBBIGFsbG93IGEgcGVlciB0byBzZW5kCiAgICBpbmJveF9hZ2VudC5weSBwZWVycwogICAgaW5ib3hfYWdlbnQucHkgaW5ib3gKICAgIGluYm94X2FnZW50LnB5IHJlYWQgPGlkPgogICAgaW5ib3hfYWdlbnQucHkgYWNrIDxpZD4KICAgIGluYm94X2FnZW50LnB5IHNlbmQgLS10byBMQUJFTCAtLWJvZHkgVEVYVAoiIiIKaW1wb3J0IGFyZ3BhcnNlCmltcG9ydCBiYXNlNjQKaW1wb3J0IGpzb24KaW1wb3J0IG9zCmltcG9ydCBzZWNyZXRzCmltcG9ydCBzb2NrZXQKaW1wb3J0IHN5cwppbXBvcnQgdGhyZWFkaW5nCmltcG9ydCB0aW1lCmltcG9ydCB1dWlkCgpmcm9tIHdpcmUgaW1wb3J0IEFnZW50S2V5cywgUHVibGljSWRlbnRpdHkKCkhPTUUgPSBvcy5lbnZpcm9uLmdldCgiVE9SQUdFTlRTX0hPTUUiLCBvcy5wYXRoLmV4cGFuZHVzZXIoIn4vLnRvcmFnZW50cyIpKQpTVEFURSA9IG9zLnBhdGguam9pbihIT01FLCAic3RhdGUiKQpJTkJPWCA9IG9zLnBhdGguam9pbihTVEFURSwgImluYm94IikKQVJDSElWRSA9IG9zLnBhdGguam9pbihTVEFURSwgImFyY2hpdmUiKQpQRUVSUyA9IG9zLnBhdGguam9pbihTVEFURSwgInBlZXJzLmpzb24iKQpJREZJTEUgPSBvcy5wYXRoLmpvaW4oU1RBVEUsICJpZGVudGl0eS5qc29uIikKSE9TVE5BTUVfRklMRSA9IG9zLnBhdGguam9pbihIT01FLCAiaHMiLCAiaG9zdG5hbWUiKQoKQ09ORklHID0gb3MucGF0aC5qb2luKFNUQVRFLCAiY29uZmlnLmpzb24iKQoKCmRlZiBfaW5zdGFsbGVkX2NvbmZpZygpOgogICAgIiIiUmVhZCB0aGUgcG9ydHMgdGhlIGluc3RhbGxlciBhY3R1YWxseSBjb25maWd1cmVkLgoKICAgIFRoaXMgZXhpc3RzIGJlY2F1c2UgdGhlIENMSSBhbmQgdGhlIGRhZW1vbiBtdXN0IGFncmVlIG9uIHRoZSBTT0NLUyBwb3J0IGFuZAogICAgdGhlIGRhZW1vbiBpcyB0aGUgb25seSBvbmUgdGhhdCBnZXRzIFRPUkFHRU5UU19TT0NLUyBmcm9tIGl0cyBzZXJ2aWNlIHVuaXQuCiAgICBUaGUgb2xkIGZhbGxiYWNrIHdhcyA5MDUwIHdoaWxlIHRoZSBpbnN0YWxsZXIgd3JpdGVzIDkwNjEsIHNvIGV2ZXJ5IGJhcmUKICAgIGBzZW5kYC9gaW5ib3hgIGRpZWQgd2l0aCAiQ29ubmVjdGlvbiByZWZ1c2VkIiB1bnRpbCB0aGUgdXNlciBleHBvcnRlZCB0aGUKICAgIHZhcmlhYmxlIGJ5IGhhbmQuIEVudiBzdGlsbCB3aW5zOyB0aGUgcmVjb3JkZWQgY29uZmlnIGlzIHRoZSBmYWxsYmFjay4KICAgICIiIgogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihDT05GSUcpIGFzIGY6CiAgICAgICAgICAgIHJldHVybiBqc29uLmxvYWQoZikKICAgIGV4Y2VwdCAoT1NFcnJvciwgVmFsdWVFcnJvcik6CiAgICAgICAgcmV0dXJuIHt9CgoKX2NmZyA9IF9pbnN0YWxsZWRfY29uZmlnKCkKTElTVEVOX1BPUlQgPSBpbnQob3MuZW52aXJvbi5nZXQoIlRPUkFHRU5UU19QT1JUIikgb3IgX2NmZy5nZXQoImxvY2FsX3BvcnQiKSBvciA4Nzk5KQpTT0NLU19QT1JUID0gaW50KG9zLmVudmlyb24uZ2V0KCJUT1JBR0VOVFNfU09DS1MiKSBvciBfY2ZnLmdldCgic29ja3NfcG9ydCIpIG9yIDkwNTApCk5PTkNFX1RUTCA9IDE4MC4wCgpiNjRlID0gbGFtYmRhIGI6IGJhc2U2NC5iNjRlbmNvZGUoYikuZGVjb2RlKCJhc2NpaSIpCmI2NGQgPSBsYW1iZGEgczogYmFzZTY0LmI2NGRlY29kZShzKQoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBzdGF0ZSAtLS0KZGVmIGRpcnMoKToKICAgIGZvciBkIGluIChTVEFURSwgSU5CT1gsIEFSQ0hJVkUpOgogICAgICAgIG9zLm1ha2VkaXJzKGQsIGV4aXN0X29rPVRydWUpCgoKZGVmIGtleXMoKToKICAgIGRpcnMoKQogICAgaWYgb3MucGF0aC5leGlzdHMoSURGSUxFKToKICAgICAgICB3aXRoIG9wZW4oSURGSUxFKSBhcyBmOgogICAgICAgICAgICByZXR1cm4gQWdlbnRLZXlzLmZyb21fc2VjcmV0X2RpY3QoanNvbi5sb2FkKGYpKQogICAgayA9IEFnZW50S2V5cy5nZW5lcmF0ZSgpCiAgICBmZCA9IG9zLm9wZW4oSURGSUxFLCBvcy5PX1dST05MWSB8IG9zLk9fQ1JFQVQgfCBvcy5PX1RSVU5DLCAwbzYwMCkKICAgIHdpdGggb3MuZmRvcGVuKGZkLCAidyIpIGFzIGY6CiAgICAgICAganNvbi5kdW1wKGsudG9fc2VjcmV0X2RpY3QoKSwgZikKICAgIHJldHVybiBrCgoKZGVmIHBlZXJzKCk6CiAgICBpZiBub3Qgb3MucGF0aC5leGlzdHMoUEVFUlMpOgogICAgICAgIHJldHVybiB7fQogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihQRUVSUykgYXMgZjoKICAgICAgICAgICAgcmV0dXJuIGpzb24ubG9hZChmKQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICByZXR1cm4ge30KCgpkZWYgc2F2ZV9wZWVycyhwKToKICAgIGRpcnMoKQogICAgdG1wID0gUEVFUlMgKyAiLnRtcCIKICAgIHdpdGggb3Blbih0bXAsICJ3IikgYXMgZjoKICAgICAgICBqc29uLmR1bXAocCwgZiwgaW5kZW50PTIsIHNvcnRfa2V5cz1UcnVlKQogICAgb3MucmVwbGFjZSh0bXAsIFBFRVJTKQoKCmRlZiBvbmlvbigpOgogICAgdHJ5OgogICAgICAgIHdpdGggb3BlbihIT1NUTkFNRV9GSUxFKSBhcyBmOgogICAgICAgICAgICByZXR1cm4gZi5yZWFkKCkuc3RyaXAoKQogICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICByZXR1cm4gTm9uZQoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIGZyYW1pbmcgLS0KZGVmIHNlbmRfbXNnKHNvY2ssIG9iaik6CiAgICBkYXRhID0ganNvbi5kdW1wcyhvYmopLmVuY29kZSgpCiAgICBzb2NrLnNlbmRhbGwobGVuKGRhdGEpLnRvX2J5dGVzKDQsICJiaWciKSArIGRhdGEpCgoKTUFYX0ZSQU1FID0gMTYgKiAxMDI0ICogMTAyNCAgIyBzYW1lIGNlaWxpbmcgdG9yYWdlbnRzIHVzZXM7IHN0b3BzIGEgaG9zdGlsZSBoZWFkZXIKCgpkZWYgcmVjdl9tc2coc29jayk6CiAgICBoZHIgPSBfcmVhZF9leGFjdChzb2NrLCA0KQogICAgaWYgaGRyIGlzIE5vbmU6CiAgICAgICAgcmV0dXJuIE5vbmUKICAgIG4gPSBpbnQuZnJvbV9ieXRlcyhoZHIsICJiaWciKQogICAgaWYgbiA+IE1BWF9GUkFNRToKICAgICAgICByYWlzZSBWYWx1ZUVycm9yKGYiZGVjbGFyZWQgZnJhbWUge259IGV4Y2VlZHMge01BWF9GUkFNRX0iKQogICAgYm9keSA9IF9yZWFkX2V4YWN0KHNvY2ssIG4pCiAgICBpZiBib2R5IGlzIE5vbmU6CiAgICAgICAgcmV0dXJuIE5vbmUKICAgIHJldHVybiBqc29uLmxvYWRzKGJvZHkuZGVjb2RlKCkpCgoKZGVmIF9yZWFkX2V4YWN0KHNvY2ssIG4pOgogICAgYnVmID0gYiIiCiAgICB3aGlsZSBsZW4oYnVmKSA8IG46CiAgICAgICAgY2h1bmsgPSBzb2NrLnJlY3YobiAtIGxlbihidWYpKQogICAgICAgIGlmIG5vdCBjaHVuazoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKICAgICAgICBidWYgKz0gY2h1bmsKICAgIHJldHVybiBidWYKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gbm9uY2VzIC0tCmNsYXNzIE5vbmNlczoKICAgIGRlZiBfX2luaXRfXyhzZWxmKToKICAgICAgICBzZWxmLl9kLCBzZWxmLl9sb2NrID0ge30sIHRocmVhZGluZy5Mb2NrKCkKCiAgICBkZWYgaXNzdWUoc2VsZik6CiAgICAgICAgbiA9IHNlY3JldHMudG9rZW5fYnl0ZXMoMzIpCiAgICAgICAgd2l0aCBzZWxmLl9sb2NrOgogICAgICAgICAgICBub3cgPSB0aW1lLnRpbWUoKQogICAgICAgICAgICBzZWxmLl9kID0ge2s6IHYgZm9yIGssIHYgaW4gc2VsZi5fZC5pdGVtcygpIGlmIHYgPiBub3d9CiAgICAgICAgICAgIHNlbGYuX2RbYjY0ZShuKV0gPSBub3cgKyBOT05DRV9UVEwKICAgICAgICByZXR1cm4gbgoKICAgIGRlZiBjb25zdW1lKHNlbGYsIHRva2VuKToKICAgICAgICB3aXRoIHNlbGYuX2xvY2s6CiAgICAgICAgICAgIGV4cCA9IHNlbGYuX2QucG9wKHRva2VuLCBOb25lKQogICAgICAgIGlmIGV4cCBpcyBOb25lIG9yIGV4cCA8IHRpbWUudGltZSgpOgogICAgICAgICAgICByZXR1cm4gTm9uZQogICAgICAgIHRyeToKICAgICAgICAgICAgcmV0dXJuIGI2NGQodG9rZW4pCiAgICAgICAgZXhjZXB0IEV4Y2VwdGlvbjoKICAgICAgICAgICAgcmV0dXJuIE5vbmUKCgojIC0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0gc2VydmVyIC0tCmNsYXNzIEluYm94OgogICAgZGVmIF9faW5pdF9fKHNlbGYpOgogICAgICAgIHNlbGYuayA9IGtleXMoKQogICAgICAgIHNlbGYubm9uY2VzID0gTm9uY2VzKCkKICAgICAgICBzZWxmLnBlZXJzID0gcGVlcnMoKQogICAgICAgIHNlbGYubG9jayA9IHRocmVhZGluZy5Mb2NrKCkKICAgICAgICBzZWxmLmFjY2VwdGVkID0gc2VsZi5yZWplY3RlZCA9IDAKICAgICAgICBzZWxmLmFkZHIgPSBvbmlvbigpCiAgICAgICAgc2VsZi5fcGVlcnNfbXRpbWUgPSBzZWxmLl9tdGltZSgpCgogICAgZGVmIF9tdGltZShzZWxmKToKICAgICAgICB0cnk6CiAgICAgICAgICAgIHJldHVybiBvcy5wYXRoLmdldG10aW1lKFBFRVJTKQogICAgICAgIGV4Y2VwdCBPU0Vycm9yOgogICAgICAgICAgICByZXR1cm4gTm9uZQoKICAgIGRlZiBfcmVsb2FkX3BlZXJzX2lmX2NoYW5nZWQoc2VsZik6CiAgICAgICAgIiIiUGljayB1cCBgYWRkLXBlZXJgIHdpdGhvdXQgcmVzdGFydGluZyB0aGUgZGFlbW9uLiIiIgogICAgICAgIG5vdyA9IHNlbGYuX210aW1lKCkKICAgICAgICBpZiBub3cgIT0gc2VsZi5fcGVlcnNfbXRpbWU6CiAgICAgICAgICAgIHdpdGggc2VsZi5sb2NrOgogICAgICAgICAgICAgICAgc2VsZi5wZWVycyA9IHBlZXJzKCkKICAgICAgICAgICAgICAgIHNlbGYuX3BlZXJzX210aW1lID0gbm93CiAgICAgICAgICAgIHByaW50KGYiW2luYm94XSBwZWVyIGxpc3QgcmVsb2FkZWQgKHtsZW4oc2VsZi5wZWVycyl9IGFsbG93ZWQpIiwgZmx1c2g9VHJ1ZSkKCiAgICBkZWYgaGFuZGxlKHNlbGYsIHJlcSk6CiAgICAgICAgb3AgPSByZXEuZ2V0KCJvcCIpCiAgICAgICAgaWYgb3AgPT0gInBpbmciOgogICAgICAgICAgICByZXR1cm4geyJvayI6IFRydWUsICJzZXJ2aWNlIjogInRvcmFnZW50cy1pbmJveCIsICJvbmlvbiI6IHNlbGYuYWRkciwKICAgICAgICAgICAgICAgICAgICAiZmluZ2VycHJpbnQiOiBzZWxmLmsucHVibGljKCkuZmluZ2VycHJpbnR9CiAgICAgICAgaWYgb3AgPT0gImhlbGxvIjoKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBUcnVlLCAibm9uY2UiOiBiNjRlKHNlbGYubm9uY2VzLmlzc3VlKCkpfQogICAgICAgIGlmIG9wID09ICJzZW5kIjoKICAgICAgICAgICAgcmV0dXJuIHNlbGYuX2FjY2VwdChyZXEpCiAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogZiJ1bmtub3duIG9wIHtvcCFyfSJ9CgogICAgZGVmIF9hY2NlcHQoc2VsZiwgcmVxKToKICAgICAgICB0b2tlbiwgYm9keSwgcHViLCBzaWcgPSAocmVxLmdldCgibm9uY2UiKSwgcmVxLmdldCgiYm9keSIpLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICByZXEuZ2V0KCJwdWJrZXkiKSwgcmVxLmdldCgic2lnIikpCiAgICAgICAgaWYgbm90IGFsbChbdG9rZW4sIGlzaW5zdGFuY2UoYm9keSwgc3RyKSwgcHViLCBzaWddKToKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJtYWxmb3JtZWQgc2VuZCJ9CgogICAgICAgIG5vbmNlID0gc2VsZi5ub25jZXMuY29uc3VtZSh0b2tlbikKICAgICAgICBpZiBub25jZSBpcyBOb25lOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogInN0YWxlIG9yIHVua25vd24gbm9uY2UifQoKICAgICAgICB0cnk6CiAgICAgICAgICAgIHNlbmRlciA9IFB1YmxpY0lkZW50aXR5LmZyb21fZGljdChwdWIpCiAgICAgICAgICAgIHNpZ25hdHVyZSA9IGI2NGQoc2lnKQogICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgIHNlbGYucmVqZWN0ZWQgKz0gMQogICAgICAgICAgICByZXR1cm4geyJvayI6IEZhbHNlLCAiZXJyb3IiOiAiYmFkIHB1YmtleSBvciBzaWduYXR1cmUgZW5jb2RpbmcifQoKICAgICAgICBpZiBub3Qgc2VuZGVyLnZlcmlmeShub25jZSArIGJvZHkuZW5jb2RlKCJ1dGYtOCIpLCBzaWduYXR1cmUpOgogICAgICAgICAgICBzZWxmLnJlamVjdGVkICs9IDEKICAgICAgICAgICAgcmV0dXJuIHsib2siOiBGYWxzZSwgImVycm9yIjogInNpZ25hdHVyZSBkb2VzIG5vdCB2ZXJpZnkifQoKICAgICAgICBmcCA9IHNlbmRlci5maW5nZXJwcmludAogICAgICAgIHNlbGYuX3JlbG9hZF9wZWVyc19pZl9jaGFuZ2VkKCkKICAgICAgICB3aXRoIHNlbGYubG9jazoKICAgICAgICAgICAgcGVlciA9IHNlbGYucGVlcnMuZ2V0KGZwKQogICAgICAgIGlmIHBlZXIgaXMgTm9uZToKICAgICAgICAgICAgc2VsZi5yZWplY3RlZCArPSAxCiAgICAgICAgICAgIHJldHVybiB7Im9rIjogRmFsc2UsICJlcnJvciI6ICJzZW5kZXIgbm90IG9uIGFsbG93bGlzdCIsCiAgICAgICAgICAgICAgICAgICAgImZpbmdlcnByaW50IjogZnB9CgogICAgICAgIG1pZCA9IHV1aWQudXVpZDQoKS5oZXhbOjEyXQogICAgICAgIHJlYyA9IHsiaWQiOiBtaWQsICJyZWNlaXZlZCI6IHRpbWUudGltZSgpLCAiZnJvbV9maW5nZXJwcmludCI6IGZwLAogICAgICAgICAgICAgICAiZnJvbV9sYWJlbCI6IHBlZXIuZ2V0KCJsYWJlbCIsICIiKSwgImZyb21fb25pb24iOiBwZWVyLmdldCgib25pb24iLCAiIiksCiAgICAgICAgICAgICAgICJib2R5IjogYm9keX0KICAgICAgICBwYXRoID0gb3MucGF0aC5qb2luKElOQk9YLCBmInt0aW1lLnRpbWUoKTouMGZ9LXttaWR9Lmpzb24iKQogICAgICAgIHdpdGggb3BlbihwYXRoICsgIi50bXAiLCAidyIpIGFzIGY6CiAgICAgICAgICAgIGpzb24uZHVtcChyZWMsIGYsIGluZGVudD0yKQogICAgICAgIG9zLnJlcGxhY2UocGF0aCArICIudG1wIiwgcGF0aCkKICAgICAgICBzZWxmLmFjY2VwdGVkICs9IDEKICAgICAgICBwcmludChmIltpbmJveF0gK3ttaWR9IGZyb20ge3BlZXIuZ2V0KCdsYWJlbCcpIG9yIGZwWzoxMl19IiwgZmx1c2g9VHJ1ZSkKICAgICAgICByZXR1cm4geyJvayI6IFRydWUsICJpZCI6IG1pZH0KCgpkZWYgY2xpZW50X2xvb3AoY29ubiwgYm94KToKICAgIHRyeToKICAgICAgICB3aGlsZSBUcnVlOgogICAgICAgICAgICByZXEgPSByZWN2X21zZyhjb25uKQogICAgICAgICAgICBpZiByZXEgaXMgTm9uZToKICAgICAgICAgICAgICAgIGJyZWFrCiAgICAgICAgICAgIHRyeToKICAgICAgICAgICAgICAgIHJlcGx5ID0gYm94LmhhbmRsZShyZXEpCiAgICAgICAgICAgIGV4Y2VwdCBFeGNlcHRpb24gYXMgZXhjOgogICAgICAgICAgICAgICAgcmVwbHkgPSB7Im9rIjogRmFsc2UsICJlcnJvciI6IGYiaGFuZGxlcjoge2V4Y30ifQogICAgICAgICAgICBzZW5kX21zZyhjb25uLCByZXBseSkKICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgcGFzcwogICAgZmluYWxseToKICAgICAgICB0cnk6CiAgICAgICAgICAgIGNvbm4uY2xvc2UoKQogICAgICAgIGV4Y2VwdCBFeGNlcHRpb246CiAgICAgICAgICAgIHBhc3MKCgpkZWYgc2VydmUoKToKICAgIGJveCA9IEluYm94KCkKICAgIHNydiA9IHNvY2tldC5zb2NrZXQoc29ja2V0LkFGX0lORVQsIHNvY2tldC5TT0NLX1NUUkVBTSkKICAgIHNydi5zZXRzb2Nrb3B0KHNvY2tldC5TT0xfU09DS0VULCBzb2NrZXQuU09fUkVVU0VBRERSLCAxKQogICAgc3J2LmJpbmQoKCIxMjcuMC4wLjEiLCBMSVNURU5fUE9SVCkpCiAgICBzcnYubGlzdGVuKDE2KQogICAgcHJpbnQoZiJsaXN0ZW5pbmcgMTI3LjAuMC4xOntMSVNURU5fUE9SVH0iLCBmbHVzaD1UcnVlKQogICAgcHJpbnQoZiJvbmlvbiAgICAgIHtib3guYWRkciBvciAnKGhpZGRlbiBzZXJ2aWNlIG5vdCBjb25maWd1cmVkIHlldCknfSIsIGZsdXNoPVRydWUpCiAgICBwcmludChmImZpbmdlcnByaW50IHtib3guay5wdWJsaWMoKS5maW5nZXJwcmludH0iLCBmbHVzaD1UcnVlKQogICAgcHJpbnQoZiJwZWVycyAgICAgIHtsZW4oYm94LnBlZXJzKX0iLCBmbHVzaD1UcnVlKQogICAgdHJ5OgogICAgICAgIHdoaWxlIFRydWU6CiAgICAgICAgICAgIGNvbm4sIF8gPSBzcnYuYWNjZXB0KCkKICAgICAgICAgICAgdGhyZWFkaW5nLlRocmVhZCh0YXJnZXQ9Y2xpZW50X2xvb3AsIGFyZ3M9KGNvbm4sIGJveCksIGRhZW1vbj1UcnVlKS5zdGFydCgpCiAgICBleGNlcHQgS2V5Ym9hcmRJbnRlcnJ1cHQ6CiAgICAgICAgcGFzcwogICAgZmluYWxseToKICAgICAgICBzcnYuY2xvc2UoKQoKCiMgLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLSBjbGllbnQgLS0KZGVmIGRpYWwodGFyZ2V0X29uaW9uLCB0aW1lb3V0PTEyMCk6CiAgICAiIiJQbGFpbiBTT0NLUzUgZGlhbCB0aHJvdWdoIHRoZSBsb2NhbCB0b3IuIE5vIHRvciBBUEksIGp1c3Qgc29ja3MuIiIiCiAgICBpbXBvcnQgc29ja3MKICAgIGhvc3QgPSB0YXJnZXRfb25pb25bOi02XSBpZiB0YXJnZXRfb25pb24uZW5kc3dpdGgoIi5vbmlvbiIpIGVsc2UgdGFyZ2V0X29uaW9uCiAgICBsYXN0ID0gTm9uZQogICAgZm9yIGF0dGVtcHQgaW4gcmFuZ2UoNCk6CiAgICAgICAgcyA9IHNvY2tzLnNvY2tzb2NrZXQoKQogICAgICAgIHMuc2V0X3Byb3h5KHNvY2tzLlNPQ0tTNSwgIjEyNy4wLjAuMSIsIFNPQ0tTX1BPUlQsIHJkbnM9VHJ1ZSkKICAgICAgICBzLnNldHRpbWVvdXQobWF4KHRpbWVvdXQgLyA0LCAyMCkpCiAgICAgICAgdHJ5OgogICAgICAgICAgICBzLmNvbm5lY3QoKGhvc3QgKyAiLm9uaW9uIiwgODApKQogICAgICAgICAgICByZXR1cm4gcwogICAgICAgIGV4Y2VwdCBFeGNlcHRpb24gYXMgZXhjOgogICAgICAgICAgICBsYXN0ID0gZXhjCiAgICAgICAgICAgIHRyeToKICAgICAgICAgICAgICAgIHMuY2xvc2UoKQogICAgICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICAgICAgcGFzcwogICAgICAgICAgICB0aW1lLnNsZWVwKDIpCiAgICByYWlzZSBDb25uZWN0aW9uRXJyb3IoZiJjYW5ub3QgcmVhY2gge3RhcmdldF9vbmlvbls6MTZdfS4uLjoge2xhc3R9IikKCgpkZWYgc2VuZF90byh0YXJnZXRfb25pb24sIGJvZHksIGs9Tm9uZSk6CiAgICBrID0gayBvciBrZXlzKCkKICAgIHNvY2sgPSBkaWFsKHRhcmdldF9vbmlvbikKICAgIHRyeToKICAgICAgICBzZW5kX21zZyhzb2NrLCB7Im9wIjogImhlbGxvIn0pCiAgICAgICAgaGVsbG8gPSByZWN2X21zZyhzb2NrKQogICAgICAgIGlmIG5vdCBoZWxsbyBvciBub3QgaGVsbG8uZ2V0KCJvayIpOgogICAgICAgICAgICByYWlzZSBSdW50aW1lRXJyb3IoZiJoZWxsbyByZWZ1c2VkOiB7aGVsbG99IikKICAgICAgICBub25jZSA9IGI2NGQoaGVsbG9bIm5vbmNlIl0pCiAgICAgICAgc2VuZF9tc2coc29jaywgeyJvcCI6ICJzZW5kIiwgIm5vbmNlIjogaGVsbG9bIm5vbmNlIl0sICJib2R5IjogYm9keSwKICAgICAgICAgICAgICAgICAgICAgICAgInB1YmtleSI6IGsucHVibGljKCkudG9fZGljdCgpLAogICAgICAgICAgICAgICAgICAgICAgICAic2lnIjogYjY0ZShrLnNpZ24obm9uY2UgKyBib2R5LmVuY29kZSgidXRmLTgiKSkpfSkKICAgICAgICByZXR1cm4gcmVjdl9tc2coc29jaykKICAgIGZpbmFsbHk6CiAgICAgICAgdHJ5OgogICAgICAgICAgICBzb2NrLmNsb3NlKCkKICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICBwYXNzCgoKIyAtLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIGNsaSAtLQpkZWYgY21kX3NlcnZlKGEpOgogICAgc2VydmUoKQoKCmRlZiBjbWRfd2hvYW1pKGEpOgogICAgayA9IGtleXMoKQogICAgcHJpbnQoZiJvbmlvbiAgICAgICAge29uaW9uKCkgb3IgJyhub3QgY29uZmlndXJlZCknfSIpCiAgICBwcmludChmImZpbmdlcnByaW50ICB7ay5wdWJsaWMoKS5maW5nZXJwcmludH0iKQoKCmRlZiBjbWRfYWRkX3BlZXIoYSk6CiAgICBwID0gcGVlcnMoKQogICAgZnAgPSBhLmZpbmdlcnByaW50LnN0cmlwKCkubG93ZXIoKQogICAgaWYgbGVuKGZwKSAhPSAzMjoKICAgICAgICBzeXMuZXhpdChmImZpbmdlcnByaW50IG11c3QgYmUgMzIgaGV4IGNoYXJzIChnb3Qge2xlbihmcCl9KSIpCiAgICBpZiBub3QgYS5vbmlvbi5lbmRzd2l0aCgiLm9uaW9uIik6CiAgICAgICAgc3lzLmV4aXQoIi0tb25pb24gbXVzdCBlbmQgaW4gLm9uaW9uIikKICAgIHBbZnBdID0geyJvbmlvbiI6IGEub25pb24uc3RyaXAoKSwgImxhYmVsIjogYS5sYWJlbCBvciBmcFs6MTJdLAogICAgICAgICAgICAgImFkZGVkIjogdGltZS50aW1lKCl9CiAgICBzYXZlX3BlZXJzKHApCiAgICBwcmludChmImFsbG93bGlzdGVkIHtwW2ZwXVsnbGFiZWwnXX0gKHtmcFs6MTJdfS4uLikgLT4ge2Eub25pb259IikKCgpkZWYgY21kX3BlZXJzKGEpOgogICAgcCA9IHBlZXJzKCkKICAgIGlmIG5vdCBwOgogICAgICAgIHByaW50KCIobm8gcGVlcnMgYWxsb3dsaXN0ZWQpIikKICAgIGZvciBmcCwgdiBpbiBzb3J0ZWQocC5pdGVtcygpLCBrZXk9bGFtYmRhIGt2OiBrdlsxXS5nZXQoImxhYmVsIiwgIiIpKToKICAgICAgICBwcmludChmInt2LmdldCgnbGFiZWwnLCcnKToxOH0ge2ZwWzoxNl19Li4uICB7dlsnb25pb24nXX0iKQoKCmRlZiBfbXNncyhpbmNsdWRlX2FyY2hpdmVkPUZhbHNlKToKICAgIG91dCA9IFtdCiAgICBmb3IgZCwgYXJjaCBpbiAoKElOQk9YLCBGYWxzZSksIChBUkNISVZFLCBUcnVlKSk6CiAgICAgICAgaWYgbm90IG9zLnBhdGguaXNkaXIoZCk6CiAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgaWYgYXJjaCBhbmQgbm90IGluY2x1ZGVfYXJjaGl2ZWQ6CiAgICAgICAgICAgIGNvbnRpbnVlCiAgICAgICAgZm9yIG4gaW4gc29ydGVkKG9zLmxpc3RkaXIoZCkpOgogICAgICAgICAgICBpZiBuLmVuZHN3aXRoKCIuanNvbiIpOgogICAgICAgICAgICAgICAgdHJ5OgogICAgICAgICAgICAgICAgICAgIHdpdGggb3Blbihvcy5wYXRoLmpvaW4oZCwgbikpIGFzIGY6CiAgICAgICAgICAgICAgICAgICAgICAgIG0gPSBqc29uLmxvYWQoZikKICAgICAgICAgICAgICAgICAgICBtWyJfYXJjaGl2ZWQiXSA9IGFyY2gKICAgICAgICAgICAgICAgICAgICBvdXQuYXBwZW5kKG0pCiAgICAgICAgICAgICAgICBleGNlcHQgRXhjZXB0aW9uOgogICAgICAgICAgICAgICAgICAgIHBhc3MKICAgIHJldHVybiBzb3J0ZWQob3V0LCBrZXk9bGFtYmRhIG06IG0uZ2V0KCJyZWNlaXZlZCIsIDApKQoKCmRlZiBjbWRfaW5ib3goYSk6CiAgICBtcyA9IF9tc2dzKGEuYWxsKQogICAgaWYgbm90IG1zOgogICAgICAgIHByaW50KCIoaW5ib3ggZW1wdHkpIikKICAgIGZvciBtIGluIG1zOgogICAgICAgIHdoZW4gPSB0aW1lLnN0cmZ0aW1lKCIlWS0lbS0lZCAlSDolTSIsIHRpbWUubG9jYWx0aW1lKG0uZ2V0KCJyZWNlaXZlZCIsIDApKSkKICAgICAgICBwcmludChmInttWydpZCddfSAge3doZW59ICB7bS5nZXQoJ2Zyb21fbGFiZWwnLCc/Jyk6MTZ9ICIKICAgICAgICAgICAgICBmInsobS5nZXQoJ2JvZHknKSBvciAnJykucmVwbGFjZShjaHIoMTApLCcgJylbOjYwXX0iKQoKCmRlZiBjbWRfcmVhZChhKToKICAgIGZvciBtIGluIF9tc2dzKFRydWUpOgogICAgICAgIGlmIG1bImlkIl0gPT0gYS5pZDoKICAgICAgICAgICAgcHJpbnQoanNvbi5kdW1wcyhtLCBpbmRlbnQ9MikpCiAgICAgICAgICAgIHJldHVybgogICAgc3lzLmV4aXQoZiJubyBtZXNzYWdlIHthLmlkfSIpCgoKZGVmIGNtZF9hY2soYSk6CiAgICBmb3IgbiBpbiAob3MubGlzdGRpcihJTkJPWCkgaWYgb3MucGF0aC5pc2RpcihJTkJPWCkgZWxzZSBbXSk6CiAgICAgICAgaWYgYS5pZCBpbiBuOgogICAgICAgICAgICBvcy5yZXBsYWNlKG9zLnBhdGguam9pbihJTkJPWCwgbiksIG9zLnBhdGguam9pbihBUkNISVZFLCBuKSkKICAgICAgICAgICAgcHJpbnQoZiJhcmNoaXZlZCB7YS5pZH0iKQogICAgICAgICAgICByZXR1cm4KICAgIHN5cy5leGl0KGYibm8gdW5hcmNoaXZlZCBtZXNzYWdlIHthLmlkfSIpCgoKZGVmIGNtZF9zZW5kKGEpOgogICAgcCA9IHBlZXJzKCkKICAgIHRhcmdldCA9IE5vbmUKICAgIGZvciBmcCwgdiBpbiBwLml0ZW1zKCk6CiAgICAgICAgaWYgYS50byBpbiAoZnAsIHYuZ2V0KCJsYWJlbCIpLCBmcFs6MTJdKToKICAgICAgICAgICAgdGFyZ2V0ID0gdgogICAgICAgICAgICBicmVhawogICAgaWYgdGFyZ2V0IGlzIE5vbmU6CiAgICAgICAgc3lzLmV4aXQoZiJ1bmtub3duIHBlZXIge2EudG8hcn07IHRyeTogaW5ib3hfYWdlbnQucHkgcGVlcnMiKQogICAgcmVwbHkgPSBzZW5kX3RvKHRhcmdldFsib25pb24iXSwgYS5ib2R5KQogICAgcHJpbnQoanNvbi5kdW1wcyhyZXBseSwgaW5kZW50PTIpKQogICAgc3lzLmV4aXQoMCBpZiByZXBseSBhbmQgcmVwbHkuZ2V0KCJvayIpIGVsc2UgMSkKCgpkZWYgbWFpbigpOgogICAgYXAgPSBhcmdwYXJzZS5Bcmd1bWVudFBhcnNlcihkZXNjcmlwdGlvbj1fX2RvY19fLAogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBmb3JtYXR0ZXJfY2xhc3M9YXJncGFyc2UuUmF3RGVzY3JpcHRpb25IZWxwRm9ybWF0dGVyKQogICAgcyA9IGFwLmFkZF9zdWJwYXJzZXJzKGRlc3Q9ImNtZCIsIHJlcXVpcmVkPVRydWUpCiAgICBzLmFkZF9wYXJzZXIoInNlcnZlIikuc2V0X2RlZmF1bHRzKGZuPWNtZF9zZXJ2ZSkKICAgIHMuYWRkX3BhcnNlcigid2hvYW1pIikuc2V0X2RlZmF1bHRzKGZuPWNtZF93aG9hbWkpCiAgICBzLmFkZF9wYXJzZXIoInBlZXJzIikuc2V0X2RlZmF1bHRzKGZuPWNtZF9wZWVycykKICAgIHAgPSBzLmFkZF9wYXJzZXIoImFkZC1wZWVyIikKICAgIHAuYWRkX2FyZ3VtZW50KCJmaW5nZXJwcmludCIpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1vbmlvbiIsIHJlcXVpcmVkPVRydWUpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1sYWJlbCIsIGRlZmF1bHQ9IiIpCiAgICBwLnNldF9kZWZhdWx0cyhmbj1jbWRfYWRkX3BlZXIpCiAgICBwID0gcy5hZGRfcGFyc2VyKCJpbmJveCIpCiAgICBwLmFkZF9hcmd1bWVudCgiLS1hbGwiLCBhY3Rpb249InN0b3JlX3RydWUiKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX2luYm94KQogICAgcCA9IHMuYWRkX3BhcnNlcigicmVhZCIpCiAgICBwLmFkZF9hcmd1bWVudCgiaWQiKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX3JlYWQpCiAgICBwID0gcy5hZGRfcGFyc2VyKCJhY2siKQogICAgcC5hZGRfYXJndW1lbnQoImlkIikKICAgIHAuc2V0X2RlZmF1bHRzKGZuPWNtZF9hY2spCiAgICBwID0gcy5hZGRfcGFyc2VyKCJzZW5kIikKICAgIHAuYWRkX2FyZ3VtZW50KCItLXRvIiwgcmVxdWlyZWQ9VHJ1ZSkKICAgIHAuYWRkX2FyZ3VtZW50KCItLWJvZHkiLCByZXF1aXJlZD1UcnVlKQogICAgcC5zZXRfZGVmYXVsdHMoZm49Y21kX3NlbmQpCiAgICBhID0gYXAucGFyc2VfYXJncygpCiAgICBhLmZuKGEpCgoKaWYgX19uYW1lX18gPT0gIl9fbWFpbl9fIjoKICAgIG1haW4oKQo='
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
