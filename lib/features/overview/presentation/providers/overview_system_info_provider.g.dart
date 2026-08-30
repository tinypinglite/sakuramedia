// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overview_system_info_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 系统概览(一次性加载 + 两个手动探针,无轮询)。
///
/// 同步 Notifier + 显式 flags，供桌面/移动概览页分别展示刷新与探针状态；
/// autoDispose，离开页面即释放。
///
/// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
///   统计条不闪骨架;移动页刷新走 [refresh],闪骨架。
/// - 元数据源探针进行中直接 return；系统信息与图片搜索两条加载腿不加重入锁。

@ProviderFor(OverviewSystemInfo)
final overviewSystemInfoProvider = OverviewSystemInfoProvider._();

/// 系统概览(一次性加载 + 两个手动探针,无轮询)。
///
/// 同步 Notifier + 显式 flags，供桌面/移动概览页分别展示刷新与探针状态；
/// autoDispose，离开页面即释放。
///
/// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
///   统计条不闪骨架;移动页刷新走 [refresh],闪骨架。
/// - 元数据源探针进行中直接 return；系统信息与图片搜索两条加载腿不加重入锁。
final class OverviewSystemInfoProvider
    extends $NotifierProvider<OverviewSystemInfo, OverviewSystemInfoState> {
  /// 系统概览(一次性加载 + 两个手动探针,无轮询)。
  ///
  /// 同步 Notifier + 显式 flags，供桌面/移动概览页分别展示刷新与探针状态；
  /// autoDispose，离开页面即释放。
  ///
  /// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
  ///   统计条不闪骨架;移动页刷新走 [refresh],闪骨架。
  /// - 元数据源探针进行中直接 return；系统信息与图片搜索两条加载腿不加重入锁。
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
    r'67e784d261347f29721e15c4c22926e9fa0c2cf7';

/// 系统概览(一次性加载 + 两个手动探针,无轮询)。
///
/// 同步 Notifier + 显式 flags，供桌面/移动概览页分别展示刷新与探针状态；
/// autoDispose，离开页面即释放。
///
/// - [load] 不置 loading 标志([refresh] 才置)——桌面概览页刷新走 [load],
///   统计条不闪骨架;移动页刷新走 [refresh],闪骨架。
/// - 元数据源探针进行中直接 return；系统信息与图片搜索两条加载腿不加重入锁。

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
