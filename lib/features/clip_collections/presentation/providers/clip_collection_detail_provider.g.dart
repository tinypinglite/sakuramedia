// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_collection_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 切片合集详情：加载合集元信息 + 全量有序切片，支持拖序、移除、删除本体。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全，便于本地重排后用
/// `setCollectionClips` 提交完整有序列表（后端按列表重新编号 position）。
///
/// **本仓库首个 [OptimisticPatchMixin] 业务采用者**：reorder / removeClip /
/// deleteClip 三处都用 [withOptimisticPatch]（本地立即变 → await API → 失败
/// 整体回滚）。三处共用 [_mutationKey]：保持原 controller 「同时只允许一个
/// mutation」的语义（先前 `_isMutating` bool 的等价）。
///
/// 三个 mutation 方法**保留返回 `Future<String?>`（成功 null / 失败错误文案）
/// 的 UI 兼容语义**——mixin 内核是 rethrow，本 provider 在外包 try/catch
/// 转文案，让两个 detail page 的 UI 调用点不动。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放；对齐
/// `mediaRapidUploadBatchDetail` 唯一 autoDispose family 先例。

@ProviderFor(ClipCollectionDetail)
final clipCollectionDetailProvider = ClipCollectionDetailFamily._();

/// 切片合集详情：加载合集元信息 + 全量有序切片，支持拖序、移除、删除本体。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全，便于本地重排后用
/// `setCollectionClips` 提交完整有序列表（后端按列表重新编号 position）。
///
/// **本仓库首个 [OptimisticPatchMixin] 业务采用者**：reorder / removeClip /
/// deleteClip 三处都用 [withOptimisticPatch]（本地立即变 → await API → 失败
/// 整体回滚）。三处共用 [_mutationKey]：保持原 controller 「同时只允许一个
/// mutation」的语义（先前 `_isMutating` bool 的等价）。
///
/// 三个 mutation 方法**保留返回 `Future<String?>`（成功 null / 失败错误文案）
/// 的 UI 兼容语义**——mixin 内核是 rethrow，本 provider 在外包 try/catch
/// 转文案，让两个 detail page 的 UI 调用点不动。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放；对齐
/// `mediaRapidUploadBatchDetail` 唯一 autoDispose family 先例。
final class ClipCollectionDetailProvider
    extends
        $AsyncNotifierProvider<
          ClipCollectionDetail,
          ClipCollectionDetailState
        > {
  /// 切片合集详情：加载合集元信息 + 全量有序切片，支持拖序、移除、删除本体。
  ///
  /// 合集切片量通常不大，这里一次性把所有分页拉全，便于本地重排后用
  /// `setCollectionClips` 提交完整有序列表（后端按列表重新编号 position）。
  ///
  /// **本仓库首个 [OptimisticPatchMixin] 业务采用者**：reorder / removeClip /
  /// deleteClip 三处都用 [withOptimisticPatch]（本地立即变 → await API → 失败
  /// 整体回滚）。三处共用 [_mutationKey]：保持原 controller 「同时只允许一个
  /// mutation」的语义（先前 `_isMutating` bool 的等价）。
  ///
  /// 三个 mutation 方法**保留返回 `Future<String?>`（成功 null / 失败错误文案）
  /// 的 UI 兼容语义**——mixin 内核是 rethrow，本 provider 在外包 try/catch
  /// 转文案，让两个 detail page 的 UI 调用点不动。
  ///
  /// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放；对齐
  /// `mediaRapidUploadBatchDetail` 唯一 autoDispose family 先例。
  ClipCollectionDetailProvider._({
    required ClipCollectionDetailFamily super.from,
    required int super.argument,
  }) : super(
         retry: kNoAsyncNotifierRetry,
         name: r'clipCollectionDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$clipCollectionDetailHash();

  @override
  String toString() {
    return r'clipCollectionDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ClipCollectionDetail create() => ClipCollectionDetail();

  @override
  bool operator ==(Object other) {
    return other is ClipCollectionDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$clipCollectionDetailHash() =>
    r'03816bd0223d13ef9a0afc57b72f3438d8863759';

/// 切片合集详情：加载合集元信息 + 全量有序切片，支持拖序、移除、删除本体。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全，便于本地重排后用
/// `setCollectionClips` 提交完整有序列表（后端按列表重新编号 position）。
///
/// **本仓库首个 [OptimisticPatchMixin] 业务采用者**：reorder / removeClip /
/// deleteClip 三处都用 [withOptimisticPatch]（本地立即变 → await API → 失败
/// 整体回滚）。三处共用 [_mutationKey]：保持原 controller 「同时只允许一个
/// mutation」的语义（先前 `_isMutating` bool 的等价）。
///
/// 三个 mutation 方法**保留返回 `Future<String?>`（成功 null / 失败错误文案）
/// 的 UI 兼容语义**——mixin 内核是 rethrow，本 provider 在外包 try/catch
/// 转文案，让两个 detail page 的 UI 调用点不动。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放；对齐
/// `mediaRapidUploadBatchDetail` 唯一 autoDispose family 先例。

final class ClipCollectionDetailFamily extends $Family
    with
        $ClassFamilyOverride<
          ClipCollectionDetail,
          AsyncValue<ClipCollectionDetailState>,
          ClipCollectionDetailState,
          FutureOr<ClipCollectionDetailState>,
          int
        > {
  ClipCollectionDetailFamily._()
    : super(
        retry: kNoAsyncNotifierRetry,
        name: r'clipCollectionDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// 切片合集详情：加载合集元信息 + 全量有序切片，支持拖序、移除、删除本体。
  ///
  /// 合集切片量通常不大，这里一次性把所有分页拉全，便于本地重排后用
  /// `setCollectionClips` 提交完整有序列表（后端按列表重新编号 position）。
  ///
  /// **本仓库首个 [OptimisticPatchMixin] 业务采用者**：reorder / removeClip /
  /// deleteClip 三处都用 [withOptimisticPatch]（本地立即变 → await API → 失败
  /// 整体回滚）。三处共用 [_mutationKey]：保持原 controller 「同时只允许一个
  /// mutation」的语义（先前 `_isMutating` bool 的等价）。
  ///
  /// 三个 mutation 方法**保留返回 `Future<String?>`（成功 null / 失败错误文案）
  /// 的 UI 兼容语义**——mixin 内核是 rethrow，本 provider 在外包 try/catch
  /// 转文案，让两个 detail page 的 UI 调用点不动。
  ///
  /// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放；对齐
  /// `mediaRapidUploadBatchDetail` 唯一 autoDispose family 先例。

  ClipCollectionDetailProvider call(int collectionId) =>
      ClipCollectionDetailProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'clipCollectionDetailProvider';
}

/// 切片合集详情：加载合集元信息 + 全量有序切片，支持拖序、移除、删除本体。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全，便于本地重排后用
/// `setCollectionClips` 提交完整有序列表（后端按列表重新编号 position）。
///
/// **本仓库首个 [OptimisticPatchMixin] 业务采用者**：reorder / removeClip /
/// deleteClip 三处都用 [withOptimisticPatch]（本地立即变 → await API → 失败
/// 整体回滚）。三处共用 [_mutationKey]：保持原 controller 「同时只允许一个
/// mutation」的语义（先前 `_isMutating` bool 的等价）。
///
/// 三个 mutation 方法**保留返回 `Future<String?>`（成功 null / 失败错误文案）
/// 的 UI 兼容语义**——mixin 内核是 rethrow，本 provider 在外包 try/catch
/// 转文案，让两个 detail page 的 UI 调用点不动。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放；对齐
/// `mediaRapidUploadBatchDetail` 唯一 autoDispose family 先例。

abstract class _$ClipCollectionDetail
    extends $AsyncNotifier<ClipCollectionDetailState> {
  late final _$args = ref.$arg as int;
  int get collectionId => _$args;

  FutureOr<ClipCollectionDetailState> build(int collectionId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<ClipCollectionDetailState>,
              ClipCollectionDetailState
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ClipCollectionDetailState>,
                ClipCollectionDetailState
              >,
              AsyncValue<ClipCollectionDetailState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
