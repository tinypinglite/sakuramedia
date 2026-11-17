// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actor_subscription_toggle_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 跨女优列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
///
/// 列表数据仍由各自的 Provider 持有；它们收到 [actorSubscriptionEventsProvider]
/// 后负责按自己的 DTO 结构就地更新订阅态。

@ProviderFor(ActorSubscriptionToggle)
final actorSubscriptionToggleProvider = ActorSubscriptionToggleProvider._();

/// 跨女优列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
///
/// 列表数据仍由各自的 Provider 持有；它们收到 [actorSubscriptionEventsProvider]
/// 后负责按自己的 DTO 结构就地更新订阅态。
final class ActorSubscriptionToggleProvider
    extends $NotifierProvider<ActorSubscriptionToggle, Set<int>> {
  /// 跨女优列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
  ///
  /// 列表数据仍由各自的 Provider 持有；它们收到 [actorSubscriptionEventsProvider]
  /// 后负责按自己的 DTO 结构就地更新订阅态。
  ActorSubscriptionToggleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'actorSubscriptionToggleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$actorSubscriptionToggleHash();

  @$internal
  @override
  ActorSubscriptionToggle create() => ActorSubscriptionToggle();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<int> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<int>>(value),
    );
  }
}

String _$actorSubscriptionToggleHash() =>
    r'f5145ea6ae1843c51ad57cd200bd6432cea14e2a';

/// 跨女优列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
///
/// 列表数据仍由各自的 Provider 持有；它们收到 [actorSubscriptionEventsProvider]
/// 后负责按自己的 DTO 结构就地更新订阅态。

abstract class _$ActorSubscriptionToggle extends $Notifier<Set<int>> {
  Set<int> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<Set<int>, Set<int>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<int>, Set<int>>,
              Set<int>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
