/// Flutter FTP & DTP — LAN file sharing and realtime sync for Flutter apps.
///
/// **FTP (File Transfer Pattern)** — one-shot JSON export/import over HTTP.
/// **DTP (Data Transfer Pattern)** — live bidirectional sync over WebSocket.
library flutter_ftp_dtp;

export 'src/common/network.dart';
export 'src/common/share_target.dart';
export 'src/common/token.dart';
export 'src/dtp/device_id.dart';
export 'src/dtp/realtime_sync_engine.dart';
export 'src/dtp/sync_message.dart';
export 'src/dtp/sync_ws_server.dart';
export 'src/ftp/local_file_share_service.dart';
export 'src/ftp/share_http_server.dart';
export 'src/ui/file_share_dialog.dart';
export 'src/ui/file_import_dialog.dart';
export 'src/ui/realtime_sync_dialog.dart';
