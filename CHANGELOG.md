# Changelog

All notable changes to the **flutter_ftp_dtp** package are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-07-11

### Added

- Initial release extracted from RUPOS Table Management module
- **FTP (File Transfer Pattern)**
  - `LocalFileShareService` — one-shot JSON export/import over HTTP
  - `ShareHttpServer` — native `dart:io` LAN HTTP server with web stub
  - `ShareSession`, `ShareTarget`, `ImportSummary` models
  - `showFileShareDialog` and `showFileImportDialog` UI widgets
- **DTP (Data Transfer Pattern)**
  - `RealtimeSyncEngine` — WebSocket-based live sync with host relay
  - `SyncAdapter` interface for pluggable storage backends
  - `SyncWsServer` — native WebSocket host with web stub
  - `SyncMessage`, `SyncType` wire protocol
  - `DeviceId` — per-install device identity via SharedPreferences
  - `showRealtimeSyncDialog` UI widget
- **Common utilities**
  - `generateShareToken()` — 6-char secure pairing tokens
  - `resolveLocalIp()` — Wi-Fi IP resolution via `network_info_plus`
- **Example app** (`example/`) demonstrating both patterns with shared notes
- **Documentation**
  - `README.md` — overview and quick start
  - `INSTALLATION.md` — platform configuration guide
  - `doc/index.html` — interactive HTML documentation
  - `doc/rupos_full_flow_1.html` — original RUPOS UI design reference
- **Platform support**: Android, iOS, macOS, Windows, Linux, Web (client only)

### Notes

- RUPOS application code is **not modified** — this is a standalone package copy
- Wire protocol is backward compatible with RUPOS dine-in sync message types
  (`order_upsert`, `order_delete`, `tables`) in addition to generic types
  (`entity_upsert`, `entity_delete`, `collection`)

[1.0.0]: https://github.com/bala-404/Flutter_FTP-DTP/releases/tag/v1.0.0
