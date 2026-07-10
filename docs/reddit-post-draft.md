<!-- Draft only — not posted. For r/macapps or similar. -->

**Title:** Drift — a native SwiftUI remote for Transmission (no Electron)

Most Transmission remotes for Mac (Transmission Remote GUI, Electorrent, the stock web UI) are
cross-platform or Electron-based. I wanted something that actually feels like part of macOS, so I
built Drift: SwiftUI, a real native toolbar, Liquid Glass on macOS 26+, colored sidebar icons —
no Chromium tab hiding in your Dock.

**What it does:**
- Real-time torrent list with multi-select, drag-and-drop `.torrent` files, add via magnet
  link/file/URL
- A tabbed inspector per torrent (Activity, Trackers, Peers, Files, General) with per-file
  priority control
- Right-click a torrent to ask the tracker for more peers, verify its data, reorder it in the
  queue, rename it, move its data, or copy its magnet link
- Global speed limits + one-click Slow Mode
- Menu bar commands, Dock badge for active downloads, launch at login, background operation,
  download-complete notifications
- English and Russian localization

**Security:** credentials live in the Keychain (never plaintext), the app is sandboxed with
Hardened Runtime, and network access is scoped to your local network only.

It's free, open source (MIT), and on GitHub. Not notarized yet (no paid Developer account behind
it currently) — first launch needs a one-time right-click-Open, documented in the README.

Feedback welcome, especially on anything that feels "not quite native."
