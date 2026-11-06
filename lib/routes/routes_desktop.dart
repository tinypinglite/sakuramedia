import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_registry.dart';
import 'package:sakuramedia/routes/desktop_branch_cache.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_desktop_shell.dart';

final GlobalKey<NavigatorState> desktopRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'desktop-root-navigator');
final GlobalKey<NavigatorState> desktopShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'desktop-shell-navigator');

List<RouteBase> buildDesktopRouteTree() {
  final outsideShell = appRoutes
      .scoped(AppPlatform.desktop, AppRouteScope.outsideShell)
      .map(_desktopGoRoute)
      .toList(growable: false);
  final shellLevel = appRoutes
      .scoped(AppPlatform.desktop, AppRouteScope.shellLevel)
      .map(_desktopGoRoute)
      .toList(growable: false);
  final branches = desktopPrimaryBranchOrder
      .map((id) {
        final definition = appRoutes.byId(id);
        return StatefulShellBranch(
          routes: <RouteBase>[_desktopGoRoute(definition)],
        );
      })
      .toList(growable: false);

  return <RouteBase>[
    ...outsideShell,
    ShellRoute(
      navigatorKey: desktopShellNavigatorKey,
      builder: (context, state, navigator) =>
          _DesktopShellScope(state: state, child: navigator),
      pageBuilder: (context, state, navigator) => NoTransitionPage<void>(
        key: state.pageKey,
        name: state.name ?? state.path,
        child: _DesktopShellScope(state: state, child: navigator),
      ),
      routes: <RouteBase>[
        StatefulShellRoute(
          branches: branches,
          navigatorContainerBuilder: (context, navigationShell, children) =>
              DesktopBranchCache(
                currentIndex: navigationShell.currentIndex,
                children: children,
              ),
          builder: (context, state, navigationShell) => navigationShell,
          pageBuilder: (context, state, navigationShell) =>
              NoTransitionPage<void>(
                key: state.pageKey,
                name: state.name ?? state.path,
                child: navigationShell,
              ),
        ),
        ...shellLevel,
      ],
    ),
  ];
}

GoRoute _desktopGoRoute(AppRouteDefinition definition) {
  return GoRoute(
    path: definition.path,
    name: definition.name,
    pageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      name: definition.name,
      child: definition.pageBuilder(context, state),
    ),
  );
}

class _DesktopShellScope extends ConsumerWidget {
  const _DesktopShellScope({required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final definition = appRoutes.forState(AppPlatform.desktop, state);
    return AppDesktopShell(
      currentPath: state.uri.path,
      layout: definition?.layout ?? AppShellLayout.standard,
      topBarConfig: resolveDesktopTopBarConfig(state: state, l10n: l10n),
      shellNavigatorKey: desktopShellNavigatorKey,
      navItems: desktopNavItems(l10n),
      showTopBar: definition?.showTopBar ?? true,
      child: child,
    );
  }
}
