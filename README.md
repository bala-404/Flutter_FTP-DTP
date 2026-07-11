# Flutter FTP & DTP

General-purpose **LAN-based local data sharing** for Flutter — **FTP** (one-shot JSON over HTTP) and **DTP** (realtime sync over WebSocket) on the same Wi-Fi network.

| Pattern | Name | Transport | Use case |
|---------|------|-----------|----------|
| **FTP** | File Transfer Pattern | HTTP GET | One-shot JSON export/import (setup sharing) |
| **DTP** | Data Transfer Pattern | WebSocket | Realtime bidirectional sync (live collaboration) |

---

## Author

**Balamurugan** · AI Architect · Chennai, India

| | |
|---|---|
| **Email** | [messagetobalamurugan@gmail.com](mailto:messagetobalamurugan@gmail.com) |
| **WhatsApp** | [+91 75388 86343](https://wa.me/917538886343) |
| **Custom solutions** | LAN sync, offline-first apps, multi-device collaboration, QR pairing flows |

Need custom LAN sync, white-label data sharing, or enterprise Flutter integrations? Connect on [WhatsApp](https://wa.me/917538886343) or [email](mailto:messagetobalamurugan@gmail.com).

---

## Support this project

If **flutter_ftp_dtp** saved you time on your app, consider buying me a coffee:

| Method | Details |
|--------|---------|
| **UPI (India)** | `balamuruganm2102-1@okaxis` |
| **Buy Me a Coffee** | [buymeacoffee.com](https://buymeacoffee.com) — search **Balamurugan** or use UPI above |

Your support helps maintain cross-platform LAN sync, WebSocket reliability, and new pairing features.

---

## Documentation

| Guide | Link |
|-------|------|
| Installation guide (all platforms) | [INSTALLATION.md](INSTALLATION.md) |
| Full HTML guide (live) | [bala-404.github.io/Flutter_FTP-DTP](https://bala-404.github.io/Flutter_FTP-DTP/) |
| Changelog | [CHANGELOG.md](CHANGELOG.md) |
| GitHub repository | [bala-404/Flutter_FTP-DTP](https://github.com/bala-404/Flutter_FTP-DTP) |

```bash
# Open live HTML guide in browser
open https://bala-404.github.io/Flutter_FTP-DTP/
```

> **Note:** GitHub shows `doc/index.html` as source code in the repo browser. Use the [live docs site](https://bala-404.github.io/Flutter_FTP-DTP/) above to view the rendered page.

---

## Install

### From pub.dev

```yaml
dependencies:
  flutter_ftp_dtp: ^1.0.3
```

### Local path (development)

```yaml
dependencies:
  flutter_ftp_dtp:
    path: ../Flutter_FTP-DTP
```

```bash
flutter pub get
```

```dart
import 'package:flutter_ftp_dtp/flutter_ftp_dtp.dart';
```

See [INSTALLATION.md](INSTALLATION.md) for Android cleartext, iOS local network, and camera permissions.

---

## Features

- **No cloud required** — devices communicate directly over the local network
- **QR + manual pairing** — scan a QR code or enter IP + port + token
- **Token-gated security** — 6-character alphanumeric tokens on every connection
- **Cross-platform** — Android, iOS, macOS, Windows, Linux (host); Web (client join only)
- **Pluggable storage** — wire FTP/DTP to your own Hive, SQLite, or in-memory store
- **Ready-made UI** — optional dialogs for share, import, and live sync flows

---

## Quick start

### File Transfer Pattern (FTP)

```dart
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

### Data Transfer Pattern (DTP)

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

---

## Example app

```bash
cd example
flutter pub get
flutter run
```

The example demonstrates both patterns with a simple shared-notes app. Test with two devices on the same Wi-Fi:

1. Device A → **Share (FTP)** or **Live Sync (DTP)** → Host
2. Device B → **Import (FTP)** or **Live Sync (DTP)** → Join (scan QR)

---

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

---

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

---

## Protocol

### FTP QR payload

```json
{"v":1,"ip":"192.168.1.25","port":8080,"token":"A9X8M2","label":"My Data","path":"/data.json","mode":"share"}
```

### DTP QR payload

```json
{"ip":"192.168.1.25","port":8080,"token":"A9X8M2","path":"/sync","mode":"sync"}
```

### WebSocket message envelope

```json
{"t":"entity_upsert","o":"dev_...","id":"item_id","ts":1234567890,"d":{...}}
```

Generic message types: `snapshot`, `entity_upsert`, `entity_delete`, `collection`, `ping`, `pong`.

---

## Publishing checklist (pub.dev)

```bash
cd Flutter_FTP-DTP
dart pub publish --dry-run
dart pub publish
```

Requires: `LICENSE`, `CHANGELOG.md`, `README.md`, valid `homepage` / `repository` URLs.

---

## License

**MIT License** — Copyright © 2026 Balamurugan, Chennai, India.

You are free to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of this software, subject to the conditions in the [LICENSE](LICENSE) file.

Permission is granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, subject to the following conditions:

- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Full license text: [LICENSE](LICENSE) · Repository: [GitHub](https://github.com/bala-404/Flutter_FTP-DTP)

---

Made with ❤️ in Chennai · [Email](mailto:messagetobalamurugan@gmail.com) · [WhatsApp](https://wa.me/917538886343) · UPI: `balamuruganm2102-1@okaxis`
