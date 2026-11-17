// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'indexer_settings_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// configuration 域 IndexerSettingsApi 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(indexerSettingsApi)
final indexerSettingsApiProvider = IndexerSettingsApiProvider._();

/// configuration 域 IndexerSettingsApi 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class IndexerSettingsApiProvider
    extends
        $FunctionalProvider<
          IndexerSettingsApi,
          IndexerSettingsApi,
          IndexerSettingsApi
        >
    with $Provider<IndexerSettingsApi> {
  /// configuration 域 IndexerSettingsApi 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  IndexerSettingsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'indexerSettingsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$indexerSettingsApiHash();

  @$internal
  @override
  $ProviderElement<IndexerSettingsApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IndexerSettingsApi create(Ref ref) {
    return indexerSettingsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IndexerSettingsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IndexerSettingsApi>(value),
    );
  }
}

String _$indexerSettingsApiHash() =>
    r'be3cef1febc229652d8866264e04a7e324db9870';
