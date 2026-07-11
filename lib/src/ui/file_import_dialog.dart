import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../common/share_target.dart';
import '../ftp/local_file_share_service.dart';
import 'ftp_dtp_theme.dart';

/// Shows the file-import (FTP) dialog. Returns [ImportSummary] on success.
Future<ImportSummary?> showFileImportDialog(
  BuildContext context, {
  required LocalFileShareService service,
  String title = 'Import Data',
  String blockedMessage =
      'Cannot import while there are active items. Clear them first.',
}) {
  return showDialog<ImportSummary>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FileImportDialog(
      service: service,
      title: title,
      blockedMessage: blockedMessage,
    ),
  );
}

enum _Stage { blocked, scan, manual, fetching, confirm, importing, error }

class FileImportDialog extends StatefulWidget {
  const FileImportDialog({
    super.key,
    required this.service,
    this.title = 'Import Data',
    this.blockedMessage =
        'Cannot import while there are active items. Clear them first.',
  });

  final LocalFileShareService service;
  final String title;
  final String blockedMessage;

  @override
  State<FileImportDialog> createState() => _FileImportDialogState();
}

class _FileImportDialogState extends State<FileImportDialog> {
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '8080');
  final _tokenCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  MobileScannerController? _scanner;
  bool _handling = false;
  late _Stage _stage;
  String? _error;
  Map<String, dynamic>? _fetched;
  ImportSummary? _preview;

  bool get _scannerSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  void initState() {
    super.initState();
    if (!widget.service.canImportNow()) {
      _stage = _Stage.blocked;
    } else if (_scannerSupported) {
      _stage = _Stage.scan;
      _scanner = MobileScannerController();
    } else {
      _stage = _Stage.manual;
    }
  }

  @override
  void dispose() {
    _scanner?.dispose();
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
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
      await _fetch(target);
    } on ShareException catch (e) {
      _handling = false;
      setState(() {
        _stage = _Stage.error;
        _error = e.message;
      });
    } catch (_) {
      _handling = false;
      setState(() {
        _stage = _Stage.error;
        _error = 'That QR code is not a valid share code.';
      });
    }
  }

  Future<void> _submitManual() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _fetch(ShareTarget(
      ip: _ipCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      token: _tokenCtrl.text.trim().toUpperCase(),
      path: widget.service.dataPath,
    ));
  }

  Future<void> _fetch(ShareTarget target) async {
    setState(() {
      _stage = _Stage.fetching;
      _error = null;
    });
    try {
      final json = await widget.service.fetchExport(target);
      final preview = widget.service.previewImport(json);
      if (!mounted) return;
      setState(() {
        _fetched = json;
        _preview = preview;
        _stage = _Stage.confirm;
        _handling = false;
      });
    } on ShareException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e.message;
        _handling = false;
      });
    }
  }

  Future<void> _confirmImport() async {
    final json = _fetched;
    if (json == null) return;
    setState(() => _stage = _Stage.importing);
    try {
      final summary = await widget.service.importIntoStorage(json);
      if (!mounted) return;
      Navigator.of(context).pop(summary);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = 'Import failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.download, color: FtpDtpTheme.blue),
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
              const SizedBox(height: 8),
              _body(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_stage) {
      case _Stage.blocked:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.blockedMessage,
                style: const TextStyle(fontSize: 13, color: FtpDtpTheme.textMute)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        );
      case _Stage.scan:
        return Column(
          children: [
            const Text('Point the camera at the host QR code.',
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
                setState(() => _stage = _Stage.manual);
              },
              child: const Text('Enter details manually'),
            ),
          ],
        );
      case _Stage.manual:
        return Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _ipCtrl,
                decoration: const InputDecoration(labelText: 'IP address'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _portCtrl,
                decoration: const InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    int.tryParse(v?.trim() ?? '') == null ? 'Invalid port' : null,
              ),
              TextFormField(
                controller: _tokenCtrl,
                decoration: const InputDecoration(labelText: 'Token'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submitManual,
                child: const Text('Connect'),
              ),
            ],
          ),
        );
      case _Stage.fetching:
      case _Stage.importing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        );
      case _Stage.confirm:
        final p = _preview!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              p.label.isNotEmpty
                  ? 'Import from "${p.label}"?'
                  : 'Import ${p.itemCount} item(s)?',
              style: const TextStyle(fontSize: 14, color: FtpDtpTheme.text),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _confirmImport,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FtpDtpTheme.blue,
                      foregroundColor: Colors.white),
                  child: const Text('Import'),
                ),
              ],
            ),
          ],
        );
      case _Stage.error:
        return Column(
          children: [
            Text(_error ?? 'Error',
                style: const TextStyle(color: FtpDtpTheme.red)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
    }
  }
}
