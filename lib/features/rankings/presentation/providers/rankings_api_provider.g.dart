// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rankings_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// rankings 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(rankingsApi)
final rankingsApiProvider = RankingsApiProvider._();

/// rankings 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class RankingsApiProvider
    extends $FunctionalProvider<RankingsApi, RankingsApi, RankingsApi>
    with $Provider<RankingsApi> {
  /// rankings 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  RankingsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rankingsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rankingsApiHash();

  @$internal
  @override
  $ProviderElement<RankingsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RankingsApi create(Ref ref) {
    return rankingsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RankingsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RankingsApi>(value),
    );
  }
}

String _$rankingsApiHash() => r'35dd80ec4a0695e13c97414e9a5ef7c796285004';
