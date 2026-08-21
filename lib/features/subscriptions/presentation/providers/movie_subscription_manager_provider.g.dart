// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_subscription_manager_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 「订阅管理」页的列表控制器。
///
/// 职责边界：
/// - **读**订阅列表走 `MovieSubscriptionsApi`（本域）；
/// - **重置**订阅搜索状态走 `MovieSubscriptionsApi`；
/// - **取消订阅**走 `MoviesApi`——后端刻意没在 `/movie-subscriptions` 下平行造写
///   端点，这里也不绕过它。
///
/// 跨页一致性：本页取消订阅后 `reportChange` / `reportBatch` 到全局
/// [MovieSubscriptionEvents]；反过来别的页面改订阅时，本页通过
/// [movieSubscriptionEventsProvider] 收到广播并**就地打补丁**（移除行 + 刷计数），
/// 不整页重拉。

@ProviderFor(MovieSubscriptionManager)
final movieSubscriptionManagerProvider = MovieSubscriptionManagerProvider._();

/// 「订阅管理」页的列表控制器。
///
/// 职责边界：
/// - **读**订阅列表走 `MovieSubscriptionsApi`（本域）；
/// - **重置**订阅搜索状态走 `MovieSubscriptionsApi`；
/// - **取消订阅**走 `MoviesApi`——后端刻意没在 `/movie-subscriptions` 下平行造写
///   端点，这里也不绕过它。
///
/// 跨页一致性：本页取消订阅后 `reportChange` / `reportBatch` 到全局
/// [MovieSubscriptionEvents]；反过来别的页面改订阅时，本页通过
/// [movieSubscriptionEventsProvider] 收到广播并**就地打补丁**（移除行 + 刷计数），
/// 不整页重拉。
final class MovieSubscriptionManagerProvider
    extends
        $AsyncNotifierProvider<
          MovieSubscriptionManager,
          MovieSubscriptionManagerState
        > {
  /// 「订阅管理」页的列表控制器。
  ///
  /// 职责边界：
  /// - **读**订阅列表走 `MovieSubscriptionsApi`（本域）；
  /// - **重置**订阅搜索状态走 `MovieSubscriptionsApi`；
  /// - **取消订阅**走 `MoviesApi`——后端刻意没在 `/movie-subscriptions` 下平行造写
  ///   端点，这里也不绕过它。
  ///
  /// 跨页一致性：本页取消订阅后 `reportChange` / `reportBatch` 到全局
  /// [MovieSubscriptionEvents]；反过来别的页面改订阅时，本页通过
  /// [movieSubscriptionEventsProvider] 收到广播并**就地打补丁**（移除行 + 刷计数），
  /// 不整页重拉。
  MovieSubscriptionManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'movieSubscriptionManagerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieSubscriptionManagerHash();

  @$internal
  @override
  MovieSubscriptionManager create() => MovieSubscriptionManager();
}

String _$movieSubscriptionManagerHash() =>
    r'6ecae4df2cf226c39b40990f41e5667a9851bb5a';

/// 「订阅管理」页的列表控制器。
///
/// 职责边界：
/// - **读**订阅列表走 `MovieSubscriptionsApi`（本域）；
/// - **重置**订阅搜索状态走 `MovieSubscriptionsApi`；
/// - **取消订阅**走 `MoviesApi`——后端刻意没在 `/movie-subscriptions` 下平行造写
///   端点，这里也不绕过它。
///
/// 跨页一致性：本页取消订阅后 `reportChange` / `reportBatch` 到全局
/// [MovieSubscriptionEvents]；反过来别的页面改订阅时，本页通过
/// [movieSubscriptionEventsProvider] 收到广播并**就地打补丁**（移除行 + 刷计数），
/// 不整页重拉。

abstract class _$MovieSubscriptionManager
    extends $AsyncNotifier<MovieSubscriptionManagerState> {
  FutureOr<MovieSubscriptionManagerState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<MovieSubscriptionManagerState>,
              MovieSubscriptionManagerState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<MovieSubscriptionManagerState>,
                MovieSubscriptionManagerState
              >,
              AsyncValue<MovieSubscriptionManagerState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
