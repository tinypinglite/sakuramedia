// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'actors_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// actors 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(actorsApi)
final actorsApiProvider = ActorsApiProvider._();

/// actors 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class ActorsApiProvider
    extends $FunctionalProvider<ActorsApi, ActorsApi, ActorsApi>
    with $Provider<ActorsApi> {
  /// actors 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  ActorsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'actorsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$actorsApiHash();

  @$internal
  @override
  $ProviderElement<ActorsApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ActorsApi create(Ref ref) {
    return actorsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActorsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActorsApi>(value),
    );
  }
}

String _$actorsApiHash() => r'965b6274ca93a4aff4a19ec324bf8fb53fd2dadf';
