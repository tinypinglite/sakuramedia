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
/// - **重置**资源查询状态走本域 `/movie-subscriptions/search/reset`；
/// - **取消订阅**走 `MoviesApi`——后端刻意没在 `/movie-subscriptions` 下平行造写
///   端点，这里也不绕过它。
///
/// 跨页一致性：本页取消订阅后 `reportChange` / `reportBatch` 到全局
/// [MovieSubscriptionEvents]；反过来别的页面改订阅时，本页通过
/// [movieSubscriptionEventsProvider] 收到广播并**就地打补丁**（移除行 + 刷计数），
/// 不整页重拉。

@ProviderFor(MovieSubscriptionManager)
final movieSubscriptionManagerProvider = MovieSubscriptionManagerFamily._();

/// 「订阅管理」页的列表控制器。
///
/// 职责边界：
/// - **读**订阅列表走 `MovieSubscriptionsApi`（本域）；
/// - **重置**资源查询状态走本域 `/movie-subscriptions/search/reset`；
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
  /// - **重置**资源查询状态走本域 `/movie-subscriptions/search/reset`；
  /// - **取消订阅**走 `MoviesApi`——后端刻意没在 `/movie-subscriptions` 下平行造写
  ///   端点，这里也不绕过它。
  ///
  /// 跨页一致性：本页取消订阅后 `reportChange` / `reportBatch` 到全局
  /// [MovieSubscriptionEvents]；反过来别的页面改订阅时，本页通过
  /// [movieSubscriptionEventsProvider] 收到广播并**就地打补丁**（移除行 + 刷计数），
  /// 不整页重拉。
  MovieSubscriptionManagerProvider._({
    required MovieSubscriptionManagerFamily super.from,
    required MovieSubscriptionStatus? super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'movieSubscriptionManagerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$movieSubscriptionManagerHash();

  @override
  String toString() {
    return r'movieSubscriptionManagerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  MovieSubscriptionManager create() => MovieSubscriptionManager();

  @override
  bool operator ==(Object other) {
    return other is MovieSubscriptionManagerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$movieSubscriptionManagerHash() =>
    r'2fcb7a087c87805f8d2df44a38d7e29123ab4077';

/// 「订阅管理」页的列表控制器。
///
/// 职责边界：
/// - **读**订阅列表走 `MovieSubscriptionsApi`（本域）；
/// - **重置**资源查询状态走本域 `/movie-subscriptions/search/reset`；
/// - **取消订阅**走 `MoviesApi`——后端刻意没在 `/movie-subscriptions` 下平行造写
///   端点，这里也不绕过它。
///
/// 跨页一致性：本页取消订阅后 `reportChange` / `reportBatch` 到全局
/// [MovieSubscriptionEvents]；反过来别的页面改订阅时，本页通过
/// [movieSubscriptionEventsProvider] 收到广播并**就地打补丁**（移除行 + 刷计数），
/// 不整页重拉。

final class MovieSubscriptionManagerFamily extends $Family
    with
        $ClassFamilyOverride<
          MovieSubscriptionManager,
          AsyncValue<MovieSubscriptionManagerState>,
          MovieSubscriptionManagerState,
          FutureOr<MovieSubscriptionManagerState>,
          MovieSubscriptionStatus?
        > {
  MovieSubscriptionManagerFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'movieSubscriptionManagerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// 「订阅管理」页的列表控制器。
  ///
  /// 职责边界：
  /// - **读**订阅列表走 `MovieSubscriptionsApi`（本域）；
  /// - **重置**资源查询状态走本域 `/movie-subscriptions/search/reset`；
  /// - **取消订阅**走 `MoviesApi`——后端刻意没在 `/movie-subscriptions` 下平行造写
  ///   端点，这里也不绕过它。
  ///
  /// 跨页一致性：本页取消订阅后 `reportChange` / `reportBatch` 到全局
  /// [MovieSubscriptionEvents]；反过来别的页面改订阅时，本页通过
  /// [movieSubscriptionEventsProvider] 收到广播并**就地打补丁**（移除行 + 刷计数），
  /// 不整页重拉。

  MovieSubscriptionManagerProvider call(MovieSubscriptionStatus? status) =>
      MovieSubscriptionManagerProvider._(argument: status, from: this);

  @override
  String toString() => r'movieSubscriptionManagerProvider';
}

/// 「订阅管理」页的列表控制器。
///
/// 职责边界：
/// - **读**订阅列表走 `MovieSubscriptionsApi`（本域）；
/// - **重置**资源查询状态走本域 `/movie-subscriptions/search/reset`；
/// - **取消订阅**走 `MoviesApi`——后端刻意没在 `/movie-subscriptions` 下平行造写
///   端点，这里也不绕过它。
///
/// 跨页一致性：本页取消订阅后 `reportChange` / `reportBatch` 到全局
/// [MovieSubscriptionEvents]；反过来别的页面改订阅时，本页通过
/// [movieSubscriptionEventsProvider] 收到广播并**就地打补丁**（移除行 + 刷计数），
/// 不整页重拉。

abstract class _$MovieSubscriptionManager
    extends $AsyncNotifier<MovieSubscriptionManagerState> {
  late final _$args = ref.$arg as MovieSubscriptionStatus?;
  MovieSubscriptionStatus? get status => _$args;

  FutureOr<MovieSubscriptionManagerState> build(
    MovieSubscriptionStatus? status,
  );
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
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
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(MovieSubscriptionStatusSelection)
final movieSubscriptionStatusSelectionProvider =
    MovieSubscriptionStatusSelectionProvider._();

final class MovieSubscriptionStatusSelectionProvider
    extends
        $NotifierProvider<
          MovieSubscriptionStatusSelection,
          MovieSubscriptionStatus?
        > {
  MovieSubscriptionStatusSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'movieSubscriptionStatusSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieSubscriptionStatusSelectionHash();

  @$internal
  @override
  MovieSubscriptionStatusSelection create() =>
      MovieSubscriptionStatusSelection();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MovieSubscriptionStatus? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MovieSubscriptionStatus?>(value),
    );
  }
}

String _$movieSubscriptionStatusSelectionHash() =>
    r'41db4ad74ec54e1f4b046d075f6243a0d2329067';

abstract class _$MovieSubscriptionStatusSelection
    extends $Notifier<MovieSubscriptionStatus?> {
  MovieSubscriptionStatus? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<MovieSubscriptionStatus?, MovieSubscriptionStatus?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MovieSubscriptionStatus?, MovieSubscriptionStatus?>,
              MovieSubscriptionStatus?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
