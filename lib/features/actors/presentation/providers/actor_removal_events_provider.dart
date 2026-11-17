import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'actor_removal_events_provider.g.dart';

/// 女优合并后跨页移除广播：通知列表把被合并掉的卡片摘掉。
@Riverpod(keepAlive: true)
class ActorRemovalEvents extends _$ActorRemovalEvents {
  final StreamController<List<int>> _controller =
      StreamController<List<int>>.broadcast(sync: true);

  @override
  Stream<List<int>> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  void reportRemoved(List<int> actorIds) {
    if (_controller.isClosed || actorIds.isEmpty) return;
    _controller.add(List<int>.unmodifiable(actorIds));
  }
}
