// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overview_system_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 系统概览(一次性加载 + 两个手动探针,无轮询)。
///
/// 迁移前对应 `OverviewSystemInfoController`。同步 Notifier + 显式 flags:
/// UI 依赖「刷新中 isLoadingStatus=true 且旧 status 保留」等复合态。
/// autoDispose:离开页面即释放。
///
/// 与旧控制器一致的两点(勿"顺手统一"):
/// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
///   统计条不闪骨架;移动页刷新走 [refresh],闪骨架。
/// - 两个探针带「进行中直接 return」重入锁;两条加载腿无重入锁(与旧同)。

@ProviderFor(OverviewSystemInfo)
final overviewSystemInfoProvider = OverviewSystemInfoProvider._();

/// 系统概览(一次性加载 + 两个手动探针,无轮询)。
///
/// 迁移前对应 `OverviewSystemInfoController`。同步 Notifier + 显式 flags:
/// UI 依赖「刷新中 isLoadingStatus=true 且旧 status 保留」等复合态。
/// autoDispose:离开页面即释放。
///
/// 与旧控制器一致的两点(勿"顺手统一"):
/// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
///   统计条不闪骨架;移动页刷新走 [refresh],闪骨架。
/// - 两个探针带「进行中直接 return」重入锁;两条加载腿无重入锁(与旧同)。
final class OverviewSystemInfoProvider
    extends $NotifierProvider<OverviewSystemInfo, OverviewSystemInfoState> {
  /// 系统概览(一次性加载 + 两个手动探针,无轮询)。
  ///
  /// 迁移前对应 `OverviewSystemInfoController`。同步 Notifier + 显式 flags:
  /// UI 依赖「刷新中 isLoadingStatus=true 且旧 status 保留」等复合态。
  /// autoDispose:离开页面即释放。
  ///
  /// 与旧控制器一致的两点(勿"顺手统一"):
  /// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
  ///   统计条不闪骨架;移动页刷新走 [refresh],闪骨架。
  /// - 两个探针带「进行中直接 return」重入锁;两条加载腿无重入锁(与旧同)。
  OverviewSystemInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'overviewSystemInfoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$overviewSystemInfoHash();

  @$internal
  @override
  OverviewSystemInfo create() => OverviewSystemInfo();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OverviewSystemInfoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OverviewSystemInfoState>(value),
    );
  }
}

String _$overviewSystemInfoHash() =>
    r'fa45842890422614a1e7e4a759fb52ae405e6d48';

/// 系统概览(一次性加载 + 两个手动探针,无轮询)。
///
/// 迁移前对应 `OverviewSystemInfoController`。同步 Notifier + 显式 flags:
/// UI 依赖「刷新中 isLoadingStatus=true 且旧 status 保留」等复合态。
/// autoDispose:离开页面即释放。
///
/// 与旧控制器一致的两点(勿"顺手统一"):
/// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
///   统计条不闪骨架;移动页刷新走 [refresh],闪骨架。
/// - 两个探针带「进行中直接 return」重入锁;两条加载腿无重入锁(与旧同)。

abstract class _$OverviewSystemInfo extends $Notifier<OverviewSystemInfoState> {
  OverviewSystemInfoState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<OverviewSystemInfoState, OverviewSystemInfoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OverviewSystemInfoState, OverviewSystemInfoState>,
              OverviewSystemInfoState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
