import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_mutation_events_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlist_order_store_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_api_provider.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_scope.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/playlists_overview_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';

part 'playlists_overview_provider.g.dart';

/// 播放列表概览：加载全量列表 + 后台逐个填首图，支持拖排序（可选持久化）、
/// 创建 / 编辑 / 删除的就地补丁，并监听跨页变更广播同步其他入口。
///
/// autoDispose family([PlaylistsOverviewScope])：桌面/移动列表页按 baseUrl
/// scope 定位实例、共享拖排顺序；orderScopeKey=null 表不持久化顺序。
///
/// 迁移前对应：`PlaylistsOverviewController`（5 个构造参数：3 个 API 闭包 +
/// orderStore + orderScopeKey）——本 provider 内联所有依赖（API/Store 各自
/// provider），scope 只留 orderScopeKey 一个业务参数。
///
/// **reorder 保持 fire-and-forget 语义**（原 controller
/// `unawaited(_savePlaylistOrder(...))`）——UI 侧无回滚需求，改成 await 会引入
/// 等待窗口。
@Riverpod(retry: kNoAsyncNotifierRetry)
class PlaylistsOverview extends _$PlaylistsOverview
    with AsyncNotifierDisposeGuardMixin<PlaylistsOverviewState> {
  int _coverFetchGeneration = 0;

  @override
  Future<PlaylistsOverviewState> build(PlaylistsOverviewScope scope) async {
    attachDisposeGuard();
    ref.listen(playlistMutationEventsProvider, (_, next) {
      final change = next.value;
      if (change == null) return;
      switch (change.kind) {
        case PlaylistMutationKind.updated:
          final playlist = change.playlist;
          if (playlist != null) {
            replacePlaylist(playlist);
          }
        case PlaylistMutationKind.deleted:
          final playlistId = change.deletedId;
          if (playlistId != null) {
            removePlaylist(playlistId);
          }
      }
    });
    final playlists = await _loadAndApplyPlaylists();
    final coverFetchGeneration = ++_coverFetchGeneration;
    // 首次加载没有旧封面；后续刷新会保留仍有效的旧封面，避免卡片回退到占位。
    unawaited(_startCoverUrlFetches(playlists, coverFetchGeneration));
    return PlaylistsOverviewState(
      playlists: playlists,
      coverUrls: _coverUrlsForPlaylists(playlists, const <int, String?>{}),
    );
  }

  /// 保留态刷新：不切 loading；失败**保留已展示列表**（state 原样不动,不可写
  /// `AsyncError`——那会把 `state.value` 清成 null,页面整页替换成错误空态）并
  /// 向上抛——4 个调用点都按「抛出即失败」契约处理（桌面壳 `_runRefresh` 兜底
  /// toast、移动页/概览骨架自行 catch + toast、configuration 对账刻意静默）。
  Future<void> refresh() async {
    final playlists = await _loadAndApplyPlaylists();
    if (isDisposed) return;
    final current = state.value;
    final coverFetchGeneration = ++_coverFetchGeneration;
    state = AsyncData(
      PlaylistsOverviewState(
        playlists: playlists,
        // 仍存在且非空的列表先继续显示旧封面；后台仍会全部重取，确保首图
        // 变更后不会永久保留旧图。新建、删除和变空的列表则立即反映为 null。
        coverUrls: _coverUrlsForPlaylists(
          playlists,
          current?.coverUrls ?? const <int, String?>{},
        ),
      ),
    );
    unawaited(_startCoverUrlFetches(playlists, coverFetchGeneration));
  }

  /// 拖排序：本地立即改 + fire-and-forget 保存新顺序（与原 controller 一致，
  /// UI 无回滚需求）。
  ///
  /// [newIndex] 是移除旧项后的最终下标，与
  /// `SliverReorderableList.onReorderItem` 的语义一致。
  void reorderPlaylists(int oldIndex, int newIndex) {
    final current = state.value;
    if (current == null) return;
    if (oldIndex < 0 ||
        oldIndex >= current.playlists.length ||
        newIndex < 0 ||
        newIndex >= current.playlists.length) {
      return;
    }
    if (newIndex == oldIndex) return;

    final updated = List<PlaylistDto>.from(current.playlists);
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    state = AsyncData(current.copyWith(playlists: updated));
    unawaited(_savePlaylistOrder(updated));
  }

  /// 只重排用户列表，系统列表保持原槽位。
  ///
  /// 概览页把系统列表和用户列表分区展示，用户列表的拖拽索引是子集内的
  /// 最终下标（`SliverReorderableList.onReorderItem` 语义），不能直接套用
  /// [reorderPlaylists] 的全量插入下标。
  void reorderCustomPlaylists(int oldIndex, int newIndex) {
    final current = state.value;
    if (current == null) return;
    final custom = current.playlists
        .where((playlist) => !playlist.isSystem)
        .toList(growable: false);
    if (oldIndex < 0 ||
        oldIndex >= custom.length ||
        newIndex < 0 ||
        newIndex >= custom.length ||
        newIndex == oldIndex) {
      return;
    }

    final reordered = List<PlaylistDto>.from(custom);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    var customIndex = 0;
    final updated = current.playlists
        .map(
          (playlist) => playlist.isSystem ? playlist : reordered[customIndex++],
        )
        .toList(growable: false);
    state = AsyncData(current.copyWith(playlists: updated));
    unawaited(_savePlaylistOrder(updated));
  }

  /// 通过 API 创建新播放列表并前置插入到本地列表。
  Future<PlaylistDto> createNewPlaylist({
    required String name,
    String? description,
  }) async {
    final playlist = await ref
        .read(playlistsApiProvider)
        .createPlaylist(name: name, description: description);
    if (!isDisposed) {
      insertPlaylist(playlist);
    }
    return playlist;
  }

  /// 已由外部创建：前置插入本地列表 + fire-and-forget 保存新顺序。
  void insertPlaylist(PlaylistDto playlist) {
    final current = state.value;
    if (current == null) return;
    final playlists = <PlaylistDto>[playlist, ...current.playlists];
    final coverUrls = <int, String?>{...current.coverUrls, playlist.id: null};
    state = AsyncData(
      current.copyWith(playlists: playlists, coverUrls: coverUrls),
    );
    unawaited(_savePlaylistOrder(playlists));
  }

  void replacePlaylist(PlaylistDto playlist) {
    final current = state.value;
    if (current == null) return;
    final updated = List<PlaylistDto>.from(current.playlists);
    final index = updated.indexWhere((item) => item.id == playlist.id);
    if (index >= 0) {
      updated[index] = playlist;
    } else {
      updated.insert(0, playlist);
    }
    final coverUrls = _coverUrlsForPlaylists(updated, current.coverUrls);
    state = AsyncData(
      current.copyWith(playlists: updated, coverUrls: coverUrls),
    );
    unawaited(_savePlaylistOrder(updated));
  }

  void removePlaylist(int playlistId) {
    final current = state.value;
    if (current == null) return;
    final playlists = current.playlists
        .where((playlist) => playlist.id != playlistId)
        .toList(growable: false);
    final coverUrls = Map<int, String?>.from(current.coverUrls)
      ..remove(playlistId);
    state = AsyncData(
      current.copyWith(playlists: playlists, coverUrls: coverUrls),
    );
    unawaited(_savePlaylistOrder(playlists));
  }

  Future<List<PlaylistDto>> _loadAndApplyPlaylists() async {
    final playlists = await ref.read(playlistsApiProvider).getPlaylists();
    return _applyStoredOrder(playlists);
  }

  Future<List<PlaylistDto>> _applyStoredOrder(
    List<PlaylistDto> playlists,
  ) async {
    final scopeKey = _normalizedScopeKey;
    if (scopeKey == null) {
      return playlists;
    }
    final store = ref.read(playlistOrderStoreProvider);
    try {
      final storedOrder = await store.readPlaylistOrder(scopeKey: scopeKey);
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

      final normalizedOrder = ordered
          .map((playlist) => playlist.id)
          .toList(growable: false);
      if (!listEquals(storedOrder, normalizedOrder)) {
        await store.savePlaylistOrder(
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
    if (scopeKey == null) return;
    final store = ref.read(playlistOrderStoreProvider);
    try {
      await store.savePlaylistOrder(
        scopeKey: scopeKey,
        playlistIds: playlists.map((playlist) => playlist.id).toList(),
      );
    } catch (_) {
      // 忽略持久化失败，本地交互保持可用。
    }
  }

  String? get _normalizedScopeKey {
    final raw = scope.orderScopeKey?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  Map<int, String?> _coverUrlsForPlaylists(
    List<PlaylistDto> playlists,
    Map<int, String?> previousCoverUrls,
  ) => <int, String?>{
    for (final playlist in playlists)
      playlist.id: playlist.movieCount > 0
          ? previousCoverUrls[playlist.id]
          : null,
  };

  Future<void> _startCoverUrlFetches(
    List<PlaylistDto> playlists,
    int generation,
  ) async {
    final api = ref.read(playlistsApiProvider);
    for (final playlist in playlists) {
      if (isDisposed || generation != _coverFetchGeneration) return;
      if (playlist.movieCount <= 0) continue;
      String? url;
      try {
        final page = await api.getPlaylistMovies(
          playlistId: playlist.id,
          pageSize: 1,
        );
        url = page.items.firstOrNull?.coverImage?.origin;
      } catch (_) {
        // 刷新请求失败时保留旧封面；成功但无首图仍会写入 null。
        continue;
      }
      if (isDisposed || generation != _coverFetchGeneration) return;
      final current = state.value;
      if (current == null) return;
      final isStillNonEmpty = current.playlists.any(
        (currentPlaylist) =>
            currentPlaylist.id == playlist.id && currentPlaylist.movieCount > 0,
      );
      if (!isStillNonEmpty) continue;
      state = AsyncData(
        current.copyWith(
          coverUrls: <int, String?>{...current.coverUrls, playlist.id: url},
        ),
      );
    }
  }
}
