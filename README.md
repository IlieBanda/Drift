<div align="center">

<img src="docs/wordmark-v2.png" alt="Drift" height="72">

**A native macOS remote for Transmission.**

[![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Swift](https://img.shields.io/badge/Swift-SwiftUI-orange)](#building)

</div>

---

Most existing Transmission remotes for Mac — Transmission Remote GUI, Electorrent, the stock web UI — are cross-platform or Electron-based. Drift is built for macOS specifically: SwiftUI, native controls, no Chromium tab hiding in your Dock.

## Features

**Torrent management**
- Real-time updates, multi-select (shift/cmd-click), drag-and-drop `.torrent` files
- Add via magnet link, `.torrent` file, or URL — set as the default handler for both
- Per-file priority (Low/Normal/High) and inclusion toggles in a torrent inspector (Activity, Trackers, Peers, Files, General)

**Speed control**
- Global up/down speed limits
- One-click Slow Mode (alternate speed limits), configurable via popover

**Built for the Mac**
- Native SwiftUI, `.inspector()` side panel, menu bar commands, Dock badge for active downloads
- Launch at login, run in the background after closing the window
- Notifications on download completion
- English and Russian localization

**At a glance**
- Sidebar activity sparkline (live up/down throughput)
- Per-filter torrent counts
- Free disk space on the download server

## Requirements

- macOS 14+
- A running Transmission daemon with remote access (RPC) enabled

## Building

No Xcode project — this is a plain SwiftPM executable, packaged into a `.app` bundle by the build script:

```bash
./script/build_and_run.sh run
```

To build a distributable, universal (Apple Silicon + Intel) release DMG instead:

```bash
./script/build_and_run.sh dmg
```

## Installing a downloaded build

Drift isn't notarized yet (that requires a paid Apple Developer account), so on first launch Gatekeeper will say the app "cannot be opened because it is from an unidentified developer" or "is damaged and can't be opened." It isn't — macOS just hasn't seen the ad-hoc signature before. To open it:

- **Right-click (or Control-click) the app → Open → Open**, once — macOS remembers your choice after that, or
- Run `xattr -cr /Applications/Drift.app` in Terminal to clear the quarantine flag.

## Connection security

Drift talks to Transmission's RPC API over plain HTTP by default, matching Transmission's own default configuration. This traffic never leaves your local network (`NSAllowsLocalNetworking` is the only App Transport Security exception Drift declares — arbitrary internet loads are not allowed). If your Transmission daemon is exposed beyond your LAN (e.g. over the internet or through a reverse proxy), put it behind HTTPS/a VPN — Drift does not encrypt RPC traffic itself.

## License

MIT — see [LICENSE](LICENSE).
