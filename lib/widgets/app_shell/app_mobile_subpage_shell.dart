import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/theme.dart';

class AppMobileSubpageShell extends StatelessWidget {
  const AppMobileSubpageShell({
    super.key,
    required this.title,
    required this.fallbackPath,
    required this.child,
    this.onBackOverride,
    this.shellNavigatorKey,
    this.bodyPadding = AppPageInsets.compactStandard,
  });

  final String title;
  final String fallbackPath;
  final Widget child;
  final VoidCallback? onBackOverride;
  final GlobalKey<NavigatorState>? shellNavigatorKey;
  final EdgeInsetsGeometry bodyPadding;

  @override
  Widget build(BuildContext context) {
    final content = PopScope<void>(
      canPop: _canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        context.go(fallbackPath);
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
                  onPressed: onBackOverride ?? () => _handleBack(context),
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

    if (Router.maybeOf(context) == null) {
      return content;
    }

    return BackButtonListener(
      onBackButtonPressed: () async {
        if (_canPop(context)) {
          return false;
        }
        context.go(fallbackPath);
        return true;
      },
      child: content,
    );
  }

  void _handleBack(BuildContext context) {
    final navigator = shellNavigatorKey?.currentState ?? Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go(fallbackPath);
  }

  bool _canPop(BuildContext context) {
    final navigator = shellNavigatorKey?.currentState ?? Navigator.of(context);
    return navigator.canPop();
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
