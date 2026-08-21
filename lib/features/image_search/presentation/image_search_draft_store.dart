import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

@immutable
class ImageSearchDraft {
  const ImageSearchDraft({
    required this.id,
    required this.fileName,
    required this.bytes,
    this.mimeType,
  });

  final String id;
  final String fileName;
  final Uint8List bytes;
  final String? mimeType;
}

class ImageSearchDraftStore {
  ImageSearchDraftStore({this.maxEntries = 16});

  final int maxEntries;
  final LinkedHashMap<String, ImageSearchDraft> _entries =
      LinkedHashMap<String, ImageSearchDraft>();
  final Random _random = Random();

  String save({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) {
    final id = _nextId();
    _entries[id] = ImageSearchDraft(
      id: id,
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    _evictIfNeeded();
    return id;
  }

  ImageSearchDraft? get(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    final draft = _entries.remove(id);
    if (draft == null) {
      return null;
    }
    _entries[id] = draft;
    return draft;
  }

  void clear() {
    _entries.clear();
  }

  String _nextId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final nonce = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$timestamp$nonce';
  }

  void _evictIfNeeded() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}
