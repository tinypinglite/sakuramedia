// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_subscription_toggle_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 跨影片列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
///
/// 列表数据仍由各自的 Provider 持有；它们收到 [movieSubscriptionEventsProvider]
/// 后负责按自己的 DTO 结构更新订阅态，避免把数据源耦合进展示组件。

@ProviderFor(MovieSubscriptionToggle)
final movieSubscriptionToggleProvider = MovieSubscriptionToggleProvider._();

/// 跨影片列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
///
/// 列表数据仍由各自的 Provider 持有；它们收到 [movieSubscriptionEventsProvider]
/// 后负责按自己的 DTO 结构更新订阅态，避免把数据源耦合进展示组件。
final class MovieSubscriptionToggleProvider
    extends $NotifierProvider<MovieSubscriptionToggle, Set<String>> {
  /// 跨影片列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
  ///
  /// 列表数据仍由各自的 Provider 持有；它们收到 [movieSubscriptionEventsProvider]
  /// 后负责按自己的 DTO 结构更新订阅态，避免把数据源耦合进展示组件。
  MovieSubscriptionToggleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'movieSubscriptionToggleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieSubscriptionToggleHash();

  @$internal
  @override
  MovieSubscriptionToggle create() => MovieSubscriptionToggle();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Set<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Set<String>>(value),
    );
  }
}

String _$movieSubscriptionToggleHash() =>
    r'7ee43a54eb414cc6518a400f2968a798e5f4968c';

/// 跨影片列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
///
/// 列表数据仍由各自的 Provider 持有；它们收到 [movieSubscriptionEventsProvider]
/// 后负责按自己的 DTO 结构更新订阅态，避免把数据源耦合进展示组件。

abstract class _$MovieSubscriptionToggle extends $Notifier<Set<String>> {
  Set<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<Set<String>, Set<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Set<String>, Set<String>>,
              Set<String>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
