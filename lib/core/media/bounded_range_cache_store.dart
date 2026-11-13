import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:streaming_video_cache/streaming_video_cache.dart';

/// Disk-backed range cache with both a global byte cap and a per-media cap.
///
/// `RangeCacheStore` protects the entry currently being written from LRU
/// eviction. A single long movie can therefore grow past the configured global
/// limit. This store keeps per-chunk access order and evicts old chunks from the
/// active entry as well, so the disk footprint remains bounded.
class BoundedRangeCacheStore implements CacheStore {
  BoundedRangeCacheStore({
    required this.directory,
    required this.maxBytes,
    required this.maxEntryBytes,
    this.chunkSize = 1 << 20,
  }) : assert(maxBytes > 0),
       assert(maxEntryBytes > 0),
       assert(chunkSize > 0),
       assert(maxBytes >= chunkSize);

  final Directory directory;
  final int maxBytes;
  final int maxEntryBytes;

  @override
  final int chunkSize;

  final Map<String, _CacheEntry> _entries = <String, _CacheEntry>{};
  final Set<String> _pinned = <String>{};
  int _clock = 0;

  static String _encodeKey(String key) =>
      base64Url.encode(utf8.encode(key)).replaceAll('=', '');

  String _entryPath(String dirName) => '${directory.path}/$dirName';
  String _chunkPath(String dirName, int index) =>
      '${_entryPath(dirName)}/c$index';
  String _metaPath(String dirName) => '${_entryPath(dirName)}/meta.json';

  Future<void> init() async {
    _entries.clear();
    _pinned.clear();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      return;
    }

    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final dirName = entity.path.split(Platform.pathSeparator).last;
      final entry = _CacheEntry(dirName);
      Map<String, dynamic> meta = const <String, dynamic>{};
      try {
        await for (final file in entity.list(followLinks: false)) {
          if (file is! File) {
            continue;
          }
          final name = file.path.split(Platform.pathSeparator).last;
          if (name == 'meta.json') {
            try {
              final decoded = jsonDecode(await file.readAsString());
              if (decoded is Map<String, dynamic>) {
                meta = decoded;
              }
            } catch (_) {}
            continue;
          }
          if (name.endsWith('.part')) {
            try {
              await file.delete();
            } catch (_) {}
            continue;
          }
          final match = RegExp(r'^c(\d+)$').firstMatch(name);
          if (match == null) {
            continue;
          }
          final index = int.tryParse(match.group(1)!);
          if (index != null) {
            try {
              entry.chunkBytes[index] = await file.length();
            } catch (_) {}
          }
        }
      } catch (_) {}

      final storedTotal = meta['totalLength'];
      entry.totalLength = storedTotal is num ? storedTotal.toInt() : null;
      final storedAccess = meta['lastAccess'];
      entry.lastAccess = storedAccess is num ? storedAccess.toInt() : 0;
      final accesses = meta['chunkAccess'];
      if (accesses is Map) {
        for (final item in accesses.entries) {
          final index = int.tryParse(item.key.toString());
          if (index == null || !entry.chunkBytes.containsKey(index)) {
            continue;
          }
          final storedChunkAccess = item.value;
          entry.chunkAccess[index] = storedChunkAccess is num
              ? storedChunkAccess.toInt()
              : entry.lastAccess;
        }
      }
      for (final index in entry.chunkBytes.keys) {
        entry.chunkAccess.putIfAbsent(index, () => entry.lastAccess);
      }
      _entries[dirName] = entry;
      if (entry.lastAccess > _clock) {
        _clock = entry.lastAccess;
      }
      _clock = entry.chunkAccess.values.fold(
        _clock,
        (latest, access) => access > latest ? access : latest,
      );
    }
    _clock++;
    for (final entry in _entries.values) {
      await _trimEntry(entry, protectIndex: -1);
    }
    await _enforceGlobalLimit();
  }

  @override
  int? totalLength(String key) => _entries[_dirName(key)]?.totalLength;

  @override
  Future<void> setTotalLength(String key, int length) async {
    final entry = _entryFor(key);
    if (entry.totalLength == length) {
      return;
    }
    entry.totalLength = length;
    entry.lastAccess = ++_clock;
    await _persistMeta(entry);
  }

  @override
  bool hasChunk(String key, int index) =>
      _entries[_dirName(key)]?.chunkBytes.containsKey(index) ?? false;

  @override
  Future<Uint8List?> readChunk(String key, int index) async {
    final dirName = _dirName(key);
    final entry = _entries[dirName];
    if (entry == null || !entry.chunkBytes.containsKey(index)) {
      return null;
    }
    try {
      final bytes = await File(_chunkPath(dirName, index)).readAsBytes();
      final expected = _expectedChunkLength(entry, index);
      if (expected != null && bytes.length != expected) {
        await _deleteChunk(entry, index);
        return null;
      }
      entry.lastAccess = ++_clock;
      entry.chunkAccess[index] = entry.lastAccess;
      return bytes;
    } catch (_) {
      entry.chunkBytes.remove(index);
      entry.chunkAccess.remove(index);
      return null;
    }
  }

  @override
  Future<void> putChunk(String key, int index, List<int> bytes) async {
    final dirName = _dirName(key);
    final entry = _entryFor(key);
    final expected = _expectedChunkLength(entry, index);
    if (expected != null && bytes.length != expected) {
      return;
    }
    try {
      final dir = Directory(_entryPath(dirName));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final part = File('${_chunkPath(dirName, index)}.part');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(_chunkPath(dirName, index));
      entry.chunkBytes[index] = bytes.length;
      entry.lastAccess = ++_clock;
      entry.chunkAccess[index] = entry.lastAccess;
      await _trimEntry(entry, protectIndex: index);
      await _persistMeta(entry);
      await _enforceGlobalLimit(protect: dirName);
    } catch (_) {
      // Cache writes are best-effort; playback continues without a cached copy.
    }
  }

  @override
  void pin(Iterable<String> keys) {
    _pinned
      ..clear()
      ..addAll(keys.map(_dirName));
  }

  @override
  CacheUsage usage() => CacheUsage(
    usedBytes: _usedBytes,
    maxBytes: maxBytes,
    entryCount: _entries.length,
  );

  @override
  Future<void> evictKey(String key) async {
    final dirName = _dirName(key);
    _entries.remove(dirName);
    try {
      final dir = Directory(_entryPath(dirName));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _pinned.clear();
    try {
      if (await directory.exists()) {
        await for (final entity in directory.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  String _dirName(String key) => _encodeKey(key);

  _CacheEntry _entryFor(String key) =>
      _entries.putIfAbsent(_dirName(key), () => _CacheEntry(_dirName(key)));

  int? _expectedChunkLength(_CacheEntry entry, int index) {
    final total = entry.totalLength;
    if (total == null) {
      return null;
    }
    final start = index * chunkSize;
    if (start < 0 || start >= total) {
      return 0;
    }
    final remaining = total - start;
    return remaining < chunkSize ? remaining : chunkSize;
  }

  int get _usedBytes =>
      _entries.values.fold<int>(0, (sum, entry) => sum + entry.bytes);

  Future<void> _trimEntry(
    _CacheEntry entry, {
    required int protectIndex,
  }) async {
    var limit = maxEntryBytes < chunkSize ? chunkSize : maxEntryBytes;
    if (limit > maxBytes) {
      limit = maxBytes;
    }
    while (entry.bytes > limit && entry.chunkBytes.length > 1) {
      int? victim;
      var oldest = 1 << 62;
      for (final index in entry.chunkBytes.keys) {
        if (index == protectIndex) {
          continue;
        }
        final access = entry.chunkAccess[index] ?? 0;
        if (access < oldest) {
          oldest = access;
          victim = index;
        }
      }
      if (victim == null) {
        break;
      }
      await _deleteChunk(entry, victim);
    }
  }

  Future<void> _enforceGlobalLimit({String? protect}) async {
    while (_usedBytes > maxBytes) {
      _CacheEntry? victim;
      for (final entry in _entries.values) {
        if (entry.dirName == protect || _pinned.contains(entry.dirName)) {
          continue;
        }
        if (victim == null || entry.lastAccess < victim.lastAccess) {
          victim = entry;
        }
      }
      if (victim == null) {
        break;
      }
      _entries.remove(victim.dirName);
      try {
        final dir = Directory(_entryPath(victim.dirName));
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<void> _deleteChunk(_CacheEntry entry, int index) async {
    entry.chunkBytes.remove(index);
    entry.chunkAccess.remove(index);
    try {
      final file = File(_chunkPath(entry.dirName, index));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _persistMeta(_CacheEntry entry) async {
    try {
      final dir = Directory(_entryPath(entry.dirName));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final part = File('${_metaPath(entry.dirName)}.part');
      await part.writeAsString(
        jsonEncode(<String, dynamic>{
          'totalLength': entry.totalLength,
          'lastAccess': entry.lastAccess,
          'chunkAccess': entry.chunkAccess.map(
            (index, access) => MapEntry('$index', access),
          ),
        }),
        flush: true,
      );
      await part.rename(_metaPath(entry.dirName));
    } catch (_) {}
  }
}

class _CacheEntry {
  _CacheEntry(this.dirName);

  final String dirName;
  int? totalLength;
  int lastAccess = 0;
  final Map<int, int> chunkBytes = <int, int>{};
  final Map<int, int> chunkAccess = <int, int>{};

  int get bytes =>
      chunkBytes.values.fold<int>(0, (sum, length) => sum + length);
}
