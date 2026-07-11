import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../ftp/local_file_share_service.dart';
import 'ftp_dtp_theme.dart';

/// Shows the file-share (FTP) host dialog: starts a LAN HTTP server and
/// displays a QR code + connection details for receivers.
Future<void> showFileShareDialog(
  BuildContext context, {
  required LocalFileShareService service,
  String title = 'Share Data',
  String description =
      'Scan this QR from the other device. Both devices must be on the same Wi-Fi network.',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FileShareDialog(
      service: service,
      title: title,
      description: description,
    ),
  );
}

class FileShareDialog extends StatefulWidget {
  const FileShareDialog({
    super.key,
    required this.service,
    this.title = 'Share Data',
    this.description =
        'Scan this QR from the other device. Both devices must be on the same Wi-Fi network.',
  });

  final LocalFileShareService service;
  final String title;
  final String description;

  @override
  State<FileShareDialog> createState() => _FileShareDialogState();
}

class _FileShareDialogState extends State<FileShareDialog> {
  ShareSession? _session;
  String? _error;
  bool _loading = true;
  int _downloads = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (!widget.service.isSupported) {
      setState(() {
        _loading = false;
        _error =
            'Sharing over Wi-Fi is not available on this platform. Use Android, '
            'iOS, or desktop to host.';
      });
      return;
    }
    try {
      final session = await widget.service.startSharing(
        onClientDownloaded: () {
          if (mounted) setState(() => _downloads++);
        },
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _loading = false;
        _error = session.ip == null
            ? 'Could not detect this device\'s IP address. Ensure Wi-Fi is on.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not start sharing: $e';
      });
    }
  }

  @override
  void dispose() {
    widget.service.stopSharing();
    super.dispose();
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
                  const Icon(Icons.share, color: FtpDtpTheme.blue),
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
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_session == null)
                _errorBox(_error ?? 'Something went wrong.')
              else
                _sessionView(_session!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sessionView(ShareSession s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.description,
            style: const TextStyle(fontSize: 13, color: FtpDtpTheme.textMute)),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FtpDtpTheme.grayLine),
            ),
            child: SizedBox(
              width: 200,
              height: 200,
              child: PrettyQrView.data(
                data: s.qrPayload,
                decoration: const PrettyQrDecoration(
                  shape: PrettyQrSmoothSymbol(color: FtpDtpTheme.text),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null) ...[
          _inlineWarn(_error!),
          const SizedBox(height: 12),
        ],
        _detailRow('Address', '${s.ip ?? '—'}:${s.port}'),
        const SizedBox(height: 8),
        _detailRow('Token', s.token, copyable: true),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _downloads > 0 ? const Color(0xFFEAF7EF) : FtpDtpTheme.grayBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _downloads > 0 ? Icons.check_circle : Icons.wifi_tethering,
                size: 18,
                color: _downloads > 0 ? FtpDtpTheme.green : FtpDtpTheme.textMute,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _downloads > 0
                      ? '$_downloads device${_downloads == 1 ? '' : 's'} downloaded.'
                      : 'Waiting for a device to connect…',
                  style: const TextStyle(fontSize: 13, color: FtpDtpTheme.text),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: FtpDtpTheme.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Stop Sharing'),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: FtpDtpTheme.textMute)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: FtpDtpTheme.text)),
        ),
        if (copyable)
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token copied')),
              );
            },
            icon: const Icon(Icons.copy, size: 16, color: FtpDtpTheme.blue),
          ),
      ],
    );
  }

  Widget _inlineWarn(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF3E4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: FtpDtpTheme.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(fontSize: 12.5, color: FtpDtpTheme.text)),
            ),
          ],
        ),
      );

  Widget _errorBox(String msg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _inlineWarn(msg),
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
  }
}
