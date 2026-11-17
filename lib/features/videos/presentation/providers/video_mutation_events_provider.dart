import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/notifiers/video_mutation_change.dart';

export 'package:sakuramedia/features/videos/presentation/controllers/notifiers/video_mutation_change.dart';

part 'video_mutation_events_provider.g.dart';

/// videos 域跨页变更广播 —— 与 `clipMutationEventsProvider` 同范式。
///
/// **消费方**：`ref.listen(videoMutationEventsProvider, (prev, next) {
/// final change = next.value; if (change != null) ...; })`；就地补丁。
///
/// **发起方**：`ref.read(videoMutationEventsProvider.notifier).reportDeleted(...)`
/// 或 `reportCollectionMembershipChanged(...)`。
@Riverpod(keepAlive: true)
class VideoMutationEvents extends _$VideoMutationEvents {
  final StreamController<VideoMutationChange> _controller =
      StreamController<VideoMutationChange>.broadcast(sync: true);

  @override
  Stream<VideoMutationChange> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  void reportDeleted(int videoId) {
    if (_controller.isClosed) return;
    _controller.add(
      VideoMutationChange(kind: VideoMutationKind.deleted, videoId: videoId),
    );
  }

  void reportCollectionMembershipChanged({
    required int videoId,
    int? collectionId,
    bool removedFromCollection = false,
  }) {
    if (_controller.isClosed) return;
    _controller.add(
      VideoMutationChange(
        kind: VideoMutationKind.collectionMembershipChanged,
        videoId: videoId,
        collectionId: collectionId,
        removedFromCollection: removedFromCollection,
      ),
    );
  }

  void reportCoverChanged({required int videoId}) {
    if (_controller.isClosed) return;
    _controller.add(
      VideoMutationChange(
        kind: VideoMutationKind.coverChanged,
        videoId: videoId,
      ),
    );
  }
}
