import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'actor_subscription_events_provider.g.dart';

/// 女优订阅变更记录：由单片切换动作广播，供已加载列表就地补丁。
class ActorSubscriptionChange {
  const ActorSubscriptionChange({
    required this.actorId,
    required this.isSubscribed,
  });

  final int actorId;
  final bool isSubscribed;
}

/// 跨页女优订阅变更广播 —— 与影片侧 `movieSubscriptionEventsProvider` 同范式。
///
/// **发起方**：`ref.read(actorSubscriptionEventsProvider.notifier).reportChange(...)`。
/// **消费方**：`ref.listen(...)` 后就地补丁，不整页重拉。
@Riverpod(keepAlive: true)
class ActorSubscriptionEvents extends _$ActorSubscriptionEvents {
  final StreamController<ActorSubscriptionChange> _controller =
      StreamController<ActorSubscriptionChange>.broadcast(sync: true);

  @override
  Stream<ActorSubscriptionChange> build() {
    ref.onDispose(_controller.close);
    return _controller.stream;
  }

  void reportChange({required int actorId, required bool isSubscribed}) {
    if (_controller.isClosed) return;
    _controller.add(
      ActorSubscriptionChange(actorId: actorId, isSubscribed: isSubscribed),
    );
  }
}
