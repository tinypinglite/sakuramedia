// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_collections_overview_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 视频合集列表（一次性拉全，后端 `/video-collections` 不分页）。
///
/// 迁移前对应：`VideoCollectionsOverviewController`（仅 load / refresh 两方法）。
/// 与切片合集不同，本 provider **无 insert / replace / remove 补丁方法**——
/// 现有 UI 在新建 / 编辑 / 删除后都是 `await refresh()` 走整拉重刷（合集列表小，
/// 且服务端计算封面 / 计数，本地补丁不划算）。
///
/// autoDispose：离开页面即释放。

@ProviderFor(VideoCollectionsOverview)
final videoCollectionsOverviewProvider = VideoCollectionsOverviewProvider._();

/// 视频合集列表（一次性拉全，后端 `/video-collections` 不分页）。
///
/// 迁移前对应：`VideoCollectionsOverviewController`（仅 load / refresh 两方法）。
/// 与切片合集不同，本 provider **无 insert / replace / remove 补丁方法**——
/// 现有 UI 在新建 / 编辑 / 删除后都是 `await refresh()` 走整拉重刷（合集列表小，
/// 且服务端计算封面 / 计数，本地补丁不划算）。
///
/// autoDispose：离开页面即释放。
final class VideoCollectionsOverviewProvider
    extends
        $AsyncNotifierProvider<
          VideoCollectionsOverview,
          List<VideoCollectionDto>
        > {
  /// 视频合集列表（一次性拉全，后端 `/video-collections` 不分页）。
  ///
  /// 迁移前对应：`VideoCollectionsOverviewController`（仅 load / refresh 两方法）。
  /// 与切片合集不同，本 provider **无 insert / replace / remove 补丁方法**——
  /// 现有 UI 在新建 / 编辑 / 删除后都是 `await refresh()` 走整拉重刷（合集列表小，
  /// 且服务端计算封面 / 计数，本地补丁不划算）。
  ///
  /// autoDispose：离开页面即释放。
  VideoCollectionsOverviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'videoCollectionsOverviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$videoCollectionsOverviewHash();

  @$internal
  @override
  VideoCollectionsOverview create() => VideoCollectionsOverview();
}

String _$videoCollectionsOverviewHash() =>
    r'27fe9b158356d9e68ec557ece978d37887a75d7a';

/// 视频合集列表（一次性拉全，后端 `/video-collections` 不分页）。
///
/// 迁移前对应：`VideoCollectionsOverviewController`（仅 load / refresh 两方法）。
/// 与切片合集不同，本 provider **无 insert / replace / remove 补丁方法**——
/// 现有 UI 在新建 / 编辑 / 删除后都是 `await refresh()` 走整拉重刷（合集列表小，
/// 且服务端计算封面 / 计数，本地补丁不划算）。
///
/// autoDispose：离开页面即释放。

abstract class _$VideoCollectionsOverview
    extends $AsyncNotifier<List<VideoCollectionDto>> {
  FutureOr<List<VideoCollectionDto>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<VideoCollectionDto>>,
              List<VideoCollectionDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<VideoCollectionDto>>,
                List<VideoCollectionDto>
              >,
              AsyncValue<List<VideoCollectionDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
