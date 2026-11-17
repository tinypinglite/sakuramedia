// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_import_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// media_import 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(mediaImportApi)
final mediaImportApiProvider = MediaImportApiProvider._();

/// media_import 域 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class MediaImportApiProvider
    extends $FunctionalProvider<MediaImportApi, MediaImportApi, MediaImportApi>
    with $Provider<MediaImportApi> {
  /// media_import 域 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  MediaImportApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaImportApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaImportApiHash();

  @$internal
  @override
  $ProviderElement<MediaImportApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaImportApi create(Ref ref) {
    return mediaImportApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaImportApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaImportApi>(value),
    );
  }
}

String _$mediaImportApiHash() => r'21928311b6af6cbc218760d5d0da195d13588d77';
