// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hot_reviews_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 热评分页列表（周期筛选驱动,`FilterablePagedAsyncNotifierMixin` 首个采用者）。
///
/// - 切周期先更新条件并保留旧列表，防抖请求成功后再替换结果。
/// - autoDispose:离开页面即释放,对齐迁移前控制器随页面 State 生灭。
///
/// 迁移前对应:`PagedHotReviewController`(含「占位 fetchPage 抛
/// UnimplementedError 再 override」的注入 hack,mixin 的 [activeFilter]
/// 使该 hack 自然消失)。

@ProviderFor(HotReviews)
final hotReviewsProvider = HotReviewsProvider._();

/// 热评分页列表（周期筛选驱动,`FilterablePagedAsyncNotifierMixin` 首个采用者）。
///
/// - 切周期先更新条件并保留旧列表，防抖请求成功后再替换结果。
/// - autoDispose:离开页面即释放,对齐迁移前控制器随页面 State 生灭。
///
/// 迁移前对应:`PagedHotReviewController`(含「占位 fetchPage 抛
/// UnimplementedError 再 override」的注入 hack,mixin 的 [activeFilter]
/// 使该 hack 自然消失)。
final class HotReviewsProvider
    extends $AsyncNotifierProvider<HotReviews, HotReviewsState> {
  /// 热评分页列表（周期筛选驱动,`FilterablePagedAsyncNotifierMixin` 首个采用者）。
  ///
  /// - 切周期先更新条件并保留旧列表，防抖请求成功后再替换结果。
  /// - autoDispose:离开页面即释放,对齐迁移前控制器随页面 State 生灭。
  ///
  /// 迁移前对应:`PagedHotReviewController`(含「占位 fetchPage 抛
  /// UnimplementedError 再 override」的注入 hack,mixin 的 [activeFilter]
  /// 使该 hack 自然消失)。
  HotReviewsProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'hotReviewsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hotReviewsHash();

  @$internal
  @override
  HotReviews create() => HotReviews();
}

String _$hotReviewsHash() => r'fc69e6d152b0146912498f2b5236057f2c10517f';

/// 热评分页列表（周期筛选驱动,`FilterablePagedAsyncNotifierMixin` 首个采用者）。
///
/// - 切周期先更新条件并保留旧列表，防抖请求成功后再替换结果。
/// - autoDispose:离开页面即释放,对齐迁移前控制器随页面 State 生灭。
///
/// 迁移前对应:`PagedHotReviewController`(含「占位 fetchPage 抛
/// UnimplementedError 再 override」的注入 hack,mixin 的 [activeFilter]
/// 使该 hack 自然消失)。

abstract class _$HotReviews extends $AsyncNotifier<HotReviewsState> {
  FutureOr<HotReviewsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<HotReviewsState>, HotReviewsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<HotReviewsState>, HotReviewsState>,
              AsyncValue<HotReviewsState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
