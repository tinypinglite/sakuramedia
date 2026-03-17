import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_sidebar.dart';
import 'package:sakuramedia/widgets/app_shell/app_top_bar.dart';

class AppDesktopShell extends StatelessWidget {
  const AppDesktopShell({
    super.key,
    required this.currentPath,
    required this.layout,
    required this.topBarConfig,
    required this.shellNavigatorKey,
    required this.navGroups,
    required this.child,
  });

  final String currentPath;
  final AppShellLayout layout;
  final DesktopTopBarConfig topBarConfig;
  final GlobalKey<NavigatorState> shellNavigatorKey;
  final List<AppNavGroup> navGroups;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final useMacSidebarGlass =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

    return Scaffold(
      backgroundColor:
          useMacSidebarGlass
              ? Colors.transparent
              : context.appColors.surfacePage,
      body: SafeArea(
        child: Row(
          children: [
            AppSidebar(currentPath: currentPath, navGroups: navGroups),
            Expanded(
              child: Container(
                key: const Key('desktop-shell-content-surface'),
                color: context.appColors.surfaceElevated,
                child: Column(
                  children: [
                    AppTopBar(
                      currentPath: currentPath,
                      config: topBarConfig,
                      shellNavigatorKey: shellNavigatorKey,
                    ),
                    Expanded(
                      child: _DesktopShellBody(layout: layout, child: child),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopShellBody extends StatelessWidget {
  const _DesktopShellBody({required this.layout, required this.child});

  final AppShellLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      AppShellLayout.standard => Padding(
        padding: AppPageInsets.desktopStandard,
        child: child,
      ),
      AppShellLayout.fullscreen => child,
    };
  }
}
