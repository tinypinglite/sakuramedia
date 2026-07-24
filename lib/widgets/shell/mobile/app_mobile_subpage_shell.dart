import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/theme.dart';

/// 让子页面把「真实标题」报给外层返回栏的信箱。
///
/// 路由层只知道静态标题（「合集」「播放列表详情」…），真正的名字要等页面把数据
/// 拉回来才有。页面拿到后 `AppMobileSubpageTitle.of(context)?.value = name`，
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

  static ValueNotifier<String?>? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppMobileSubpageTitle>()
        ?.notifier;
  }

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

class AppMobileSubpageShell extends StatefulWidget {
  const AppMobileSubpageShell({
    super.key,
    required this.title,
    this.defaultLocation,
    @Deprecated('请改用 defaultLocation。') this.fallbackPath,
    required this.child,
    this.currentPath,
    this.bodyPadding = AppPageInsets.compactStandard,
  }) : assert(
         defaultLocation != null || fallbackPath != null,
         'defaultLocation 和 fallbackPath 至少需要提供一个',
       ),
       resolvedDefaultLocation = defaultLocation ?? fallbackPath ?? '';

  final String title;
  final String? defaultLocation;
  @Deprecated('请改用 defaultLocation。')
  final String? fallbackPath;
  final String resolvedDefaultLocation;
  final Widget child;
  final String? currentPath;
  final EdgeInsetsGeometry bodyPadding;

  @override
  State<AppMobileSubpageShell> createState() => _AppMobileSubpageShellState();
}

class _AppMobileSubpageShellState extends State<AppMobileSubpageShell> {
  /// 子页面报上来的真实标题；为 null 时用路由给的静态标题。
  final ValueNotifier<String?> _titleOverride = ValueNotifier<String?>(null);

  @override
  void dispose() {
    _titleOverride.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.maybeOf(context);
    final content = PopScope<void>(
      canPop: _canPop(router, navigator),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _goToDefault(router, widget.resolvedDefaultLocation);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        key: const Key('mobile-subpage-system-overlay'),
        value: _mobileSystemOverlayStyle(context),
        child: ColoredBox(
          key: const Key('mobile-subpage-root-surface'),
          color: context.appColors.surfaceCard,
          child: SafeArea(
            key: const Key('mobile-subpage-safe-area'),
            child: Scaffold(
              backgroundColor: context.appColors.surfaceCard,
              appBar: AppBar(
                key: const Key('mobile-subpage-topbar'),
                backgroundColor: context.appColors.surfaceCard,
                elevation: 0,
                scrolledUnderElevation: 0,
                leadingWidth:
                    context.appComponentTokens.mobileSubpageLeadingWidth,
                titleSpacing: 0, // 默认 16
                leading: IconButton(
                  iconSize: context.appComponentTokens.iconSizeSm,
                  key: const Key('mobile-subpage-back-button'),
                  onPressed: () => _handleBack(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  tooltip: '返回',
                ),
                title: ValueListenableBuilder<String?>(
                  valueListenable: _titleOverride,
                  builder: (context, override, _) {
                    final resolved =
                        (override != null && override.trim().isNotEmpty)
                            ? override
                            : widget.title;
                    return Text(
                      resolved,
                      key: const Key('mobile-subpage-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.medium,
                        tone: AppTextTone.primary,
                      ),
                    );
                  },
                ),
              ),
              body: Padding(
                key: const Key('mobile-subpage-body-padding'),
                padding: widget.bodyPadding,
                child: AppMobileSubpageTitle(
                  notifier: _titleOverride,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return content;
  }

  void _handleBack(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.maybeOf(context);
    if (_canPop(router, navigator)) {
      if (router != null && router.canPop()) {
        router.pop();
        return;
      }
      navigator?.pop();
      return;
    }
    final activePath =
        widget.currentPath ??
        (router != null ? GoRouterState.of(context).uri.path : null);
    if (activePath != widget.resolvedDefaultLocation) {
      _goToDefault(router, widget.resolvedDefaultLocation);
    }
  }

  bool _canPop(GoRouter? router, NavigatorState? navigator) {
    return router?.canPop() ?? navigator?.canPop() ?? false;
  }

  void _goToDefault(GoRouter? router, String location) {
    // 子页面优先交给路由系统处理；在纯组件宿主下没有 GoRouter 时保持静默。
    router?.go(location);
  }

  SystemUiOverlayStyle _mobileSystemOverlayStyle(BuildContext context) {
    return SystemUiOverlayStyle(
      statusBarColor: context.appColors.surfaceCard,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: context.appColors.surfaceCard,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: context.appColors.divider,
    );
  }
}
