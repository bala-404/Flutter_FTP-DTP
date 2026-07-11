import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../common/share_target.dart';
import '../dtp/realtime_sync_engine.dart';
import 'ftp_dtp_theme.dart';

/// Opens the live-sync (DTP) dialog — host or join.
Future<void> showRealtimeSyncDialog(
  BuildContext context, {
  required RealtimeSyncEngine engine,
  String title = 'Live Sync',
  String description =
      'Keep data in sync across devices on the same Wi-Fi. One device hosts; others join.',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RealtimeSyncDialog(
      engine: engine,
      title: title,
      description: description,
    ),
  );
}

enum _Mode { choose, host, joinScan, joinManual }

class RealtimeSyncDialog extends StatefulWidget {
  const RealtimeSyncDialog({
    super.key,
    required this.engine,
    this.title = 'Live Sync',
    this.description =
        'Keep data in sync across devices on the same Wi-Fi. One device hosts; others join.',
  });

  final RealtimeSyncEngine engine;
  final String title;
  final String description;

  @override
  State<RealtimeSyncDialog> createState() => _RealtimeSyncDialogState();
}

class _RealtimeSyncDialogState extends State<RealtimeSyncDialog> {
  SyncHostInfo? _hostInfo;
  String? _error;
  late _Mode _mode;

  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '8080');
  final _tokenCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  MobileScannerController? _scanner;
  bool _handling = false;

  bool get _scannerSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    widget.engine.onChanged = _onEngineChanged;
    if (widget.engine.role == SyncRole.host) {
      _mode = _Mode.host;
    } else if (widget.engine.role == SyncRole.client) {
      _mode = _Mode.joinScan;
    } else {
      _mode = _Mode.choose;
    }
  }

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.engine.onChanged = null;
    _scanner?.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _startHost() async {
    setState(() {
      _mode = _Mode.host;
      _error = null;
    });
    if (!widget.engine.isHostSupported) {
      setState(() => _error =
          'Hosting is not supported on this platform (e.g. web). Use a mobile '
          'or desktop device as the host; this device can still Join.');
      return;
    }
    try {
      final info = await widget.engine.startHost();
      setState(() => _hostInfo = info);
    } catch (e) {
      setState(() => _error = 'Could not start hosting: $e');
    }
  }

  void _beginJoin() {
    setState(() {
      _error = null;
      if (_scannerSupported) {
        _mode = _Mode.joinScan;
        _scanner = MobileScannerController();
      } else {
        _mode = _Mode.joinManual;
      }
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw =
        capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handling = true;
    try {
      final target = ShareTarget.fromQr(raw);
      await _scanner?.stop();
      await _join(target);
    } catch (_) {
      _handling = false;
      setState(() => _error = 'That QR code is not a valid live-sync code.');
    }
  }

  Future<void> _submitManual() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _join(ShareTarget(
      ip: _ipCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      token: _tokenCtrl.text.trim().toUpperCase(),
      path: '/sync',
      mode: 'sync',
    ));
  }

  Future<void> _join(ShareTarget target) async {
    setState(() => _error = null);
    try {
      await widget.engine.joinAsClient(target);
    } catch (e) {
      setState(() => _error = 'Could not connect: $e');
    }
  }

  Future<void> _stop() async {
    await widget.engine.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync, color: FtpDtpTheme.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: FtpDtpTheme.text)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: FtpDtpTheme.textMute),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_mode) {
      case _Mode.choose:
        return _chooseView();
      case _Mode.host:
        return _hostView();
      case _Mode.joinScan:
        return _joinScanView();
      case _Mode.joinManual:
        return _joinManualView();
    }
  }

  Widget _chooseView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.description,
            style: const TextStyle(fontSize: 13, color: FtpDtpTheme.textMute)),
        const SizedBox(height: 18),
        _bigButton(
          icon: Icons.wifi_tethering,
          title: 'Host Live Sync',
          subtitle: 'This device shares data and relays changes.',
          onTap: _startHost,
          filled: true,
        ),
        const SizedBox(height: 12),
        _bigButton(
          icon: Icons.login,
          title: 'Join Live Sync',
          subtitle: 'Connect to a device that is already hosting.',
          onTap: _beginJoin,
          filled: false,
        ),
      ],
    );
  }

  Widget _hostView() {
    if (_error != null) return _errorBox(_error!);
    final info = _hostInfo;
    if (info == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 34),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final clients = widget.engine.clientCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Scan this from each device\'s "Join Live Sync".',
          style: TextStyle(fontSize: 13, color: FtpDtpTheme.textMute),
        ),
        const SizedBox(height: 14),
        Center(
          child: SizedBox(
            width: 190,
            height: 190,
            child: PrettyQrView.data(
              data: info.qrPayload,
              decoration: const PrettyQrDecoration(
                shape: PrettyQrSmoothSymbol(color: FtpDtpTheme.text),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _detailRow('Address', '${info.ip ?? '—'}:${info.port}'),
        const SizedBox(height: 8),
        _detailRow('Token', info.token, copyable: true),
        const SizedBox(height: 14),
        _statusChip(
          icon: Icons.devices,
          active: clients > 0,
          text: clients == 0
              ? 'No devices connected yet'
              : '$clients device${clients == 1 ? '' : 's'} connected',
        ),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerRight, child: _stopButton()),
      ],
    );
  }

  Widget _joinScanView() {
    final status = widget.engine.status;
    if (status == SyncConnectionStatus.connected) return _connectedView();
    if (_error != null) return _errorBox(_error!);
    if (status == SyncConnectionStatus.connecting) {
      return _busy('Connecting to host…', withStop: true);
    }
    return Column(
      children: [
        const Text('Point the camera at the host\'s QR code.',
            style: TextStyle(fontSize: 13, color: FtpDtpTheme.textMute)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 230,
            child: _scanner == null
                ? const SizedBox.shrink()
                : MobileScanner(controller: _scanner, onDetect: _onDetect),
          ),
        ),
        TextButton(
          onPressed: () {
            _scanner?.stop();
            setState(() => _mode = _Mode.joinManual);
          },
          child: const Text('Enter details manually'),
        ),
      ],
    );
  }

  Widget _joinManualView() {
    final status = widget.engine.status;
    if (status == SyncConnectionStatus.connected) return _connectedView();
    if (status == SyncConnectionStatus.connecting) {
      return _busy('Connecting to host…', withStop: true);
    }
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_error != null) Text(_error!, style: const TextStyle(color: FtpDtpTheme.red)),
          TextFormField(
            controller: _ipCtrl,
            decoration: const InputDecoration(labelText: 'IP address'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          TextFormField(
            controller: _portCtrl,
            decoration: const InputDecoration(labelText: 'Port'),
            keyboardType: TextInputType.number,
          ),
          TextFormField(
            controller: _tokenCtrl,
            decoration: const InputDecoration(labelText: 'Token'),
            textCapitalization: TextCapitalization.characters,
          ),
          ElevatedButton(onPressed: _submitManual, child: const Text('Connect')),
        ],
      ),
    );
  }

  Widget _connectedView() {
    return Column(
      children: [
        _statusChip(
          icon: Icons.check_circle,
          active: true,
          text: 'Connected — data is syncing live.',
        ),
        const SizedBox(height: 16),
        Align(alignment: Alignment.centerRight, child: _stopButton()),
      ],
    );
  }

  Widget _bigButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool filled,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: filled ? FtpDtpTheme.blue : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: filled ? FtpDtpTheme.blue : FtpDtpTheme.grayLine),
        ),
        child: Row(
          children: [
            Icon(icon, color: filled ? Colors.white : FtpDtpTheme.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: filled ? Colors.white : FtpDtpTheme.text)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: filled
                              ? Colors.white.withOpacity(0.85)
                              : FtpDtpTheme.textMute)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: FtpDtpTheme.textMute))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        if (copyable)
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Token copied')));
            },
            icon: const Icon(Icons.copy, size: 16, color: FtpDtpTheme.blue),
          ),
      ],
    );
  }

  Widget _statusChip(
      {required IconData icon, required bool active, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEAF7EF) : FtpDtpTheme.grayBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: active ? FtpDtpTheme.green : FtpDtpTheme.textMute),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _stopButton() => ElevatedButton(
        onPressed: _stop,
        style: ElevatedButton.styleFrom(
            backgroundColor: FtpDtpTheme.red, foregroundColor: Colors.white),
        child: const Text('Stop Sync'),
      );

  Widget _busy(String label, {bool withStop = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(label),
            if (withStop) ...[const SizedBox(height: 16), _stopButton()],
          ],
        ),
      );

  Widget _errorBox(String msg) {
    return Column(
      children: [
        Text(msg, style: const TextStyle(color: FtpDtpTheme.amber)),
        TextButton(
          onPressed: () => setState(() {
            _error = null;
            _mode = _Mode.choose;
          }),
          child: const Text('Back'),
        ),
      ],
    );
  }
}
