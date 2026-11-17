// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movies_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// movies 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(moviesApi)
final moviesApiProvider = MoviesApiProvider._();

/// movies 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class MoviesApiProvider
    extends $FunctionalProvider<MoviesApi, MoviesApi, MoviesApi>
    with $Provider<MoviesApi> {
  /// movies 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  MoviesApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'moviesApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$moviesApiHash();

  @$internal
  @override
  $ProviderElement<MoviesApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MoviesApi create(Ref ref) {
    return moviesApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MoviesApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MoviesApi>(value),
    );
  }
}

String _$moviesApiHash() => r'54ada3bfca743ba71f6ac4991096132a529985e9';
