import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'moment_collection_mutation_events_provider.g.dart';

/// 时刻合集跨页变更广播；监听方重新读取合集摘要以同步数量和封面。
@Riverpod(keepAlive: true)
class MomentCollectionMutationEvents extends _$MomentCollectionMutationEvents {
  final StreamController<int> _controller = StreamController<int>.broadcast(
    sync: true,
  );

  @override
  Stream<int> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  void reportChanged(int collectionId) {
    if (_controller.isClosed) return;
    _controller.add(collectionId);
  }
}
