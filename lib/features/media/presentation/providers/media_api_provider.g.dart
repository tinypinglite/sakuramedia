// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// media feature 内所有 Riverpod Notifier 读 API 的统一入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(mediaApi)
final mediaApiProvider = MediaApiProvider._();

/// media feature 内所有 Riverpod Notifier 读 API 的统一入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class MediaApiProvider
    extends $FunctionalProvider<MediaApi, MediaApi, MediaApi>
    with $Provider<MediaApi> {
  /// media feature 内所有 Riverpod Notifier 读 API 的统一入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  MediaApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaApiHash();

  @$internal
  @override
  $ProviderElement<MediaApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MediaApi create(Ref ref) {
    return mediaApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaApi>(value),
    );
  }
}

String _$mediaApiHash() => r'7f047ba1ec647f0cbb74ace57db563dedb08b937';

/// media 页需要读媒体库列表（用于筛选、秒传目标选择、存储描述解析）。
///
/// `MediaLibrariesApi` 归属 configuration 域；configuration 迁移完成后该
/// bridge 仍保持现状（configuration 页面、media、system_diagnostics、
/// media_import 选择器等多处共用，原生装配无副作用）。

@ProviderFor(mediaLibrariesApi)
final mediaLibrariesApiProvider = MediaLibrariesApiProvider._();

/// media 页需要读媒体库列表（用于筛选、秒传目标选择、存储描述解析）。
///
/// `MediaLibrariesApi` 归属 configuration 域；configuration 迁移完成后该
/// bridge 仍保持现状（configuration 页面、media、system_diagnostics、
/// media_import 选择器等多处共用，原生装配无副作用）。

final class MediaLibrariesApiProvider
    extends
        $FunctionalProvider<
          MediaLibrariesApi,
          MediaLibrariesApi,
          MediaLibrariesApi
        >
    with $Provider<MediaLibrariesApi> {
  /// media 页需要读媒体库列表（用于筛选、秒传目标选择、存储描述解析）。
  ///
  /// `MediaLibrariesApi` 归属 configuration 域；configuration 迁移完成后该
  /// bridge 仍保持现状（configuration 页面、media、system_diagnostics、
  /// media_import 选择器等多处共用，原生装配无副作用）。
  MediaLibrariesApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mediaLibrariesApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mediaLibrariesApiHash();

  @$internal
  @override
  $ProviderElement<MediaLibrariesApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MediaLibrariesApi create(Ref ref) {
    return mediaLibrariesApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MediaLibrariesApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MediaLibrariesApi>(value),
    );
  }
}

String _$mediaLibrariesApiHash() => r'bf3e35aae513b857caf5201a233acdffe2a44782';
