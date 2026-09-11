import 'package:flutter/foundation.dart';

/// 视频跨页变更的类别。
enum VideoMutationKind {
  /// 视频被删除（全局删除，影响所有展示该视频的列表）。
  deleted,

  /// 视频的合集归属发生变化（加入 / 移出合集，影响合集封面与计数）。
  collectionMembershipChanged,

  /// 视频封面发生变化。
  coverChanged,
}

/// 一次视频变更事件的载荷。
@immutable
class VideoMutationChange {
  const VideoMutationChange({
    required this.kind,
    required this.videoId,
    this.collectionId,
    this.removedFromCollection = false,
  });

  final VideoMutationKind kind;
  final int videoId;

  /// 仅 [VideoMutationKind.collectionMembershipChanged] 时有意义，可能为空。
  final int? collectionId;
  final bool removedFromCollection;
}
