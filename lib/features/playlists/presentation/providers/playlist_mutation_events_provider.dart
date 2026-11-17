import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';

part 'playlist_mutation_events_provider.g.dart';

enum PlaylistMutationKind { updated, deleted }

/// 一次播放列表变更事件的载荷。
@immutable
class PlaylistMutationChange {
  const PlaylistMutationChange({
    required this.kind,
    this.playlist,
    this.deletedId,
  });

  final PlaylistMutationKind kind;

  /// 仅 [PlaylistMutationKind.updated] 时有意义。
  final PlaylistDto? playlist;

  /// 仅 [PlaylistMutationKind.deleted] 时有意义。
  final int? deletedId;
}

/// 播放列表跨页变更广播 —— 与 `videoMutationEventsProvider` 同范式。
///
/// **消费方**：`ref.listen(playlistMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })` 就地补丁。
///
/// **发起方**：详情页编辑/删除后 `reportUpdated` / `reportDeleted`。
@Riverpod(keepAlive: true)
class PlaylistMutationEvents extends _$PlaylistMutationEvents {
  final StreamController<PlaylistMutationChange> _controller =
      StreamController<PlaylistMutationChange>.broadcast(sync: true);

  @override
  Stream<PlaylistMutationChange> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  void reportUpdated(PlaylistDto playlist) {
    if (_controller.isClosed) return;
    _controller.add(
      PlaylistMutationChange(
        kind: PlaylistMutationKind.updated,
        playlist: playlist,
      ),
    );
  }

  void reportDeleted(int playlistId) {
    if (_controller.isClosed) return;
    _controller.add(
      PlaylistMutationChange(
        kind: PlaylistMutationKind.deleted,
        deletedId: playlistId,
      ),
    );
  }
}
