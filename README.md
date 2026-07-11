# Flutter FTP & DTP

A Flutter package for **LAN-based local data sharing** between devices on the same Wi-Fi network. Extracted from the [RUPOS](https://github.com) dine-in table management module.

| Pattern | Name | Transport | Use case |
|---------|------|-----------|----------|
| **FTP** | File Transfer Pattern | HTTP GET | One-shot JSON export/import (setup sharing) |
| **DTP** | Data Transfer Pattern | WebSocket | Realtime bidirectional sync (live collaboration) |

## Features

- **No cloud required** — devices communicate directly over the local network
- **QR + manual pairing** — scan a QR code or enter IP + port + token
- **Token-gated security** — 6-character alphanumeric tokens on every connection
- **Cross-platform** — Android, iOS, macOS, Windows, Linux (host); Web (client join only)
- **Pluggable storage** — wire FTP/DTP to your own Hive, SQLite, or in-memory store
- **Ready-made UI** — optional dialogs for share, import, and live sync flows

## Quick start

### 1. Add dependency

```yaml
dependencies:
  flutter_ftp_dtp: ^1.0.0
```

See [INSTALLATION.md](INSTALLATION.md) for full platform setup.

### 2. File Transfer Pattern (FTP)

```dart
import 'package:flutter_ftp_dtp/flutter_ftp_dtp.dart';

final shareService = LocalFileShareService(
  label: 'My App Data',
  buildExport: () => {'items': myData.toJson()},
  importExport: (json) async {
    myData.loadFrom(json);
    return ImportSummary(itemCount: myData.length);
  },
);

// Host — show QR dialog
await showFileShareDialog(context, service: shareService);

// Client — import from host
await showFileImportDialog(context, service: shareService);
```

### 3. Data Transfer Pattern (DTP)

```dart
class MySyncAdapter implements SyncAdapter {
  @override
  Future<Map<String, dynamic>> buildSnapshot() async => {...};

  @override
  Future<void> applyRemote(SyncMessage message) async {...}

  @override
  void startWatching(void Function(SyncMessage) onLocalChange) {...}

  @override
  Future<void> stopWatching() async {...}
}

final engine = RealtimeSyncEngine(MySyncAdapter());
await showRealtimeSyncDialog(context, engine: engine);
```

## Example app

```bash
cd example
flutter pub get
flutter run
```

The example demonstrates both patterns with a simple shared-notes app.

## Platform support

| Platform | FTP Host | FTP Client | DTP Host | DTP Client |
|----------|----------|------------|----------|------------|
| Android  | ✅ | ✅ | ✅ | ✅ |
| iOS      | ✅ | ✅ | ✅ | ✅ |
| macOS    | ✅ | ✅ | ✅ | ✅ |
| Windows  | ✅ | ✅ | ✅ | ✅ |
| Linux    | ✅ | ✅ | ✅ | ✅ |
| Web      | ❌ | ✅ | ❌ | ✅ |

Hosting requires `dart:io` (native platforms). Web can join as a client but cannot host.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Your Flutter App                      │
│  ┌──────────────┐              ┌──────────────────────┐ │
│  │ LocalFile    │              │ RealtimeSyncEngine   │ │
│  │ ShareService │              │ + SyncAdapter        │ │
│  └──────┬───────┘              └──────────┬───────────┘ │
│         │                                  │             │
│  ┌──────▼───────┐              ┌─────────▼──────────┐  │
│  │ ShareHttp    │              │ SyncWsServer       │  │
│  │ Server       │              │ (WebSocket host)   │  │
│  │ GET /data.json│             │ GET /sync          │  │
│  └──────────────┘              └────────────────────┘  │
└─────────────────────────────────────────────────────────┘
         │ LAN (same Wi-Fi)              │
         ▼                               ▼
    Receiver device(s)            Joining device(s)
```

## Protocol

### FTP QR payload
```json
{"v":1,"ip":"192.168.1.25","port":8080,"token":"A9X8M2","label":"My Store","path":"/data.json","mode":"share"}
```

### DTP QR payload
```json
{"ip":"192.168.1.25","port":8080,"token":"A9X8M2","path":"/sync","mode":"sync"}
```

### WebSocket message envelope
```json
{"t":"entity_upsert","o":"dev_...","id":"item_id","ts":1234567890,"d":{...}}
```

## Documentation

- [Installation Guide](INSTALLATION.md)
- [Changelog](CHANGELOG.md)
- [HTML Overview](doc/index.html) — interactive documentation
- [RUPOS Table Management UI Reference](doc/rupos_full_flow_1.html) — original design prototype

## Origin

This package was extracted from the RUPOS application's Table Management module:

- `TableShareService` → `LocalFileShareService` (FTP)
- `DineSyncService` → `RealtimeSyncEngine` (DTP)

The original Rupos code is **unchanged** — this is a standalone copy for reuse in other Flutter projects.

## License

MIT — see [LICENSE](LICENSE). Copyright © 2026 CI Global Technologies.
