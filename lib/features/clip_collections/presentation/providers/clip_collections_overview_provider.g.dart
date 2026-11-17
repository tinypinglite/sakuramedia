// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_collections_overview_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 切片合集列表（一次性拉全，后端 `/clip-collections` 不分页）。
///
/// 迁移前对应：`ClipCollectionsOverviewController`。补丁方法 [insertCollection]
/// / [replaceCollection] / [removeCollection] 保留：外部动作成功后调用即可就地
/// 打补丁，不整页 invalidate 重拉。
///
/// autoDispose：离开页面即释放。

@ProviderFor(ClipCollectionsOverview)
final clipCollectionsOverviewProvider = ClipCollectionsOverviewProvider._();

/// 切片合集列表（一次性拉全，后端 `/clip-collections` 不分页）。
///
/// 迁移前对应：`ClipCollectionsOverviewController`。补丁方法 [insertCollection]
/// / [replaceCollection] / [removeCollection] 保留：外部动作成功后调用即可就地
/// 打补丁，不整页 invalidate 重拉。
///
/// autoDispose：离开页面即释放。
final class ClipCollectionsOverviewProvider
    extends
        $AsyncNotifierProvider<
          ClipCollectionsOverview,
          List<ClipCollectionDto>
        > {
  /// 切片合集列表（一次性拉全，后端 `/clip-collections` 不分页）。
  ///
  /// 迁移前对应：`ClipCollectionsOverviewController`。补丁方法 [insertCollection]
  /// / [replaceCollection] / [removeCollection] 保留：外部动作成功后调用即可就地
  /// 打补丁，不整页 invalidate 重拉。
  ///
  /// autoDispose：离开页面即释放。
  ClipCollectionsOverviewProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'clipCollectionsOverviewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipCollectionsOverviewHash();

  @$internal
  @override
  ClipCollectionsOverview create() => ClipCollectionsOverview();
}

String _$clipCollectionsOverviewHash() =>
    r'75e9a76ef52d8ef88bec0fac656b851fc0d6bc1c';

/// 切片合集列表（一次性拉全，后端 `/clip-collections` 不分页）。
///
/// 迁移前对应：`ClipCollectionsOverviewController`。补丁方法 [insertCollection]
/// / [replaceCollection] / [removeCollection] 保留：外部动作成功后调用即可就地
/// 打补丁，不整页 invalidate 重拉。
///
/// autoDispose：离开页面即释放。

abstract class _$ClipCollectionsOverview
    extends $AsyncNotifier<List<ClipCollectionDto>> {
  FutureOr<List<ClipCollectionDto>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<ClipCollectionDto>>,
              List<ClipCollectionDto>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ClipCollectionDto>>,
                List<ClipCollectionDto>
              >,
              AsyncValue<List<ClipCollectionDto>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
