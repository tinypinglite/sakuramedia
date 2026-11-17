// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'videos_api_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// videos 域三个 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

@ProviderFor(videosApi)
final videosApiProvider = VideosApiProvider._();

/// videos 域三个 API 的 Riverpod 入口。
///
/// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
/// 测试需要替身时用 `overrideWithValue(...)`。

final class VideosApiProvider
    extends $FunctionalProvider<VideosApi, VideosApi, VideosApi>
    with $Provider<VideosApi> {
  /// videos 域三个 API 的 Riverpod 入口。
  ///
  /// 原生装配：依赖经 `ref.watch` 拉取，组合根不再 override。
  /// 测试需要替身时用 `overrideWithValue(...)`。
  VideosApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videosApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videosApiHash();

  @$internal
  @override
  $ProviderElement<VideosApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  VideosApi create(Ref ref) {
    return videosApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideosApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideosApi>(value),
    );
  }
}

String _$videosApiHash() => r'755cd06605f593061d0e61343ccec1f0617a0f6b';

@ProviderFor(videoCollectionsApi)
final videoCollectionsApiProvider = VideoCollectionsApiProvider._();

final class VideoCollectionsApiProvider
    extends
        $FunctionalProvider<
          VideoCollectionsApi,
          VideoCollectionsApi,
          VideoCollectionsApi
        >
    with $Provider<VideoCollectionsApi> {
  VideoCollectionsApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'videoCollectionsApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoCollectionsApiHash();

  @$internal
  @override
  $ProviderElement<VideoCollectionsApi> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VideoCollectionsApi create(Ref ref) {
    return videoCollectionsApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VideoCollectionsApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VideoCollectionsApi>(value),
    );
  }
}

String _$videoCollectionsApiHash() =>
    r'9810a6adbfdcc8fe2123ff4becce2a9b5323c534';
