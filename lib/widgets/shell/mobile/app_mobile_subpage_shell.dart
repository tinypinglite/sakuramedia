import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_back_guard.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_ambient_backdrop.dart';
import 'package:sakuramedia/widgets/shell/mobile/mobile_subpage_app_bar.dart';
import 'package:sakuramedia/widgets/shell/mobile/mobile_subpage_back_interceptor.dart';
import 'package:sakuramedia/widgets/shell/mobile/mobile_subpage_title.dart';
import 'package:sakuramedia/widgets/shell/mobile/mobile_system_overlay.dart';

export 'mobile_subpage_app_bar.dart';
export 'mobile_subpage_back_interceptor.dart';
export 'mobile_subpage_title.dart';

class AppMobileSubpageShell extends StatefulWidget {
  const AppMobileSubpageShell({
    super.key,
    required this.title,
    required this.defaultLocation,
    required this.child,
    this.currentPath,
    this.fallbackPath,
    this.bodyPadding = AppPageInsets.compactStandard,
    this.immersive = false,
    this.autoHideAppBar = false,
    this.glassChrome = false,
  });

  final String title;
  final String defaultLocation;
  final String? fallbackPath;
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

  /// 透明页面背景 + 液态玻璃返回按钮的子页导航栏。
  ///
  /// 只改导航层和页面底色；子页内容仍是普通内容层。开启后 AppBar 常驻，
  /// 不跟随滚动收起，避免玻璃返回键在滚动中消失。
  final bool glassChrome;

  @override
  State<AppMobileSubpageShell> createState() => _AppMobileSubpageShellState();
}

class _AppMobileSubpageShellState extends State<AppMobileSubpageShell> {
  /// 子页面报上来的真实标题；为 null 时用路由给的静态标题。
  final ValueNotifier<String?> _titleOverride = ValueNotifier<String?>(null);
  final AppBackGuardController _backGuard = AppBackGuardController();
  late final AppMobileSubpageBackInterceptorController _backInterceptor =
      AppMobileSubpageBackInterceptorController(guard: _backGuard);
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
    final useGlassChrome = widget.glassChrome && !immersive;
    final autoHideAppBar = widget.autoHideAppBar && !useGlassChrome;
    final router = GoRouter.maybeOf(context);
    final appBar = AppMobileSubpageAppBar(
      title: widget.title,
      titleOverride: _titleOverride,
      onBack: () => _handleBack(context),
      immersive: immersive,
      glassChrome: useGlassChrome,
      autoHide: autoHideAppBar,
      hidden: _appBarHidden,
      animationDuration: _appBarAnimationDuration,
    );
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
        backgroundColor: useGlassChrome
            ? Colors.transparent
            : context.appColors.surfaceCard,
        body: Column(
          children: [
            appBar,
            Expanded(child: body),
          ],
        ),
      );
    } else {
      scaffold = Scaffold(
        backgroundColor: immersive || useGlassChrome
            ? Colors.transparent
            : context.appColors.surfaceCard,
        extendBodyBehindAppBar: immersive,
        appBar: appBar,
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
            : resolveMobileSystemOverlayStyle(
                context,
              ).copyWith(statusBarColor: Colors.transparent),
        child: ColoredBox(
          key: const Key('mobile-subpage-root-surface'),
          color: immersive || useGlassChrome
              ? Colors.transparent
              : context.appColors.surfaceCard,
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
    final themedContent = useGlassChrome
        ? AppMobileAmbientBackdrop(child: content)
        : content;
    final guardedContent = AppBackGuardScope(
      controller: _backGuard,
      child: themedContent,
    );
    if (router == null) return guardedContent;
    // GoRouter 对无历史可退的深链首屏会直接返回 false；这里补一次回退处理，
    // 同时让 PopScope 保持 true，避免无拦截时禁用 iOS 侧滑返回。
    return BackButtonListener(
      onBackButtonPressed: _backButtonHandler,
      child: guardedContent,
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.maybeOf(context);
    final activePath =
        widget.currentPath ??
        (router != null ? GoRouterState.of(context).uri.path : null);
    if (!await _backGuard.canLeave()) return;
    if (!mounted) return;
    if (_canPop(router, navigator)) {
      if (router != null && router.canPop()) {
        router.pop();
        return;
      }
      navigator?.pop();
      return;
    }
    final target = widget.fallbackPath ?? widget.defaultLocation;
    if (activePath != target) {
      _goToDefault(router, target);
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
    final target = widget.fallbackPath ?? widget.defaultLocation;
    if (activePath == null || activePath == target) {
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
