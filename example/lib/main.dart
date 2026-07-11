import 'package:flutter/material.dart';
import 'package:flutter_ftp_dtp/flutter_ftp_dtp.dart';
import 'package:permission_handler/permission_handler.dart';

import 'note_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FtpDtpExampleApp());
}

class FtpDtpExampleApp extends StatelessWidget {
  const FtpDtpExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FTP & DTP Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A56C4)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NoteStore _store = NoteStore();
  late final LocalFileShareService _shareService;
  late final RealtimeSyncEngine _syncEngine;

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _shareService = createNoteShareService(_store);
    _syncEngine = RealtimeSyncEngine(NoteSyncAdapter(_store));
    _syncEngine.onChanged = () {
      if (mounted) setState(() {});
    };
    _store.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _store.addNote('Welcome', 'Add notes and try FTP share or DTP live sync.');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _syncEngine.stop();
    _store.dispose();
    super.dispose();
  }

  Future<void> _requestCamera() async {
    await Permission.camera.request();
  }

  void _addNote() {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty) return;
    _store.addNote(title, body);
    _titleCtrl.clear();
    _bodyCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final syncActive = _syncEngine.isActive;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FTP & DTP Example'),
        actions: [
          if (syncActive)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.sync, size: 16),
                label: Text(_syncEngine.role == SyncRole.host
                    ? 'Hosting (${_syncEngine.clientCount})'
                    : 'Synced'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => showFileShareDialog(
                    context,
                    service: _shareService,
                    title: 'Share Notes (FTP)',
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Share (FTP)'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _requestCamera();
                    if (!context.mounted) return;
                    await showFileImportDialog(
                      context,
                      service: _shareService,
                      title: 'Import Notes (FTP)',
                    );
                    setState(() {});
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Import (FTP)'),
                ),
                ElevatedButton.icon(
                  onPressed: () => showRealtimeSyncDialog(
                    context,
                    engine: _syncEngine,
                    title: 'Live Sync (DTP)',
                  ),
                  icon: const Icon(Icons.sync),
                  label: const Text('Live Sync (DTP)'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _bodyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Body',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _addNote,
                  icon: const Icon(Icons.add_circle),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _store.notes.isEmpty
                ? const Center(child: Text('No notes yet'))
                : ListView.builder(
                    itemCount: _store.notes.length,
                    itemBuilder: (context, i) {
                      final note = _store.notes[i];
                      return ListTile(
                        title: Text(note.title),
                        subtitle: Text(note.body),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _store.removeNote(note.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
