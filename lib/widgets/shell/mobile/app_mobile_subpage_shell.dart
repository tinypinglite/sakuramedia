import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/shell/mobile/mobile_system_overlay.dart';

typedef AppMobileSubpageBackHandler = Future<bool> Function();

/// 页面注册到子页壳的返回拦截器。默认没有处理函数时直接放行。
class AppMobileSubpageBackInterceptorController {
  final ValueNotifier<bool> _canPop = ValueNotifier<bool>(true);
  AppMobileSubpageBackHandler? _handler;

  /// 页面同步声明的路由返回资格。
  ///
  /// `false` 会让 [PopScope] 保留拦截能力并关闭 iOS 侧滑等平台返回手势；
  /// 没有页面注册 handler 时始终为 `true`。
  ValueListenable<bool> get canPop => _canPop;

  void attach(AppMobileSubpageBackHandler handler) {
    _handler = handler;
    _setCanPop(true);
  }

  void detach(AppMobileSubpageBackHandler handler) {
    if (_handler != handler) return;
    _handler = null;
    _setCanPop(true);
  }

  /// 由页面在脏状态变化时同步调用。
  void setCanPop(bool canPop) {
    _setCanPop(_handler == null || canPop);
  }

  Future<bool> shouldPop() async {
    final handler = _handler;
    return handler == null || await handler();
  }

  void _setCanPop(bool canPop) {
    if (_canPop.value == canPop) return;
    _canPop.value = canPop;
  }

  void dispose() {
    _handler = null;
    _canPop.dispose();
  }
}

class AppMobileSubpageBackInterceptor extends InheritedWidget {
  const AppMobileSubpageBackInterceptor({
    super.key,
    required this.controller,
    required super.child,
  });

  final AppMobileSubpageBackInterceptorController controller;

  static AppMobileSubpageBackInterceptorController? maybeOf(
    BuildContext context,
  ) {
    return context
        .dependOnInheritedWidgetOfExactType<AppMobileSubpageBackInterceptor>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(AppMobileSubpageBackInterceptor oldWidget) =>
      controller != oldWidget.controller;
}

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

class AppMobileSubpageShell extends StatefulWidget {
  const AppMobileSubpageShell({
    super.key,
    required this.title,
    required this.defaultLocation,
    required this.child,
    this.currentPath,
    this.bodyPadding = AppPageInsets.compactStandard,
    this.immersive = false,
    this.autoHideAppBar = false,
  });

  final String title;
  final String defaultLocation;
  final Widget child;
  final String? currentPath;
  final EdgeInsetsGeometry bodyPadding;

  /// 沉浸详情：透明底 + 返回栏悬浮在内容之上（影片详情用）。
  final bool immersive;

  /// 子页是否随滚动收起 AppBar：滚离顶部隐藏，回到顶部才恢复。
  ///
  /// 非沉浸子页收起时 AppBar 高度归零、内容随之上移；沉浸子页的返回栏本来
  /// 就悬浮在内容上，收起只做淡出，正文不位移。
  ///
  /// 移动路由层对所有子页传 true；直接使用 shell 时默认 false，
  /// 需要滚动收起时显式开启。
  final bool autoHideAppBar;

  @override
  State<AppMobileSubpageShell> createState() => _AppMobileSubpageShellState();
}

class _AppMobileSubpageShellState extends State<AppMobileSubpageShell> {
  /// 子页面报上来的真实标题；为 null 时用路由给的静态标题。
  final ValueNotifier<String?> _titleOverride = ValueNotifier<String?>(null);
  final AppMobileSubpageBackInterceptorController _backInterceptor =
      AppMobileSubpageBackInterceptorController();
  late final ValueGetter<Future<bool>> _backButtonHandler =
      _handleBackButtonPressed;

  /// autoHideAppBar 子页是否已滚离顶部。
  bool _appBarHidden = false;

  static const Duration _appBarAnimationDuration = Duration(milliseconds: 180);

  @override
  void dispose() {
    _titleOverride.dispose();
    _backInterceptor.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    // depth 0 的横向 PageView / TabBarView 切换：新 Tab 可能停在顶部，也可能
    // 内容不足一屏，不会再发出纵向通知；先恢复 AppBar 避免返回键/标题消失。
    // 若新 Tab 本身停留在滚动位置，后续纵向滚动会重新收起。
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.horizontal) {
      if (_appBarHidden) {
        setState(() => _appBarHidden = false);
      }
      return false;
    }
    // depth 0：页面自身的主滚动；depth 1：TabBarView / PageView 里的纵向列表
    // （媒体管理、下载器等 tab 子页）。更深的嵌套滚动不驱动 AppBar。
    if (notification.depth > 1 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final hidden = notification.metrics.pixels > 0;
    if (hidden != _appBarHidden) {
      setState(() => _appBarHidden = hidden);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final immersive = widget.immersive;
    final autoHideAppBar = widget.autoHideAppBar;
    final router = GoRouter.maybeOf(context);
    final appBar = _buildAppBar(context, immersive: immersive);
    final interceptedChild = AppMobileSubpageBackInterceptor(
      controller: _backInterceptor,
      child: widget.child,
    );
    final pageChild = autoHideAppBar
        ? NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: interceptedChild,
          )
        : interceptedChild;
    final body = Padding(
      key: const Key('mobile-subpage-body-padding'),
      padding: widget.bodyPadding,
      child: AppMobileSubpageTitle(notifier: _titleOverride, child: pageChild),
    );
    final Widget scaffold;
    if (autoHideAppBar && !immersive) {
      scaffold = Scaffold(
        backgroundColor: context.appColors.surfaceCard,
        body: Column(
          children: [
            AnimatedSize(
              duration: _appBarAnimationDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _appBarHidden
                  ? const SizedBox(width: double.infinity)
                  : SizedBox(height: kToolbarHeight, child: appBar),
            ),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        backgroundColor: immersive
            ? Colors.transparent
            : context.appColors.surfaceCard,
        extendBodyBehindAppBar: immersive,
        appBar: immersive && autoHideAppBar
            ? _AutoHideOverlayAppBar(
                hidden: _appBarHidden,
                duration: _appBarAnimationDuration,
                child: appBar,
              )
            : appBar,
        body: body,
      );
    }
    final content = ValueListenableBuilder<bool>(
      valueListenable: _backInterceptor.canPop,
      builder: (context, canPop, child) {
        return PopScope<void>(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleBack(context);
          },
          child: child!,
        );
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        key: const Key('mobile-subpage-system-overlay'),
        value: immersive
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : resolveMobileSystemOverlayStyle(context),
        child: ColoredBox(
          key: const Key('mobile-subpage-root-surface'),
          color: immersive ? Colors.transparent : context.appColors.surfaceCard,
          child: SafeArea(
            key: const Key('mobile-subpage-safe-area'),
            // 沉浸时顶边不留安全区：封面从状态栏下开始铺。
            top: !immersive,
            // 底边一律不留：内容铺到屏幕物理底边（沉浸页的封面背景因此盖住
            // home indicator 区，非沉浸页由外壳底色兜底）。底部安全区改由内容
            // 层自己留——滚动页在滚动末尾补 `MediaQuery.paddingOf().bottom`
            //（`AppAdaptiveRefreshScrollView` / `BoxScrollView` 已统一处理），
            // 贴底操作条自带 `SafeArea(top: false)`。新加子页面时别忘了这一条。
            bottom: false,
            child: scaffold,
          ),
        ),
      ),
    );
    if (router == null) return content;
    // GoRouter 对无历史可退的深链首屏会直接返回 false；这里补一次回退处理，
    // 同时让 PopScope 保持 true，避免无拦截时禁用 iOS 侧滑返回。
    return BackButtonListener(
      onBackButtonPressed: _backButtonHandler,
      child: content,
    );
  }

  AppBar _buildAppBar(BuildContext context, {required bool immersive}) {
    final l10n = appL10n(context);
    return AppBar(
      key: const Key('mobile-subpage-topbar'),
      backgroundColor: immersive
          ? Colors.transparent
          : context.appColors.surfaceCard,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: immersive
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.appColors.mediaOverlayStrong.withValues(
                      alpha: 0.55,
                    ),
                    context.appColors.mediaOverlayStrong.withValues(alpha: 0),
                  ],
                ),
              ),
            )
          : null,
      leadingWidth: context.appComponentTokens.mobileSubpageLeadingWidth,
      titleSpacing: 0, // 默认 16
      leading: IconButton(
        iconSize: context.appComponentTokens.iconSizeSm,
        key: const Key('mobile-subpage-back-button'),
        onPressed: () => _handleBack(context),
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          // 沉浸页压在封面和顶部压暗渐变上，沿用媒体前景色保证可读。
          color: immersive ? context.appTextPalette.onMedia : null,
        ),
        tooltip: l10n.shellBack,
      ),
      title: immersive
          // 沉浸页不占标题位：封面直通状态栏，顶栏只留返回键和渐变。
          ? null
          : ValueListenableBuilder<String?>(
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
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.maybeOf(context);
    final activePath =
        widget.currentPath ??
        (router != null ? GoRouterState.of(context).uri.path : null);
    if (!await _backInterceptor.shouldPop()) return;
    if (!mounted) return;
    if (_canPop(router, navigator)) {
      if (router != null && router.canPop()) {
        router.pop();
        return;
      }
      navigator?.pop();
      return;
    }
    if (activePath != widget.defaultLocation) {
      _goToDefault(router, widget.defaultLocation);
    }
  }

  Future<bool> _handleBackButtonPressed() async {
    if (!mounted) return false;
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.maybeOf(context);
    if (_canPop(router, navigator)) return false;
    final activePath =
        widget.currentPath ??
        (router != null ? GoRouterState.of(context).uri.path : null);
    if (activePath == null || activePath == widget.defaultLocation) {
      return false;
    }
    await _handleBack(context);
    return true;
  }

  bool _canPop(GoRouter? router, NavigatorState? navigator) {
    return router?.canPop() ?? navigator?.canPop() ?? false;
  }

  void _goToDefault(GoRouter? router, String location) {
    // 子页面优先交给路由系统处理；在纯组件宿主下没有 GoRouter 时保持静默。
    router?.go(location);
  }
}

/// 沉浸子页的悬浮返回栏：滚离顶部时淡出，正文保持全幅铺底不位移。
///
/// 与普通子页不同，这里不能用高度动画——沉浸页的 AppBar 是叠在内容上的，
/// 高度归零不会让内容上移，反而会闪一次布局。淡出期间仍保留 preferredSize，
/// 隐藏后屏蔽命中和语义，避免透明返回键被点到或读屏读到。
class _AutoHideOverlayAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _AutoHideOverlayAppBar({
    required this.hidden,
    required this.duration,
    required this.child,
  });

  final bool hidden;
  final Duration duration;

  /// 必须是 [AppBar]：它自身携带状态栏高度和工具栏高度。
  final AppBar child;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: hidden,
      child: ExcludeSemantics(
        excluding: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }
}
