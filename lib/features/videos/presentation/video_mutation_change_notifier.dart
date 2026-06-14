import 'package:flutter/foundation.dart';

/// 视频跨页变更的类别。
enum VideoMutationKind {
  /// 视频被删除（全局删除，影响所有展示该视频的列表）。
  deleted,

  /// 视频的合集归属发生变化（加入 / 移出合集，影响合集封面与计数）。
  collectionMembershipChanged,
}

/// 一次视频变更事件的载荷。
class VideoMutationChange {
  const VideoMutationChange({
    required this.kind,
    required this.videoId,
    this.collectionId,
  });

  final VideoMutationKind kind;
  final int videoId;

  /// 仅 [VideoMutationKind.collectionMembershipChanged] 时有意义，可能为空。
  final int? collectionId;
}

/// 视频变更的全局广播器：与 movies 的 `MovieSubscriptionChangeNotifier` 同构。
///
/// 发起方在某页改完视频后 `reportXxx(...)`，其它持有缓存副本的页面监听后读
/// [lastChange] 做精准就地补丁（如把该视频从分页列表移除），避免跨页数据 stale。
class VideoMutationChangeNotifier extends ChangeNotifier {
  VideoMutationChange? _lastChange;
  VideoMutationChange? get lastChange => _lastChange;

  void reportDeleted(int videoId) {
    _lastChange = VideoMutationChange(
      kind: VideoMutationKind.deleted,
      videoId: videoId,
    );
    notifyListeners();
  }

  void reportCollectionMembershipChanged({
    required int videoId,
    int? collectionId,
  }) {
    _lastChange = VideoMutationChange(
      kind: VideoMutationKind.collectionMembershipChanged,
      videoId: videoId,
      collectionId: collectionId,
    );
    notifyListeners();
  }
}
