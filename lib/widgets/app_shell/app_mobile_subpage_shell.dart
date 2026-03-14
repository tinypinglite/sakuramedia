import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/theme.dart';

class AppMobileSubpageShell extends StatelessWidget {
  const AppMobileSubpageShell({
    super.key,
    required this.title,
    required this.fallbackPath,
    required this.child,
    this.onBackOverride,
  });

  final String title;
  final String fallbackPath;
  final Widget child;
  final VoidCallback? onBackOverride;

  @override
  Widget build(BuildContext context) {
    final content = PopScope<void>(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        context.go(fallbackPath);
      },
      child: Scaffold(
        appBar: AppBar(
          key: const Key('mobile-subpage-topbar'),
          backgroundColor: context.appColors.surfacePage,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 40, // 默认 56
          titleSpacing: 0, // 默认 16
          leading: IconButton(
            iconSize: context.appComponentTokens.iconSizeSm,
            // iconSize: context.theme,
            key: const Key('mobile-subpage-back-button'),
            onPressed: onBackOverride ?? () => _handleBack(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            tooltip: '返回',
          ),
          title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        body: Padding(padding: AppPageInsets.compactStandard, child: child),
      ),
    );

    if (Router.maybeOf(context) == null) {
      return content;
    }

    return BackButtonListener(
      onBackButtonPressed: () async {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          return false;
        }
        context.go(fallbackPath);
        return true;
      },
      child: content,
    );
  }

  void _handleBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go(fallbackPath);
  }
}
