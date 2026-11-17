import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'mobile_overview_tab_index_provider.g.dart';

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
@riverpod
class MobileOverviewTabIndex extends _$MobileOverviewTabIndex {
  @override
  int build() => 0;

  /// 首页 reporter 上报当前 tab 序号。Riverpod Notifier 对相同 state 默认按
  /// `==` 去重(等价旧 ValueNotifier「相同值不通知」),拖动动画期间的每帧
  /// 回调不会引起壳重建。
  void report(int index) {
    state = index;
  }
}
