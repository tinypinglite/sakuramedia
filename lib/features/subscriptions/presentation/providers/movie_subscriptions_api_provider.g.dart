// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie_subscriptions_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 订阅管理 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(movieSubscriptionsApi)
final movieSubscriptionsApiProvider = MovieSubscriptionsApiProvider._();

/// 订阅管理 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class MovieSubscriptionsApiProvider
    extends
        $FunctionalProvider<
          MovieSubscriptionsApi,
          MovieSubscriptionsApi,
          MovieSubscriptionsApi
        >
    with $Provider<MovieSubscriptionsApi> {
  /// 订阅管理 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  MovieSubscriptionsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'movieSubscriptionsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$movieSubscriptionsApiHash();

  @$internal
  @override
  $ProviderElement<MovieSubscriptionsApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MovieSubscriptionsApi create(Ref ref) {
    return movieSubscriptionsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MovieSubscriptionsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MovieSubscriptionsApi>(value),
    );
  }
}

String _$movieSubscriptionsApiHash() =>
    r'0561d417db658f201692b6818ae330f3b3e7a468';
