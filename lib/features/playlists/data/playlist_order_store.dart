import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class PlaylistOrderStore {
  Future<List<int>> readPlaylistOrder({required String scopeKey});
  Future<void> savePlaylistOrder({
    required String scopeKey,
    required List<int> playlistIds,
  });
}

class SharedPreferencesPlaylistOrderStore implements PlaylistOrderStore {
  const SharedPreferencesPlaylistOrderStore();

  static const String _storagePrefix = 'mobile_overview.playlist_order.';

  @visibleForTesting
  static String storageKeyForScope(String scopeKey) {
    return '$_storagePrefix${Uri.encodeComponent(scopeKey)}';
  }

  @override
  Future<List<int>> readPlaylistOrder({required String scopeKey}) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getStringList(storageKeyForScope(scopeKey));
      if (raw == null || raw.isEmpty) {
        return const <int>[];
      }

      final ids = <int>[];
      for (final value in raw) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          ids.add(parsed);
        }
      }
      return ids;
    } catch (_) {
      return const <int>[];
    }
  }

  @override
  Future<void> savePlaylistOrder({
    required String scopeKey,
    required List<int> playlistIds,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        storageKeyForScope(scopeKey),
        playlistIds.map((id) => id.toString()).toList(growable: false),
      );
    } catch (_) {
      // Ignore persistence failures so UI interactions stay responsive.
    }
  }
}

class InMemoryPlaylistOrderStore implements PlaylistOrderStore {
  final Map<String, List<int>> _storage = <String, List<int>>{};

  @override
  Future<List<int>> readPlaylistOrder({required String scopeKey}) async {
    return List<int>.from(_storage[scopeKey] ?? const <int>[]);
  }

  @override
  Future<void> savePlaylistOrder({
    required String scopeKey,
    required List<int> playlistIds,
  }) async {
    _storage[scopeKey] = List<int>.from(playlistIds);
  }

  UnmodifiableMapView<String, List<int>> get snapshot {
    return UnmodifiableMapView<String, List<int>>(_storage);
  }
}
