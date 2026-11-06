import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/auth/presentation/actions/auth_actions.dart';
import 'package:sakuramedia/features/overview/presentation/providers/mobile_overview_tab_index_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_registry.dart';
import 'package:sakuramedia/routes/app_route_target.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_ambient_backdrop.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_shell.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';
import 'package:sakuramedia/widgets/shell/mobile/mobile_overview_drawer.dart';

final GlobalKey<NavigatorState> mobileRootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-root-navigator');
final GlobalKey<NavigatorState> mobileOverviewNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-overview-navigator');
final GlobalKey<NavigatorState> mobileMoviesNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-movies-navigator');
final GlobalKey<NavigatorState> mobileActorsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-actors-navigator');
final GlobalKey<NavigatorState> mobileRankingsNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-rankings-navigator');
final GlobalKey<NavigatorState> mobilePornboxNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'mobile-pornbox-navigator');

final Map<AppRouteId, GlobalKey<NavigatorState>> _branchNavigatorKeys = {
  AppRouteId.mobileOverview: mobileOverviewNavigatorKey,
  AppRouteId.mobileMovies: mobileMoviesNavigatorKey,
  AppRouteId.mobileActors: mobileActorsNavigatorKey,
  AppRouteId.mobileRankings: mobileRankingsNavigatorKey,
  AppRouteId.mobilePornbox: mobilePornboxNavigatorKey,
};

List<RouteBase> buildMobileRouteTree() {
  final outsideShell = appRoutes
      .scoped(AppPlatform.mobile, AppRouteScope.outsideShell)
      .map(_mobileGoRoute)
      .toList(growable: false);
  final branches = mobilePrimaryBranchOrder
      .map((id) {
        final root = appRoutes.byId(id);
        final children = appRoutes
            .scoped(AppPlatform.mobile, AppRouteScope.branchChild, parentId: id)
            .map((child) => _mobileBranchChildRoute(root, child))
            .toList(growable: false);
        return StatefulShellBranch(
          navigatorKey: _branchNavigatorKeys[id],
          routes: <RouteBase>[
            GoRoute(
              path: root.path,
              name: root.name,
              pageBuilder: (context, state) =>
                  _mobilePage(root, context, state),
              routes: children,
            ),
          ],
        );
      })
      .toList(growable: false);

  return <RouteBase>[
    ...outsideShell,
    StatefulShellRoute.indexedStack(
      branches: branches,
      builder: (context, state, navigationShell) =>
          _MobileRootShellScope(state: state, navigationShell: navigationShell),
    ),
  ];
}

GoRoute _mobileGoRoute(AppRouteDefinition definition) {
  return GoRoute(
    path: definition.path,
    name: definition.name,
    pageBuilder: (context, state) => _mobilePage(definition, context, state),
  );
}

GoRoute _mobileBranchChildRoute(
  AppRouteDefinition parent,
  AppRouteDefinition child,
) {
  final relativePath = child.path.substring(parent.path.length + 1);
  return GoRoute(
    path: relativePath,
    name: child.name,
    parentNavigatorKey: child.useRootNavigator ? mobileRootNavigatorKey : null,
    pageBuilder: (context, state) => _mobilePage(child, context, state),
  );
}

Page<void> _mobilePage(
  AppRouteDefinition definition,
  BuildContext context,
  GoRouterState state,
) {
  final content = definition.pageBuilder(context, state);
  if (definition.scope == AppRouteScope.branchRoot) {
    return NoTransitionPage<void>(
      key: state.pageKey,
      name: definition.name,
      child: content,
    );
  }
  final chrome = definition.subpageChrome;
  if (chrome != null) {
    return CupertinoPage<void>(
      key: state.pageKey,
      name: definition.name,
      child: _LocalizedMobileSubpageShell(
        title: definition.title,
        defaultLocation:
            definition.backTarget?.call(state) ?? mobileOverviewPath,
        fallbackPath: AppRouteExtra.fallbackPathOf(
          state.extra,
          platform: AppPlatform.mobile,
        ),
        currentPath: state.uri.path,
        chrome: chrome,
        child: content,
      ),
    );
  }
  switch (definition.transition) {
    case AppRouteTransition.material:
      return MaterialPage<void>(
        key: state.pageKey,
        name: definition.name,
        child: content,
      );
    case AppRouteTransition.cupertino:
      return CupertinoPage<void>(
        key: state.pageKey,
        name: definition.name,
        child: content,
      );
    case AppRouteTransition.none:
      return NoTransitionPage<void>(
        key: state.pageKey,
        name: definition.name,
        child: content,
      );
  }
}

class _MobileRootShellScope extends ConsumerStatefulWidget {
  const _MobileRootShellScope({
    required this.state,
    required this.navigationShell,
  });

  final GoRouterState state;
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<_MobileRootShellScope> createState() =>
      _MobileRootShellScopeState();
}

class _MobileRootShellScopeState extends ConsumerState<_MobileRootShellScope> {
  @override
  Widget build(BuildContext context) {
    final navigationShell = widget.navigationShell;
    final currentPath = widget.state.uri.path;
    final enableOverviewDrawer =
        navigationShell.currentIndex == mobileOverviewBranchIndex;
    final enableOverviewDrawerDrag =
        enableOverviewDrawer &&
        currentPath == mobileOverviewPath &&
        ref.watch(mobileOverviewTabIndexProvider) == 0;
    final l10n = ref.watch(appLocalizationsProvider);
    final navItems = mobileNavItems(l10n);
    return AppMobileShell(
      currentPath: currentPath,
      navItems: navItems,
      currentIndex: navigationShell.currentIndex,
      drawer: enableOverviewDrawer
          ? MobileOverviewDrawer(
              hostContext: context,
              sections: mobileDrawerSections(l10n),
              onSelected: (entry) =>
                  AppRouteTarget(id: entry.routeId).push(context),
              onLogout: () => context.logOut(),
              onOpenPluginUpdates: () => AppRouteTarget(
                id: AppRouteId.mobileSettingsPlugins,
              ).push(context),
            )
          : null,
      drawerEnableOpenDragGesture: enableOverviewDrawerDrag,
      background: const AppMobileAmbientBackdrop(child: SizedBox.expand()),
      onDestinationSelected: (index) {
        navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        );
      },
      child: navigationShell,
    );
  }
}

class _LocalizedMobileSubpageShell extends StatelessWidget {
  const _LocalizedMobileSubpageShell({
    required this.title,
    required this.defaultLocation,
    required this.fallbackPath,
    required this.currentPath,
    required this.chrome,
    required this.child,
  });

  final AppRouteTitle title;
  final String defaultLocation;
  final String? fallbackPath;
  final String currentPath;
  final AppSubpageChrome chrome;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppMobileSubpageShell(
      title: title(AppLocalizations.of(context)),
      defaultLocation: defaultLocation,
      fallbackPath: fallbackPath,
      currentPath: currentPath,
      bodyPadding: chrome.bodyPadding,
      immersive: chrome.immersive,
      autoHideAppBar: chrome.autoHideAppBar,
      glassChrome: chrome.glassChrome,
      child: child,
    );
  }
}
