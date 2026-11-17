// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor_subscription_events_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 跨页女优订阅变更广播 —— 与影片侧 `movieSubscriptionEventsProvider` 同范式。
///
/// **发起方**：`ref.read(actorSubscriptionEventsProvider.notifier).reportChange(...)`。
/// **消费方**：`ref.listen(...)` 后就地补丁，不整页重拉。

@ProviderFor(ActorSubscriptionEvents)
final actorSubscriptionEventsProvider = ActorSubscriptionEventsProvider._();

/// 跨页女优订阅变更广播 —— 与影片侧 `movieSubscriptionEventsProvider` 同范式。
///
/// **发起方**：`ref.read(actorSubscriptionEventsProvider.notifier).reportChange(...)`。
/// **消费方**：`ref.listen(...)` 后就地补丁，不整页重拉。
final class ActorSubscriptionEventsProvider
    extends
        $StreamNotifierProvider<
          ActorSubscriptionEvents,
          ActorSubscriptionChange
        > {
  /// 跨页女优订阅变更广播 —— 与影片侧 `movieSubscriptionEventsProvider` 同范式。
  ///
  /// **发起方**：`ref.read(actorSubscriptionEventsProvider.notifier).reportChange(...)`。
  /// **消费方**：`ref.listen(...)` 后就地补丁，不整页重拉。
  ActorSubscriptionEventsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'actorSubscriptionEventsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$actorSubscriptionEventsHash();

  @$internal
  @override
  ActorSubscriptionEvents create() => ActorSubscriptionEvents();
}

String _$actorSubscriptionEventsHash() =>
    r'3f07d3da4604484a785b92013d1e9e50a942236b';

/// 跨页女优订阅变更广播 —— 与影片侧 `movieSubscriptionEventsProvider` 同范式。
///
/// **发起方**：`ref.read(actorSubscriptionEventsProvider.notifier).reportChange(...)`。
/// **消费方**：`ref.listen(...)` 后就地补丁，不整页重拉。

abstract class _$ActorSubscriptionEvents
    extends $StreamNotifier<ActorSubscriptionChange> {
  Stream<ActorSubscriptionChange> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<ActorSubscriptionChange>,
              ActorSubscriptionChange
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ActorSubscriptionChange>,
                ActorSubscriptionChange
              >,
              AsyncValue<ActorSubscriptionChange>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
