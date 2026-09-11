// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_collection_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 视频合集详情：加载合集元信息 + 全量有序成员，支持排序、乐观重排与移除。
///
/// **本仓库第二个 [OptimisticPatchMixin] 采用者**（首个：clip_collection_detail）：
/// reorder / removeItem / deleteVideo 三处都用 [withOptimisticPatch]，共用
/// [_mutationKey] 让「同时只允许一个 mutation」（等价原 controller `_isMutating`
/// bool）。reorder **返回 `Future<void>`**（原 controller 语义）——失败静默回滚，
/// UI 无 toast；removeItem 返回 `Future<String?>` 供调用点直接展示失败文案；
/// deleteVideo 则把异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
///
/// [applySort] 走独立的「保留旧列表 → 拉新排序 → 覆盖」路径，不占 [_mutationKey]，
/// 与批 2 的筛选切换视觉策略一致（现有 controller 也是这么做的：`applySort` 期间
/// items 保留、失败仍保留原列表并写 errorMessage）。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。

@ProviderFor(VideoCollectionDetail)
final videoCollectionDetailProvider = VideoCollectionDetailFamily._();

/// 视频合集详情：加载合集元信息 + 全量有序成员，支持排序、乐观重排与移除。
///
/// **本仓库第二个 [OptimisticPatchMixin] 采用者**（首个：clip_collection_detail）：
/// reorder / removeItem / deleteVideo 三处都用 [withOptimisticPatch]，共用
/// [_mutationKey] 让「同时只允许一个 mutation」（等价原 controller `_isMutating`
/// bool）。reorder **返回 `Future<void>`**（原 controller 语义）——失败静默回滚，
/// UI 无 toast；removeItem 返回 `Future<String?>` 供调用点直接展示失败文案；
/// deleteVideo 则把异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
///
/// [applySort] 走独立的「保留旧列表 → 拉新排序 → 覆盖」路径，不占 [_mutationKey]，
/// 与批 2 的筛选切换视觉策略一致（现有 controller 也是这么做的：`applySort` 期间
/// items 保留、失败仍保留原列表并写 errorMessage）。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。
final class VideoCollectionDetailProvider
    extends
        $AsyncNotifierProvider<
          VideoCollectionDetail,
          VideoCollectionDetailState
        > {
  /// 视频合集详情：加载合集元信息 + 全量有序成员，支持排序、乐观重排与移除。
  ///
  /// **本仓库第二个 [OptimisticPatchMixin] 采用者**（首个：clip_collection_detail）：
  /// reorder / removeItem / deleteVideo 三处都用 [withOptimisticPatch]，共用
  /// [_mutationKey] 让「同时只允许一个 mutation」（等价原 controller `_isMutating`
  /// bool）。reorder **返回 `Future<void>`**（原 controller 语义）——失败静默回滚，
  /// UI 无 toast；removeItem 返回 `Future<String?>` 供调用点直接展示失败文案；
  /// deleteVideo 则把异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
  ///
  /// [applySort] 走独立的「保留旧列表 → 拉新排序 → 覆盖」路径，不占 [_mutationKey]，
  /// 与批 2 的筛选切换视觉策略一致（现有 controller 也是这么做的：`applySort` 期间
  /// items 保留、失败仍保留原列表并写 errorMessage）。
  ///
  /// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。
  VideoCollectionDetailProvider._({
    required VideoCollectionDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'videoCollectionDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$videoCollectionDetailHash();

  @override
  String toString() {
    return r'videoCollectionDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  VideoCollectionDetail create() => VideoCollectionDetail();

  @override
  bool operator ==(Object other) {
    return other is VideoCollectionDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$videoCollectionDetailHash() =>
    r'6a9e3f7c614e660446aaa0cc2ea06a863a937df2';

/// 视频合集详情：加载合集元信息 + 全量有序成员，支持排序、乐观重排与移除。
///
/// **本仓库第二个 [OptimisticPatchMixin] 采用者**（首个：clip_collection_detail）：
/// reorder / removeItem / deleteVideo 三处都用 [withOptimisticPatch]，共用
/// [_mutationKey] 让「同时只允许一个 mutation」（等价原 controller `_isMutating`
/// bool）。reorder **返回 `Future<void>`**（原 controller 语义）——失败静默回滚，
/// UI 无 toast；removeItem 返回 `Future<String?>` 供调用点直接展示失败文案；
/// deleteVideo 则把异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
///
/// [applySort] 走独立的「保留旧列表 → 拉新排序 → 覆盖」路径，不占 [_mutationKey]，
/// 与批 2 的筛选切换视觉策略一致（现有 controller 也是这么做的：`applySort` 期间
/// items 保留、失败仍保留原列表并写 errorMessage）。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。

final class VideoCollectionDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          VideoCollectionDetail,
          AsyncValue<VideoCollectionDetailState>,
          VideoCollectionDetailState,
          FutureOr<VideoCollectionDetailState>,
          int
        > {
  VideoCollectionDetailFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'videoCollectionDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 视频合集详情：加载合集元信息 + 全量有序成员，支持排序、乐观重排与移除。
  ///
  /// **本仓库第二个 [OptimisticPatchMixin] 采用者**（首个：clip_collection_detail）：
  /// reorder / removeItem / deleteVideo 三处都用 [withOptimisticPatch]，共用
  /// [_mutationKey] 让「同时只允许一个 mutation」（等价原 controller `_isMutating`
  /// bool）。reorder **返回 `Future<void>`**（原 controller 语义）——失败静默回滚，
  /// UI 无 toast；removeItem 返回 `Future<String?>` 供调用点直接展示失败文案；
  /// deleteVideo 则把异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
  ///
  /// [applySort] 走独立的「保留旧列表 → 拉新排序 → 覆盖」路径，不占 [_mutationKey]，
  /// 与批 2 的筛选切换视觉策略一致（现有 controller 也是这么做的：`applySort` 期间
  /// items 保留、失败仍保留原列表并写 errorMessage）。
  ///
  /// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。

  VideoCollectionDetailProvider call(int collectionId) =>
      VideoCollectionDetailProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'videoCollectionDetailProvider';
}

/// 视频合集详情：加载合集元信息 + 全量有序成员，支持排序、乐观重排与移除。
///
/// **本仓库第二个 [OptimisticPatchMixin] 采用者**（首个：clip_collection_detail）：
/// reorder / removeItem / deleteVideo 三处都用 [withOptimisticPatch]，共用
/// [_mutationKey] 让「同时只允许一个 mutation」（等价原 controller `_isMutating`
/// bool）。reorder **返回 `Future<void>`**（原 controller 语义）——失败静默回滚，
/// UI 无 toast；removeItem 返回 `Future<String?>` 供调用点直接展示失败文案；
/// deleteVideo 则把异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
///
/// [applySort] 走独立的「保留旧列表 → 拉新排序 → 覆盖」路径，不占 [_mutationKey]，
/// 与批 2 的筛选切换视觉策略一致（现有 controller 也是这么做的：`applySort` 期间
/// items 保留、失败仍保留原列表并写 errorMessage）。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。

abstract class _$VideoCollectionDetail
    extends $AsyncNotifier<VideoCollectionDetailState> {
  late final _$args = ref.$arg as int;
  int get collectionId => _$args;

  FutureOr<VideoCollectionDetailState> build(int collectionId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<VideoCollectionDetailState>,
              VideoCollectionDetailState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<VideoCollectionDetailState>,
                VideoCollectionDetailState
              >,
              AsyncValue<VideoCollectionDetailState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
