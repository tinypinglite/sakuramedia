import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/image_search/presentation/image_search_filter_state.dart';
import 'package:sakuramedia/features/image_search/presentation/pages/shared/image_search_draft_page.dart';
import 'package:sakuramedia/features/image_search/presentation/providers/image_search_state.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_page.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/definitions/query_params.dart';

final AppRouteDefinition desktopSearchRoute = AppRouteDefinition(
  id: AppRouteId.desktopSearch,
  name: 'desktop-search-empty',
  platform: AppPlatform.desktop,
  path: desktopSearchPath,
  scope: AppRouteScope.shellLevel,
  queryParameters: searchQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(searchQueryParameters, state);
    return CatalogSearchPage(
      initialQuery: '',
      mobile: false,
      initialUseOnlineSearch: query.boolean('useOnlineSearch'),
    );
  },
  title: (l10n, [_]) => l10n.routeSearchTitle,
  backTarget: (state) => desktopOverviewPath,
);

final AppRouteDefinition desktopSearchQueryRoute = AppRouteDefinition(
  id: AppRouteId.desktopSearchQuery,
  name: 'desktop-search',
  platform: AppPlatform.desktop,
  path: '$desktopSearchPath/:query',
  scope: AppRouteScope.shellLevel,
  queryParameters: searchQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(searchQueryParameters, state);
    return CatalogSearchPage(
      initialQuery: state.pathParameters['query']!,
      mobile: false,
      initialUseOnlineSearch: query.boolean('useOnlineSearch'),
    );
  },
  title: (l10n, [state]) {
    final value = state?.pathParameters['query'];
    if (value == null || value.isEmpty) {
      return l10n.routeSearchTitle;
    }
    try {
      return Uri.decodeComponent(value);
    } on ArgumentError {
      return value;
    }
  },
  backTarget: (state) => desktopOverviewPath,
);

final AppRouteDefinition desktopImageSearchRoute = AppRouteDefinition(
  id: AppRouteId.desktopImageSearch,
  name: 'desktop-image-search',
  platform: AppPlatform.desktop,
  path: desktopImageSearchPath,
  scope: AppRouteScope.shellLevel,
  queryParameters: imageSearchQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(imageSearchQueryParameters, state);
    return ImageSearchDraftPage(
      platform: AppPlatform.desktop,
      draftId: query.string('draftId'),
      fallbackPath: AppRouteExtra.fallbackPathOf(
        state.extra,
        platform: AppPlatform.desktop,
      ),
      currentMovieNumber: query.string('currentMovieNumber'),
      initialCurrentMovieScope: _parseScope(query.string('currentMovieScope')),
      initialInputKind: _parseInputKind(query.string('mode')),
    );
  },
  title: (l10n, [_]) => l10n.routeImageSearchTitle,
  backTarget: (state) => desktopOverviewPath,
);

final AppRouteDefinition mobileSearchRoute = AppRouteDefinition(
  id: AppRouteId.mobileSearch,
  name: 'mobile-search-empty',
  platform: AppPlatform.mobile,
  path: mobileSearchPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  queryParameters: searchQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(searchQueryParameters, state);
    return CatalogSearchPage(
      initialQuery: '',
      mobile: true,
      initialUseOnlineSearch: query.boolean('useOnlineSearch'),
    );
  },
  title: (l10n, [_]) => l10n.routeSearchTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileSearchQueryRoute = AppRouteDefinition(
  id: AppRouteId.mobileSearchQuery,
  name: 'mobile-search',
  platform: AppPlatform.mobile,
  path: '$mobileSearchPath/:query',
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  queryParameters: searchQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(searchQueryParameters, state);
    return CatalogSearchPage(
      initialQuery: state.pathParameters['query']!,
      mobile: true,
      initialUseOnlineSearch: query.boolean('useOnlineSearch'),
    );
  },
  title: (l10n, [_]) => l10n.routeSearchTitle,
  backTarget: (state) => mobileOverviewPath,
);

final AppRouteDefinition mobileImageSearchRoute = AppRouteDefinition(
  id: AppRouteId.mobileImageSearch,
  name: 'mobile-image-search',
  platform: AppPlatform.mobile,
  path: mobileImageSearchPath,
  scope: AppRouteScope.outsideShell,
  transition: AppRouteTransition.cupertino,
  subpageChrome: const AppSubpageChrome(),
  queryParameters: imageSearchQueryParameters,
  pageBuilder: (context, state) {
    final query = AppQueryValues(imageSearchQueryParameters, state);
    return ImageSearchDraftPage(
      platform: AppPlatform.mobile,
      draftId: query.string('draftId'),
      currentMovieNumber: query.string('currentMovieNumber'),
      initialCurrentMovieScope: _parseScope(query.string('currentMovieScope')),
      initialInputKind: _parseInputKind(query.string('mode')),
    );
  },
  title: (l10n, [_]) => l10n.routeImageSearchTitle,
  backTarget: (state) => mobileOverviewPath,
);

ImageSearchCurrentMovieScope _parseScope(String? value) {
  return ImageSearchCurrentMovieScope.values.firstWhere(
    (scope) => scope.name == value,
    orElse: () => ImageSearchCurrentMovieScope.all,
  );
}

ImageSearchInputKind _parseInputKind(String? value) {
  return ImageSearchInputKind.values.firstWhere(
    (kind) => kind.name == value,
    orElse: () => ImageSearchInputKind.image,
  );
}
