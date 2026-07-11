# Swarm 1.0 — release notes (draft)

A native macOS remote for Transmission, built from scratch in SwiftUI.

## Highlights

- **Native, not Electron.** SwiftUI, Liquid Glass materials on macOS 26+, a real macOS toolbar,
  colored sidebar icons, animated state transitions — no Chromium tab hiding in your Dock.
- **Full torrent management** — real-time updates, multi-select, drag-and-drop `.torrent` files,
  add via magnet link/file/URL, per-file priority and inclusion toggles in a tabbed inspector
  (Activity, Trackers, Peers, Files, General).
- **Right-click actions**: ask the tracker for more peers, verify local data, reorder the download
  queue, rename a torrent, move its data to a new location, copy its magnet link.
- **Speed control** — global limits plus one-click Slow Mode (alternate bandwidth) via popover.
- **Built for the Mac** — menu bar commands, Dock badge for active downloads, launch at login,
  background operation, download-complete notifications, English and Russian localization.
- **At a glance** — sidebar activity sparkline, per-filter torrent counts, free disk space on the
  download server.

## Security

- Server credentials are stored in the Keychain, never in plaintext `UserDefaults`.
- Sandboxed with Hardened Runtime; only the entitlements it actually needs
  (network client, user-selected read-only file access).
- App Transport Security scoped to local-network traffic only — no arbitrary internet loads.

## Known limitations

- Ad-hoc signed, not notarized (no paid Apple Developer account behind this release yet).
  Gatekeeper will warn on first launch — see the README for the one-time workaround.
- No in-app language switcher; Swarm follows the system locale (English/Russian available).

## Requirements

- macOS 14+
- A Transmission daemon with remote access (RPC) enabled

## Install

Download the DMG, drag Swarm into Applications, then see the README's "Installing a downloaded
build" section for the Gatekeeper first-launch workaround.
