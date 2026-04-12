import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/playlists/data/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/data/playlist_order_store.dart';

typedef PlaylistListFetcher =
    Future<List<PlaylistDto>> Function({bool includeSystem});
typedef PlaylistCoverFetcher = Future<String?> Function(int playlistId);
typedef PlaylistCreator =
    Future<PlaylistDto> Function({required String name, String? description});

class PlaylistsOverviewController extends ChangeNotifier {
  PlaylistsOverviewController({
    required this.fetchPlaylists,
    required this.fetchPlaylistCoverUrl,
    required this.createPlaylist,
    this.playlistOrderStore,
    this.orderScopeKey,
  });

  final PlaylistListFetcher fetchPlaylists;
  final PlaylistCoverFetcher fetchPlaylistCoverUrl;
  final PlaylistCreator createPlaylist;
  final PlaylistOrderStore? playlistOrderStore;
  final String? orderScopeKey;

  List<PlaylistDto> _playlists = const <PlaylistDto>[];
  final Map<int, String?> _coverUrls = <int, String?>{};
  bool _isLoading = true;
  bool _isCreating = false;
  String? _errorMessage;

  List<PlaylistDto> get playlists => _playlists;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get errorMessage => _errorMessage;

  String? coverUrlFor(int playlistId) => _coverUrls[playlistId];

  void reorderPlaylists(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= _playlists.length ||
        newIndex < 0 ||
        newIndex > _playlists.length) {
      return;
    }

    var targetIndex = newIndex;
    if (targetIndex > oldIndex) {
      targetIndex -= 1;
    }
    if (targetIndex == oldIndex) {
      return;
    }

    final updated = List<PlaylistDto>.from(_playlists);
    final moved = updated.removeAt(oldIndex);
    updated.insert(targetIndex, moved);
    _playlists = updated;
    notifyListeners();
    unawaited(_savePlaylistOrder(updated));
  }

  Future<void> refresh() async {
    final playlists = await _loadAndApplyPlaylists();
    final coverUrls = await _fetchCoverUrls(playlists);
    _playlists = playlists;
    _coverUrls
      ..clear()
      ..addAll(coverUrls);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final playlists = await _loadAndApplyPlaylists();
      _playlists = playlists;
      _errorMessage = null;
      notifyListeners();
      await _loadCoverUrls(playlists);
    } catch (error) {
      _playlists = const <PlaylistDto>[];
      _errorMessage = apiErrorMessage(error, fallback: '播放列表暂时无法加载，请稍后重试');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<PlaylistDto> createNewPlaylist({
    required String name,
    String? description,
  }) async {
    _isCreating = true;
    notifyListeners();
    try {
      final playlist = await createPlaylist(
        name: name,
        description: description,
      );
      _playlists = <PlaylistDto>[playlist, ..._playlists];
      _coverUrls[playlist.id] = null;
      notifyListeners();
      unawaited(_savePlaylistOrder(_playlists));
      return playlist;
    } finally {
      _isCreating = false;
      notifyListeners();
    }
  }

  void insertPlaylist(PlaylistDto playlist) {
    _playlists = <PlaylistDto>[playlist, ..._playlists];
    _coverUrls[playlist.id] = null;
    notifyListeners();
    unawaited(_savePlaylistOrder(_playlists));
  }

  Future<List<PlaylistDto>> _loadAndApplyPlaylists() async {
    final playlists = await fetchPlaylists(includeSystem: true);
    return _applyStoredOrder(playlists);
  }

  Future<List<PlaylistDto>> _applyStoredOrder(
    List<PlaylistDto> playlists,
  ) async {
    final scopeKey = _normalizedScopeKey;
    final orderStore = playlistOrderStore;
    if (orderStore == null || scopeKey == null) {
      return playlists;
    }

    try {
      final storedOrder = await orderStore.readPlaylistOrder(
        scopeKey: scopeKey,
      );
      if (storedOrder.isEmpty) {
        return playlists;
      }

      final byId = <int, PlaylistDto>{
        for (final playlist in playlists) playlist.id: playlist,
      };
      final ordered = <PlaylistDto>[];
      final seen = <int>{};

      for (final id in storedOrder) {
        final playlist = byId[id];
        if (playlist == null || !seen.add(id)) {
          continue;
        }
        ordered.add(playlist);
      }

      for (final playlist in playlists) {
        if (!seen.add(playlist.id)) {
          continue;
        }
        ordered.add(playlist);
      }

      final normalizedOrder = ordered.map((playlist) => playlist.id).toList();
      if (!listEquals(storedOrder, normalizedOrder)) {
        await orderStore.savePlaylistOrder(
          scopeKey: scopeKey,
          playlistIds: normalizedOrder,
        );
      }
      return ordered;
    } catch (_) {
      return playlists;
    }
  }

  Future<void> _savePlaylistOrder(List<PlaylistDto> playlists) async {
    final scopeKey = _normalizedScopeKey;
    final orderStore = playlistOrderStore;
    if (orderStore == null || scopeKey == null) {
      return;
    }
    try {
      await orderStore.savePlaylistOrder(
        scopeKey: scopeKey,
        playlistIds: playlists.map((playlist) => playlist.id).toList(),
      );
    } catch (_) {
      // Ignore persistence failures so in-memory interactions stay available.
    }
  }

  String? get _normalizedScopeKey {
    final raw = orderScopeKey?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  Future<void> _loadCoverUrls(List<PlaylistDto> playlists) async {
    for (final playlist in playlists) {
      if (playlist.movieCount <= 0) {
        _coverUrls[playlist.id] = null;
        continue;
      }
      try {
        _coverUrls[playlist.id] = await fetchPlaylistCoverUrl(playlist.id);
      } catch (_) {
        _coverUrls[playlist.id] = null;
      }
      notifyListeners();
    }
  }

  Future<Map<int, String?>> _fetchCoverUrls(List<PlaylistDto> playlists) async {
    final coverUrls = <int, String?>{};
    for (final playlist in playlists) {
      if (playlist.movieCount <= 0) {
        coverUrls[playlist.id] = null;
        continue;
      }
      try {
        coverUrls[playlist.id] = await fetchPlaylistCoverUrl(playlist.id);
      } catch (_) {
        coverUrls[playlist.id] = null;
      }
    }
    return coverUrls;
  }
}
