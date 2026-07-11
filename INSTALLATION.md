# Installation Guide

This guide covers adding **flutter_ftp_dtp** to your Flutter project and configuring each platform for LAN HTTP/WebSocket traffic.

## Requirements

- Flutter SDK ≥ 3.13.0
- Dart SDK ≥ 3.1.3
- Devices on the **same Wi-Fi / LAN** for pairing

## 1. Add the package

### Path dependency (local monorepo)

```yaml
# pubspec.yaml
dependencies:
  flutter_ftp_dtp:
    path: ../Flutter_FTP-DTP
```

### Git dependency

```yaml
dependencies:
  flutter_ftp_dtp:
    git:
      url: <your-repo-url>
      path: Flutter_FTP-DTP
```

Then run:

```bash
flutter pub get
```

## 2. Import

```dart
import 'package:flutter_ftp_dtp/flutter_ftp_dtp.dart';
```

## 3. Android configuration

### AndroidManifest.xml

Add permissions and enable cleartext HTTP (required for `http://` and `ws://` LAN traffic):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

<application
    android:usesCleartextTraffic="true"
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
```

### res/xml/network_security_config.xml

Create `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

> **Note:** Location permission is used by `network_info_plus` to resolve the device's Wi-Fi IP on Android.

## 4. iOS configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used to scan QR codes for LAN pairing.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Local network access is required to sync data with nearby devices on the same Wi-Fi.</string>
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

## 5. macOS configuration

Add to `macos/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera is used to scan QR codes for LAN pairing.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>Local network access is required to sync data with nearby devices on the same Wi-Fi.</string>
```

## 6. Windows / Linux

No extra native configuration is required. The package uses `dart:io` `HttpServer` directly.

## 7. Web

- **Hosting is not supported** on web (`dart:io` unavailable).
- **Joining** as FTP client or DTP client may work via `http` / `WebSocketChannel`.
- QR scanning works via `mobile_scanner` web support.

## 8. Optional: Camera permission at runtime

Request camera permission before showing import/sync QR scanners:

```dart
import 'package:permission_handler/permission_handler.dart';

await Permission.camera.request();
```

Add `permission_handler` to your app's `pubspec.yaml` if you use this approach (included in the example app).

## 9. Wire up your storage

### FTP — one-shot share

```dart
final service = LocalFileShareService(
  label: 'My Data',
  dataPath: '/data.json',          // HTTP endpoint path
  buildExport: () => myStore.toJson(),
  importExport: (json) async {
    await myStore.importFrom(json);
    return ImportSummary(itemCount: myStore.count);
  },
  canImport: () => !myStore.hasActiveSessions,  // optional guard
);
```

### DTP — live sync

Implement [SyncAdapter](lib/src/dtp/realtime_sync_engine.dart):

1. `buildSnapshot()` — return full state for new clients
2. `applyRemote(message)` — apply incoming changes with last-write-wins
3. `startWatching(onLocalChange)` — watch your DB and emit `SyncMessage`s
4. `stopWatching()` — clean up subscriptions

```dart
final engine = RealtimeSyncEngine(MySyncAdapter());
engine.onChanged = () => setState(() {});  // refresh UI
```

## 10. Run the example

```bash
cd Flutter_FTP-DTP/example
flutter pub get
flutter run -d <device>
```

Test with two physical devices (or one device + desktop) on the same Wi-Fi:

1. Device A → **Share (FTP)** or **Live Sync (DTP)** → Host
2. Device B → **Import (FTP)** or **Live Sync (DTP)** → Join (scan QR)

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Cannot detect IP | Ensure Wi-Fi is on; grant location permission on Android |
| Connection refused | Both devices must be on the same subnet; check firewall |
| Invalid token | Re-scan QR; token is session-specific |
| Hosting not supported | Use a native platform (not web) as host |
| Import blocked | Check `canImport` callback — may block during active sessions |

## Port range

The server binds to the first free port in **8080–8120** (`shared: true`).
