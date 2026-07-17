// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// media feature 内所有 Riverpod Notifier 读 API 的统一入口。
///
/// body 抛 [UnimplementedError]，实际实例由 `lib/app/app.dart` 的组合根
/// 用 `overrideWithValue(context.read<MediaApi>())` 注入（R2 过渡期方案：
/// legacy MultiProvider 里的 `MediaApi` 单例桥接到 Riverpod 侧）。

@ProviderFor(mediaApi)
final mediaApiProvider = MediaApiProvider._();

/// media feature 内所有 Riverpod Notifier 读 API 的统一入口。
///
/// body 抛 [UnimplementedError]，实际实例由 `lib/app/app.dart` 的组合根
/// 用 `overrideWithValue(context.read<MediaApi>())` 注入（R2 过渡期方案：
/// legacy MultiProvider 里的 `MediaApi` 单例桥接到 Riverpod 侧）。

final class MediaApiProvider
    extends $FunctionalProvider<MediaApi, MediaApi, MediaApi>
    with $Provider<MediaApi> {
  /// media feature 内所有 Riverpod Notifier 读 API 的统一入口。
  ///
  /// body 抛 [UnimplementedError]，实际实例由 `lib/app/app.dart` 的组合根
  /// 用 `overrideWithValue(context.read<MediaApi>())` 注入（R2 过渡期方案：
  /// legacy MultiProvider 里的 `MediaApi` 单例桥接到 Riverpod 侧）。
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

String _$mediaApiHash() => r'0b16b6d6f36c9d6d228e68d62f01b428e075acfb';

/// media 页需要读媒体库列表（用于筛选、秒传目标选择、存储描述解析）。
///
/// `MediaLibrariesApi` 归属 configuration 域，但目前该域尚未开始 R2 迁移；
/// 先在 media 侧建 bridge，供 [mediaLibrariesProvider] 消费。等 configuration
/// 迁 Riverpod 时把 bridge 上移到 configuration/presentation/providers/。

@ProviderFor(mediaLibrariesApi)
final mediaLibrariesApiProvider = MediaLibrariesApiProvider._();

/// media 页需要读媒体库列表（用于筛选、秒传目标选择、存储描述解析）。
///
/// `MediaLibrariesApi` 归属 configuration 域，但目前该域尚未开始 R2 迁移；
/// 先在 media 侧建 bridge，供 [mediaLibrariesProvider] 消费。等 configuration
/// 迁 Riverpod 时把 bridge 上移到 configuration/presentation/providers/。

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
  /// `MediaLibrariesApi` 归属 configuration 域，但目前该域尚未开始 R2 迁移；
  /// 先在 media 侧建 bridge，供 [mediaLibrariesProvider] 消费。等 configuration
  /// 迁 Riverpod 时把 bridge 上移到 configuration/presentation/providers/。
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

String _$mediaLibrariesApiHash() => r'8d4201ef7e1e05034c70c025040d9ecb972f0b3f';
