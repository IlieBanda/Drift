<!-- Draft only — not posted. For r/macapps or similar. -->

**Title:** Swarm — a native SwiftUI remote for Transmission

I wanted a Transmission remote that actually feels like part of macOS — SwiftUI throughout, a real
native toolbar, Liquid Glass on macOS 26+ (falls back gracefully on 14–25), colored sidebar icons.
So I built Swarm.

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
Hardened Runtime, and network access is scoped to your local network only. Transmission's RPC
traffic is plain HTTP by default (matching Transmission itself) — if your daemon is reachable from
outside your LAN, put it behind HTTPS or a VPN, since Swarm doesn't encrypt that traffic itself.

It's free, open source (MIT), and on GitHub. **One heads-up:** it's not notarized yet (that needs a
paid Apple Developer account I don't have yet), so macOS will flag it as unverified on first
launch. Right-click the app → Open → Open once and it's remembered after that — full steps are
right near the top of the README.

Feedback welcome, especially anything that feels off or not-quite-native.
