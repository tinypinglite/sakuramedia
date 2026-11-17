import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// 挂一个沉默监听者，阻止流式事件 provider 被 Riverpod pause。
///
/// 无监听者时入站流 pause 是特性（底层 `StreamSubscription.pause()`，事件缓冲、
/// 恢复监听才补投）——但测试里通常会因此**静默丢事件**、误判成 bug。想复现
/// 「页面在场」时给事件 provider 挂监听者就用这个（或直接 `container.listen`）。
///
/// 例：
/// ```dart
/// keepEventsProviderAlive(container, movieSubscriptionEventsProvider);
/// ```
void keepEventsProviderAlive<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> events,
) {
  container.listen(events, (_, __) {});
}
