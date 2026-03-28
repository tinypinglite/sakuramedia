import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/theme.dart';

class AppMobileSubpageShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.maybeOf(context);
    final content = PopScope<void>(
      canPop: _canPop(router, navigator),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _goToDefault(router, resolvedDefaultLocation);
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
                title: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              body: Padding(
                key: const Key('mobile-subpage-body-padding'),
                padding: bodyPadding,
                child: child,
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
        currentPath ??
        (router != null ? GoRouterState.of(context).uri.path : null);
    if (activePath != resolvedDefaultLocation) {
      _goToDefault(router, resolvedDefaultLocation);
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
