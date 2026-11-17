// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moments_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 时刻分页列表（排序 + 内容类型双维筛选,值对象 [MomentsFilter] 驱动）。
///
/// - 切筛选先更新条件并保留旧列表，防抖请求成功后再替换结果。
/// - autoDispose:离开页面即释放,对齐迁移前控制器随页面 State 生灭。
/// - `fetchPage` 保留 `MediaPointListItemDto → MomentListItem` 的 ViewModel
///   映射（迁移前在控制器 override 里做）。
///
/// 迁移前对应:`PagedMomentController`。

@ProviderFor(Moments)
final momentsProvider = MomentsProvider._();

/// 时刻分页列表（排序 + 内容类型双维筛选,值对象 [MomentsFilter] 驱动）。
///
/// - 切筛选先更新条件并保留旧列表，防抖请求成功后再替换结果。
/// - autoDispose:离开页面即释放,对齐迁移前控制器随页面 State 生灭。
/// - `fetchPage` 保留 `MediaPointListItemDto → MomentListItem` 的 ViewModel
///   映射（迁移前在控制器 override 里做）。
///
/// 迁移前对应:`PagedMomentController`。
final class MomentsProvider
    extends $AsyncNotifierProvider<Moments, MomentsState> {
  /// 时刻分页列表（排序 + 内容类型双维筛选,值对象 [MomentsFilter] 驱动）。
  ///
  /// - 切筛选先更新条件并保留旧列表，防抖请求成功后再替换结果。
  /// - autoDispose:离开页面即释放,对齐迁移前控制器随页面 State 生灭。
  /// - `fetchPage` 保留 `MediaPointListItemDto → MomentListItem` 的 ViewModel
  ///   映射（迁移前在控制器 override 里做）。
  ///
  /// 迁移前对应:`PagedMomentController`。
  MomentsProvider._()
    : super(
        from: null,
        argument: null,
        retry: kNoAsyncNotifierRetry,
        name: r'momentsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$momentsHash();

  @$internal
  @override
  Moments create() => Moments();
}

String _$momentsHash() => r'22b3df865280597ac45e713f519ebd800a342cfe';

/// 时刻分页列表（排序 + 内容类型双维筛选,值对象 [MomentsFilter] 驱动）。
///
/// - 切筛选先更新条件并保留旧列表，防抖请求成功后再替换结果。
/// - autoDispose:离开页面即释放,对齐迁移前控制器随页面 State 生灭。
/// - `fetchPage` 保留 `MediaPointListItemDto → MomentListItem` 的 ViewModel
///   映射（迁移前在控制器 override 里做）。
///
/// 迁移前对应:`PagedMomentController`。

abstract class _$Moments extends $AsyncNotifier<MomentsState> {
  FutureOr<MomentsState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<MomentsState>, MomentsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MomentsState>, MomentsState>,
              AsyncValue<MomentsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
