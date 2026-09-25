// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clip_collection_detail_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 切片合集详情：加载合集元信息 + 全量切片，支持移除、删除本体。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全。
///
/// removeClip / deleteClip 两处都用 [withOptimisticPatch]（本地立即变
/// → await API → 失败整体回滚）。两处共用 [_mutationKey]，保证同一合集同时只
/// 执行一个 mutation。
///
/// removeClip 返回 `Future<String?>`（成功 null / 失败错误文案）；
/// deleteClip 则将异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。

@ProviderFor(ClipCollectionDetail)
final clipCollectionDetailProvider = ClipCollectionDetailFamily._();

/// 切片合集详情：加载合集元信息 + 全量切片，支持移除、删除本体。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全。
///
/// removeClip / deleteClip 两处都用 [withOptimisticPatch]（本地立即变
/// → await API → 失败整体回滚）。两处共用 [_mutationKey]，保证同一合集同时只
/// 执行一个 mutation。
///
/// removeClip 返回 `Future<String?>`（成功 null / 失败错误文案）；
/// deleteClip 则将异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。
final class ClipCollectionDetailProvider
    extends
        $AsyncNotifierProvider<
          ClipCollectionDetail,
          ClipCollectionDetailState
        > {
  /// 切片合集详情：加载合集元信息 + 全量切片，支持移除、删除本体。
  ///
  /// 合集切片量通常不大，这里一次性把所有分页拉全。
  ///
  /// removeClip / deleteClip 两处都用 [withOptimisticPatch]（本地立即变
  /// → await API → 失败整体回滚）。两处共用 [_mutationKey]，保证同一合集同时只
  /// 执行一个 mutation。
  ///
  /// removeClip 返回 `Future<String?>`（成功 null / 失败错误文案）；
  /// deleteClip 则将异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
  ///
  /// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。
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
    r'8760162c1bf470e1c88e21dbbdbe780e99ff2d1c';

/// 切片合集详情：加载合集元信息 + 全量切片，支持移除、删除本体。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全。
///
/// removeClip / deleteClip 两处都用 [withOptimisticPatch]（本地立即变
/// → await API → 失败整体回滚）。两处共用 [_mutationKey]，保证同一合集同时只
/// 执行一个 mutation。
///
/// removeClip 返回 `Future<String?>`（成功 null / 失败错误文案）；
/// deleteClip 则将异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。

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

  /// 切片合集详情：加载合集元信息 + 全量切片，支持移除、删除本体。
  ///
  /// 合集切片量通常不大，这里一次性把所有分页拉全。
  ///
  /// removeClip / deleteClip 两处都用 [withOptimisticPatch]（本地立即变
  /// → await API → 失败整体回滚）。两处共用 [_mutationKey]，保证同一合集同时只
  /// 执行一个 mutation。
  ///
  /// removeClip 返回 `Future<String?>`（成功 null / 失败错误文案）；
  /// deleteClip 则将异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
  ///
  /// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。

  ClipCollectionDetailProvider call(int collectionId) =>
      ClipCollectionDetailProvider._(argument: collectionId, from: this);

  @override
  String toString() => r'clipCollectionDetailProvider';
}

/// 切片合集详情：加载合集元信息 + 全量切片，支持移除、删除本体。
///
/// 合集切片量通常不大，这里一次性把所有分页拉全。
///
/// removeClip / deleteClip 两处都用 [withOptimisticPatch]（本地立即变
/// → await API → 失败整体回滚）。两处共用 [_mutationKey]，保证同一合集同时只
/// 执行一个 mutation。
///
/// removeClip 返回 `Future<String?>`（成功 null / 失败错误文案）；
/// deleteClip 则将异常交给确认弹层处理，以便请求中保持确认按钮的 loading 状态。
///
/// family(collectionId) + autoDispose：每合集独立实例，离开页面即释放。

abstract class _$ClipCollectionDetail
    extends $AsyncNotifier<ClipCollectionDetailState> {
  late final _$args = ref.$arg as int;
  int get collectionId => _$args;

  FutureOr<ClipCollectionDetailState> build(int collectionId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
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
    return element.handleCreate(ref, () => build(_$args));
  }
}
