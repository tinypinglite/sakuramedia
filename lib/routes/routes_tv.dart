import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_registry.dart';
import 'package:sakuramedia/widgets/shell/tv/app_tv_shell.dart';

final GlobalKey<NavigatorState> tvRootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'tv-root-navigator',
);
final GlobalKey<NavigatorState> tvShellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'tv-shell-navigator',
);
final GlobalKey<NavigatorState> tvHomeNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'tv-home-navigator',
);
final GlobalKey<NavigatorState> tvMoviesNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'tv-movies-navigator');
final GlobalKey<NavigatorState> tvSearchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'tv-search-navigator');
final GlobalKey<NavigatorState> tvSettingsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'tv-settings-navigator');

final Map<AppRouteId, GlobalKey<NavigatorState>> _tvBranchNavigatorKeys = {
  AppRouteId.tvHome: tvHomeNavigatorKey,
  AppRouteId.tvMovies: tvMoviesNavigatorKey,
  AppRouteId.tvSearch: tvSearchNavigatorKey,
  AppRouteId.tvSettings: tvSettingsNavigatorKey,
};

List<RouteBase> buildTvRouteTree() {
  final outsideShell = appRoutes
      .scoped(AppPlatform.tv, AppRouteScope.outsideShell)
      .map(_tvGoRoute)
      .toList(growable: false);
  final shellLevel = appRoutes
      .scoped(AppPlatform.tv, AppRouteScope.shellLevel)
      .map(_tvGoRoute)
      .toList(growable: false);
  final branches = tvPrimaryBranchOrder
      .map((id) {
        final definition = appRoutes.byId(id);
        return StatefulShellBranch(
          navigatorKey: _tvBranchNavigatorKeys[id],
          routes: <RouteBase>[_tvGoRoute(definition)],
        );
      })
      .toList(growable: false);

  return <RouteBase>[
    ...outsideShell,
    ShellRoute(
      navigatorKey: tvShellNavigatorKey,
      pageBuilder: (context, state, navigator) => NoTransitionPage<void>(
        key: state.pageKey,
        name: state.name ?? state.path,
        child: _TvShellScope(state: state, child: navigator),
      ),
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          branches: branches,
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

GoRoute _tvGoRoute(AppRouteDefinition definition) {
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

class _TvShellScope extends ConsumerWidget {
  const _TvShellScope({required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(appLocalizationsProvider);
    final definition = appRoutes.forState(AppPlatform.tv, state);
    return AppTvShell(
      currentPath: state.uri.path,
      navItems: tvNavItems(l10n),
      showNav: definition?.layout != AppShellLayout.immersive,
      child: child,
    );
  }
}
