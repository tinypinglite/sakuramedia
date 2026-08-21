// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mobile_overview_tab_index_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 移动端首页(概览)当前 tab 序号,供上层壳读取。
///
/// 存在的唯一理由:壳层要决定「要不要放开左边缘侧滑打开抽屉」,而这个决定依赖
/// 首页停在哪个 tab——`Scaffold` 的边缘拖拽区在 Stack 顶层,拖拽区覆盖多宽,
/// 下面的 `TabBarView` 就有多宽收不到手势。只有停在第一个 tab 时右滑本就无处
/// 可去(已到头),让给抽屉才不会剥夺「右滑切回上一个 tab」。
///
/// 首页在路由树里被壳包着,拿不到向上的通道,因此走本 provider 上报。
///
/// **作用域是移动壳子树,不是 app 全局**:autoDispose——壳与首页 reporter
/// `ref.watch` 时创建,双方都不在时自动释放,随壳挂载/销毁的生命周期语义与旧
/// 局部 provider 一致。刻意不 keepAlive:它是纯移动端 UI 手势状态,桌面端
/// 永不创建。因此壳侧与首页侧都可以按「必然存在」直接 `watch` / `read`。
///
/// 迁移前形态:`MobileOverviewTabIndexNotifier extends ValueNotifier<int>`
/// + legacy `ChangeNotifierProvider.autoDispose`。

@ProviderFor(MobileOverviewTabIndex)
final mobileOverviewTabIndexProvider = MobileOverviewTabIndexProvider._();

/// 移动端首页(概览)当前 tab 序号,供上层壳读取。
///
/// 存在的唯一理由:壳层要决定「要不要放开左边缘侧滑打开抽屉」,而这个决定依赖
/// 首页停在哪个 tab——`Scaffold` 的边缘拖拽区在 Stack 顶层,拖拽区覆盖多宽,
/// 下面的 `TabBarView` 就有多宽收不到手势。只有停在第一个 tab 时右滑本就无处
/// 可去(已到头),让给抽屉才不会剥夺「右滑切回上一个 tab」。
///
/// 首页在路由树里被壳包着,拿不到向上的通道,因此走本 provider 上报。
///
/// **作用域是移动壳子树,不是 app 全局**:autoDispose——壳与首页 reporter
/// `ref.watch` 时创建,双方都不在时自动释放,随壳挂载/销毁的生命周期语义与旧
/// 局部 provider 一致。刻意不 keepAlive:它是纯移动端 UI 手势状态,桌面端
/// 永不创建。因此壳侧与首页侧都可以按「必然存在」直接 `watch` / `read`。
///
/// 迁移前形态:`MobileOverviewTabIndexNotifier extends ValueNotifier<int>`
/// + legacy `ChangeNotifierProvider.autoDispose`。
final class MobileOverviewTabIndexProvider
    extends $NotifierProvider<MobileOverviewTabIndex, int> {
  /// 移动端首页(概览)当前 tab 序号,供上层壳读取。
  ///
  /// 存在的唯一理由:壳层要决定「要不要放开左边缘侧滑打开抽屉」,而这个决定依赖
  /// 首页停在哪个 tab——`Scaffold` 的边缘拖拽区在 Stack 顶层,拖拽区覆盖多宽,
  /// 下面的 `TabBarView` 就有多宽收不到手势。只有停在第一个 tab 时右滑本就无处
  /// 可去(已到头),让给抽屉才不会剥夺「右滑切回上一个 tab」。
  ///
  /// 首页在路由树里被壳包着,拿不到向上的通道,因此走本 provider 上报。
  ///
  /// **作用域是移动壳子树,不是 app 全局**:autoDispose——壳与首页 reporter
  /// `ref.watch` 时创建,双方都不在时自动释放,随壳挂载/销毁的生命周期语义与旧
  /// 局部 provider 一致。刻意不 keepAlive:它是纯移动端 UI 手势状态,桌面端
  /// 永不创建。因此壳侧与首页侧都可以按「必然存在」直接 `watch` / `read`。
  ///
  /// 迁移前形态:`MobileOverviewTabIndexNotifier extends ValueNotifier<int>`
  /// + legacy `ChangeNotifierProvider.autoDispose`。
  MobileOverviewTabIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mobileOverviewTabIndexProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mobileOverviewTabIndexHash();

  @$internal
  @override
  MobileOverviewTabIndex create() => MobileOverviewTabIndex();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$mobileOverviewTabIndexHash() =>
    r'10a5fba5a024152ebea4e8ea846bfc5eaee2b936';

/// 移动端首页(概览)当前 tab 序号,供上层壳读取。
///
/// 存在的唯一理由:壳层要决定「要不要放开左边缘侧滑打开抽屉」,而这个决定依赖
/// 首页停在哪个 tab——`Scaffold` 的边缘拖拽区在 Stack 顶层,拖拽区覆盖多宽,
/// 下面的 `TabBarView` 就有多宽收不到手势。只有停在第一个 tab 时右滑本就无处
/// 可去(已到头),让给抽屉才不会剥夺「右滑切回上一个 tab」。
///
/// 首页在路由树里被壳包着,拿不到向上的通道,因此走本 provider 上报。
///
/// **作用域是移动壳子树,不是 app 全局**:autoDispose——壳与首页 reporter
/// `ref.watch` 时创建,双方都不在时自动释放,随壳挂载/销毁的生命周期语义与旧
/// 局部 provider 一致。刻意不 keepAlive:它是纯移动端 UI 手势状态,桌面端
/// 永不创建。因此壳侧与首页侧都可以按「必然存在」直接 `watch` / `read`。
///
/// 迁移前形态:`MobileOverviewTabIndexNotifier extends ValueNotifier<int>`
/// + legacy `ChangeNotifierProvider.autoDispose`。

abstract class _$MobileOverviewTabIndex extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
