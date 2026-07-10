# Drift

A native macOS remote GUI for [Transmission](https://transmissionbt.com/), built with SwiftUI.

Most existing Transmission remotes for Mac (Transmission Remote GUI, Electorrent, the stock web UI, …) are cross-platform or Electron-based. Drift is a SwiftUI-native alternative built for macOS specifically: real-time updates, multi-select, speed limits with a Slow Mode toggle, a torrent inspector (trackers, peers, files), magnet-link/`.torrent` handling, and English/Russian localization.

## Requirements

- macOS 14+
- A running Transmission daemon with remote access (RPC) enabled

## Building

No Xcode project — this is a plain SwiftPM executable, packaged into a `.app` bundle by the build script:

```bash
./script/build_and_run.sh run
```

## License

MIT — see [LICENSE](LICENSE).
