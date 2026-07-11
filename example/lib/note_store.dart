import 'dart:async';
import 'dart:convert';

import 'package:flutter_ftp_dtp/flutter_ftp_dtp.dart';

/// Simple in-memory note for the example app.
class Note {
  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.modifiedAt,
  });

  final String id;
  final String title;
  final String body;
  final String modifiedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'modifiedAt': modifiedAt,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        modifiedAt: json['modifiedAt']?.toString() ??
            DateTime.now().toUtc().toIso8601String(),
      );

  Note copyWith({String? title, String? body}) => Note(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
        modifiedAt: DateTime.now().toUtc().toIso8601String(),
      );
}

/// Local note storage with change notifications for DTP sync.
class NoteStore {
  NoteStore();

  final List<Note> _notes = [];
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;
  List<Note> get notes => List.unmodifiable(_notes);

  void _notify() => _changes.add(null);

  Map<String, dynamic> exportJson() => {
        'label': 'Shared Notes',
        'items': _notes.map((n) => n.toJson()).toList(),
      };

  void replaceAll(List<Note> incoming) {
    _notes
      ..clear()
      ..addAll(incoming);
    _notify();
  }

  void addNote(String title, String body) {
    _notes.add(Note(
      id: 'note_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      body: body,
      modifiedAt: DateTime.now().toUtc().toIso8601String(),
    ));
    _notify();
  }

  void updateNote(String id, {String? title, String? body}) {
    final i = _notes.indexWhere((n) => n.id == id);
    if (i < 0) return;
    _notes[i] = _notes[i].copyWith(title: title, body: body);
    _notify();
  }

  void removeNote(String id) {
    _notes.removeWhere((n) => n.id == id);
    _notify();
  }

  Note? getNote(String id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  void dispose() => _changes.close();
}

/// [SyncAdapter] implementation for the example notes app.
class NoteSyncAdapter implements SyncAdapter {
  NoteSyncAdapter(this.store);

  final NoteStore store;
  StreamSubscription? _sub;
  final Map<String, String> _suppress = {};

  @override
  Future<Map<String, dynamic>> buildSnapshot() async => {
        'items': store.notes.map((n) => n.toJson()).toList(),
      };

  @override
  Future<void> applyRemote(SyncMessage message) async {
    switch (message.type) {
      case SyncType.snapshot:
        final data = message.data;
        if (data is Map) {
          final items = data['items'];
          if (items is List) {
            store.replaceAll(
              items
                  .whereType<Map>()
                  .map((m) => Note.fromJson(m.cast<String, dynamic>()))
                  .toList(),
            );
          }
        }
        break;
      case SyncType.entityUpsert:
        final data = message.data;
        if (data is! Map || message.id == null) return;
        final incoming =
            Note.fromJson(data.cast<String, dynamic>());
        final existing = store.getNote(incoming.id);
        if (existing != null &&
            RealtimeSyncEngine.isNewer(
                existing.modifiedAt, incoming.modifiedAt)) {
          return;
        }
        _suppress[incoming.id] = jsonEncode(incoming.toJson());
        if (existing == null) {
          store.replaceAll([...store.notes, incoming]);
        } else {
          store.updateNote(incoming.id,
              title: incoming.title, body: incoming.body);
        }
        break;
      case SyncType.entityDelete:
        if (message.id == null) return;
        _suppress[message.id!] = '__deleted__';
        store.removeNote(message.id!);
        break;
      case SyncType.collection:
        final data = message.data;
        if (data is List) {
          final sig = jsonEncode(data);
          if (_suppress['_collection'] == sig) {
            _suppress.remove('_collection');
            return;
          }
          store.replaceAll(
            data
                .whereType<Map>()
                .map((m) => Note.fromJson(m.cast<String, dynamic>()))
                .toList(),
          );
        }
        break;
    }
  }

  @override
  void startWatching(void Function(SyncMessage message) onLocalChange) {
    _sub = store.changes.listen((_) {
      for (final note in store.notes) {
        final json = note.toJson();
        final sig = jsonEncode(json);
        if (_suppress[note.id] == sig) {
          _suppress.remove(note.id);
          continue;
        }
        if (_suppress[note.id] == '__deleted__') {
          _suppress.remove(note.id);
          continue;
        }
        onLocalChange(RealtimeSyncEngine.entityUpsert(
          id: note.id,
          data: json,
        ));
        return;
      }
    });
  }

  @override
  Future<void> stopWatching() async {
    await _sub?.cancel();
    _sub = null;
    _suppress.clear();
  }
}

/// FTP service wired to [NoteStore].
LocalFileShareService createNoteShareService(NoteStore store) {
  return LocalFileShareService(
    label: 'Shared Notes',
    buildExport: store.exportJson,
    importExport: (json) async {
      final items = ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => Note.fromJson(m.cast<String, dynamic>()))
          .toList();
      store.replaceAll(items);
      return ImportSummary(itemCount: items.length, label: 'Shared Notes');
    },
    canImport: () => true,
  );
}
