import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'media_tag_assignment_events_provider.g.dart';

/// 媒体文件标签指派发生变更的广播。
///
/// 载荷刻意为空：当前唯一的消费方（影片列表）只关心「有变更」这件事，
/// 收到后整体暖刷新；真要做按影片定向刷新时再往这里补字段。
class MediaTagAssignmentChange {
  const MediaTagAssignmentChange();
}

@Riverpod(keepAlive: true)
class MediaTagAssignmentEvents extends _$MediaTagAssignmentEvents {
  final StreamController<MediaTagAssignmentChange> _controller =
      StreamController<MediaTagAssignmentChange>.broadcast(sync: true);

  @override
  Stream<MediaTagAssignmentChange> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  void reportChange(MediaTagAssignmentChange change) {
    if (_controller.isClosed) return;
    _controller.add(change);
  }
}
