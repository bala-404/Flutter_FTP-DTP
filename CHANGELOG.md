# Changelog

All notable changes to the **flutter_ftp_dtp** package are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.3] - 2026-07-11

### Added

- GitHub Pages workflow — live HTML docs at https://bala-404.github.io/Flutter_FTP-DTP/

### Changed

- README and `homepage` now link to rendered docs site (GitHub repo browser shows HTML as source only)

## [1.0.2] - 2026-07-11

### Changed

- Generalized package docs — removed domain-specific references from README and HTML guide
- Removed legacy wire-format aliases (`order_upsert`, `order_delete`, `tables`) from `SyncType`
- `previewImport` now uses generic keys (`items`, `records`, `entities`) instead of domain-specific fields

### Removed

- `doc/rupos_full_flow_1.html` — domain-specific UI reference removed from package

## [1.0.1] - 2026-07-11

### Changed

- README: author contact, support, documentation table, publishing checklist, and license details (pub.dev page)

## [1.0.0] - 2026-07-11

### Added

- Initial release — general-purpose LAN data sharing for Flutter
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
- **Platform support**: Android, iOS, macOS, Windows, Linux, Web (client only)

[1.0.3]: https://github.com/bala-404/Flutter_FTP-DTP/releases/tag/v1.0.3
[1.0.2]: https://github.com/bala-404/Flutter_FTP-DTP/releases/tag/v1.0.2
[1.0.1]: https://github.com/bala-404/Flutter_FTP-DTP/releases/tag/v1.0.1
[1.0.0]: https://github.com/bala-404/Flutter_FTP-DTP/releases/tag/v1.0.0
