import 'package:material_ui/material_ui.dart';

/// 让子页面把「真实标题」报给外层返回栏的信箱。
///
/// 路由层只知道静态标题（「合集」「播放列表详情」…），真正的名字要等页面把数据
/// 拉回来才有。页面拿到后 `AppMobileSubpageTitle.read(context)?.value = name`，
/// 返回栏立刻换成它，页面内部就不必再写一遍标题——省掉「静态标题 + 页内大标题」
/// 两层重复，也把列表往上提了一整块。
///
/// 没有报的子页保持路由传进来的静态标题，行为不变。
class AppMobileSubpageTitle extends InheritedWidget {
  const AppMobileSubpageTitle({
    super.key,
    required this.notifier,
    required super.child,
  });

  final ValueNotifier<String?> notifier;

  /// 不建立依赖关系的读取——在 `initState` / 回调里写标题时用这个，避免把页面
  /// 挂到 InheritedWidget 的重建链上。
  static ValueNotifier<String?>? read(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<AppMobileSubpageTitle>()
        ?.notifier;
  }

  @override
  bool updateShouldNotify(AppMobileSubpageTitle oldWidget) =>
      notifier != oldWidget.notifier;
}
