import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_filter_drawer.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_provider.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_scope.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_state.dart';
import 'package:sakuramedia/features/search/presentation/widgets/actor_candidate_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_sort_menu_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_summary_grid.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_field.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_stream_status_card.dart';

class CatalogSearchPage extends ConsumerStatefulWidget {
  const CatalogSearchPage({
    super.key,
    required this.initialQuery,
    required this.mobile,
    this.initialUseOnlineSearch = false,
  });

  final String initialQuery;
  final bool mobile;
  final bool initialUseOnlineSearch;

  @override
  ConsumerState<CatalogSearchPage> createState() => _CatalogSearchPageState();
}

class _CatalogSearchPageState extends ConsumerState<CatalogSearchPage>
    with SingleTickerProviderStateMixin {
  late final CatalogSearchScope _scope;
  late final RiverpodPageHandle _pageCacheHandle;
  late final TextEditingController _textController;
  late final TabController _tabController;

  MovieCardHoverFeatureActions get _hoverFeatureActions =>
      movieCardHoverFeatureActions(context);

  @override
  void initState() {
    super.initState();
    _scope = CatalogSearchScope(_resolveCachePath());
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: _pageCacheKey(_scope.cacheKey),
          resolveLinks: () {
            final link = ref
                .read(catalogSearchProvider(_scope).notifier)
                .cacheLink;
            return link == null ? const [] : [link];
          },
        );
    // 延到 post-frame：路由从 sidebar 快捷入口跳转过来时，initState
    // 会在旧路由的 build 阶段执行；直接改 provider state 会触发
    // Riverpod 的「build 中修改 provider」断言。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(catalogSearchProvider(_scope).notifier)
          .bootstrap(
            initialQuery: widget.initialQuery,
            initialUseOnlineSearch: widget.initialUseOnlineSearch,
          );
    });
    _textController = TextEditingController(text: widget.initialQuery);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex:
          ref.read(catalogSearchProvider(_scope)).activeKind ==
              CatalogSearchKind.movies
          ? 0
          : 1,
    );
  }

  @override
  void didUpdateWidget(covariant CatalogSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final useOnlineSearchChanged =
        oldWidget.initialUseOnlineSearch != widget.initialUseOnlineSearch;
    if (useOnlineSearchChanged) {
      ref
          .read(catalogSearchProvider(_scope).notifier)
          .setUseOnlineSearch(widget.initialUseOnlineSearch);
    }
    if (!useOnlineSearchChanged &&
        oldWidget.initialQuery == widget.initialQuery) {
      return;
    }
    _textController.text = widget.initialQuery;
    if (widget.initialQuery.trim().isEmpty) {
      return;
    }
    unawaited(
      ref
          .read(catalogSearchProvider(_scope).notifier)
          .submit(
            widget.initialQuery,
            useOnlineSearch: ref
                .read(catalogSearchProvider(_scope))
                .useOnlineSearch,
          ),
    );
  }

  @override
  void dispose() {
    _pageCacheHandle.release();
    _textController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(catalogSearchProvider(_scope));
    ref.listen(
      catalogSearchProvider(_scope).select((value) => value.activeKind),
      (_, nextKind) {
        final nextIndex = nextKind == CatalogSearchKind.movies ? 0 : 1;
        if (_tabController.index != nextIndex) {
          _tabController.animateTo(nextIndex);
        }
      },
    );
    return _buildContent(context, searchState);
  }

  Widget _buildContent(BuildContext context, CatalogSearchState state) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: AppFixedHeaderLayout(
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CatalogSearchField(
              key: const Key('catalog-search-page-field'),
              fieldKey: const Key('catalog-search-page-input'),
              searchButtonKey: const Key('catalog-search-page-submit'),
              onlineToggleKey: const Key('catalog-search-page-online-toggle'),
              controller: _textController,
              hintText: l10n.widgetSearchHint,
              showOnlineToggle: true,
              isOnlineSearchEnabled: state.useOnlineSearch,
              onOnlineSearchToggle: (value) => ref
                  .read(catalogSearchProvider(_scope).notifier)
                  .setUseOnlineSearch(value),
              onSubmitted: (_) => _submitSearch(),
              onSearchTap: _submitSearch,
            ),
            SizedBox(height: context.appSpacing.xs),
            _buildSearchToolbar(context, state, l10n),
            SizedBox(height: context.appSpacing.lg),
          ],
        ),
        child: CustomScrollView(
          slivers: [
            if (state.streamStatus != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: context.appSpacing.md),
                  child: CatalogSearchStreamStatusCard(
                    status: state.streamStatus!,
                  ),
                ),
              ),
            if (state.sourceErrors.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: context.appSpacing.md),
                  child: AppNoticeCard(
                    leadingIcon: Icons.warning_amber_rounded,
                    description: _sourceErrorsDescription(state, l10n),
                  ),
                ),
              ),
            _buildBodySliver(context, state),
            ...bottomSafeAreaSliver(context),
          ],
        ),
      ),
    );
  }

  String _sourceErrorsDescription(
    CatalogSearchState state,
    AppLocalizations l10n,
  ) {
    final names = state.sourceErrors
        .map((error) => error.sourceName)
        .join(', ');
    return l10n.searchSourceErrors(names);
  }

  Widget _buildBodySliver(BuildContext context, CatalogSearchState state) {
    final l10n = AppLocalizations.of(context);
    if (state.query.isEmpty && !state.isLoading) {
      return SliverToBoxAdapter(
        child: AppEmptyState(message: l10n.widgetSearchInputPrompt),
      );
    }

    if (state.errorMessage != null) {
      return SliverToBoxAdapter(
        child: AppEmptyState(
          message: state.errorMessage!,
          onRetry: _submitSearch,
          retryKey: const Key('catalog-search-retry'),
        ),
      );
    }

    switch (state.activeKind) {
      case CatalogSearchKind.movies:
        if (!state.isOnlineSearchActive &&
            state.movieResults.isEmpty &&
            !state.isLoading) {
          return _buildLocalEmptyFallback(
            context,
            l10n.widgetSearchLocalNoMovies,
          );
        }
        final movies = state.isLoading
            ? movieListItemPlaceholders(count: 12)
            : state.movieResults;
        return AppSkeletonizer.sliver(
          enabled: state.isLoading,
          child: MovieSummarySliver(
            items: movies,
            emptyMessage: state.isOnlineSearchActive
                ? l10n.widgetSearchOnlineNoMovie
                : l10n.widgetSearchLocalNoMatchingMovies,
            onMovieTap: (movie) {
              if (widget.mobile) {
                MobileRoutes.movieDetail(
                  movieNumber: movie.movieNumber,
                ).push(context);
              } else {
                DesktopRoutes.movieDetail(
                  movieNumber: movie.movieNumber,
                ).push(context);
              }
            },
            onMovieMenuRequest: (movie, globalPosition) =>
                requestMovieCollectionMenu(
                  context,
                  movie.movieNumber,
                  globalPosition,
                  isSubscribed: movie.isSubscribed,
                ),
            onMovieToggleCollectionType:
                _hoverFeatureActions.toggleCollectionType,
            onMovieBlacklist: _hoverFeatureActions.blacklist,
            onMovieSubscriptionTap: (movie) =>
                _toggleMovieSubscription(movie.movieNumber),
            isMovieSubscriptionUpdating: (movie) =>
                state.isMovieSubscriptionUpdating(movie.movieNumber),
          ),
        );
      case CatalogSearchKind.actors:
        if (state.isOnlineSearchActive) {
          if (state.isLoading) {
            return AppSkeletonizer.sliver(
              enabled: true,
              child: ActorSummarySliver(
                items: actorListItemPlaceholders(count: 8),
              ),
            );
          }
          if (state.actorCandidates.isEmpty) {
            return ActorSummarySliver(
              items: const [],
              emptyMessage: l10n.widgetSearchOnlineNoActor,
            );
          }
          return ActorCandidateSliver(
            candidates: state.actorCandidates,
            importingCandidateIds: state.importingActorCandidateIds,
            onOpenActor: (candidate) {
              final actorId = candidate.existingActorId;
              if (actorId != null) {
                _openActor(actorId);
              }
            },
            onImport: (candidate) =>
                unawaited(_importActorCandidate(candidate.candidateId)),
          );
        }
        if (!state.isOnlineSearchActive &&
            state.actorResults.isEmpty &&
            !state.isLoading) {
          return _buildLocalEmptyFallback(
            context,
            l10n.widgetSearchLocalNoActors,
          );
        }
        final actors = state.isLoading
            ? actorListItemPlaceholders(count: 12)
            : state.actorResults;
        return AppSkeletonizer.sliver(
          enabled: state.isLoading,
          child: ActorSummarySliver(
            items: actors,
            emptyMessage: state.isOnlineSearchActive
                ? l10n.widgetSearchOnlineNoActor
                : l10n.widgetSearchLocalNoMatchingActors,
            onActorTap: (actor) {
              _openActor(actor.id);
            },
            onActorSubscriptionTap: (actor) =>
                _toggleActorSubscription(actor.id),
            isActorSubscriptionUpdating: (actor) =>
                state.isActorSubscriptionUpdating(actor.id),
          ),
        );
    }
  }

  void _openActor(int actorId) {
    if (widget.mobile) {
      MobileRoutes.actorDetail(actorId: actorId).push(context);
    } else {
      DesktopRoutes.actorDetail(actorId: actorId).push(context);
    }
  }

  Future<void> _importActorCandidate(String candidateId) async {
    try {
      final actor = await ref
          .read(catalogSearchProvider(_scope).notifier)
          .importActorCandidate(candidateId);
      if (!mounted || actor == null) {
        return;
      }
      showToast(
        AppLocalizations.of(context).actorCandidateImportSuccess,
        tone: AppToastTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.actorCandidateImportFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Widget _buildSearchToolbar(
    BuildContext context,
    CatalogSearchState state,
    AppLocalizations l10n,
  ) {
    final tabs = AppTabBar(
      controller: _tabController,
      tabAlignment: widget.mobile ? TabAlignment.start : null,
      onTap: (index) => ref
          .read(catalogSearchProvider(_scope).notifier)
          .setActiveKind(_kindForIndex(index)),
      tabs: [
        Tab(text: l10n.widgetSearchTabMovies),
        Tab(text: l10n.widgetSearchTabActors),
      ],
    );
    final showMovieControls =
        state.activeKind == CatalogSearchKind.movies &&
        !state.isOnlineSearchActive &&
        !state.useOnlineSearch &&
        state.query.isNotEmpty;
    if (!showMovieControls) {
      return tabs;
    }

    final notifier = ref.read(catalogSearchProvider(_scope).notifier);
    if (widget.mobile) {
      return Row(
        children: [
          Expanded(child: tabs),
          SizedBox(width: context.appSpacing.xs),
          AppGlassFilterIconButton(
            key: const Key('catalog-search-filter-trigger'),
            summary: _movieFilterSummary(l10n, state),
            isActive: state.hasActiveMovieFilters,
            onPressed: () => unawaited(
              showMobileMovieFilterDrawer(
                context,
                current: state.movieFilter,
                onChanged: (value) =>
                    unawaited(notifier.applyMovieFilter(value)),
                resetBuilder: _resetSearchMovieFilter,
                isDefault: (value) =>
                    !CatalogSearchState.hasActiveMovieFilterConditions(value),
              ),
            ),
          ),
          SizedBox(width: context.appSpacing.xs),
          _buildMovieSortButton(l10n, state),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: tabs),
        SizedBox(width: context.appSpacing.md),
        AppGlassFilterPopover(
          panelKey: const Key('catalog-search-filter-panel'),
          triggerKey: const Key('catalog-search-filter-trigger'),
          label: _movieFilterSummary(l10n, state),
          tooltip: l10n.baseFilterTooltip,
          isDefault: !state.hasActiveMovieFilters,
          onReset: () => unawaited(
            notifier.applyMovieFilter(
              _resetSearchMovieFilter(state.movieFilter),
            ),
          ),
          scrollable: true,
          panelBuilder: (context) => MovieFilterSectionGroup(
            filterState: state.movieFilter,
            onChanged: (value) => unawaited(notifier.applyMovieFilter(value)),
          ),
        ),
        SizedBox(width: context.appSpacing.xs),
        AppGlassHeaderGroup(children: [_buildMovieSortButton(l10n, state)]),
      ],
    );
  }

  Widget _buildMovieSortButton(
    AppLocalizations l10n,
    CatalogSearchState state,
  ) {
    final notifier = ref.read(catalogSearchProvider(_scope).notifier);
    final statsEnabled = ref.watch(statsFeaturesEnabledProvider);
    final selectedField = visibleMovieSortField(
      state.movieSortField ?? MovieSortField.releaseDate,
      statsEnabled: statsEnabled,
    );
    return AppSortMenuButton<MovieSortField>(
      fields: visibleMovieSortFields(statsEnabled: statsEnabled),
      selectedField: state.movieSortField == null ? null : selectedField,
      allowDefaultOption: true,
      defaultOptionLabel: l10n.searchSortRelevance,
      fieldLabelBuilder: (value) => value.labelWith(l10n),
      onFieldChanged: (value) => unawaited(
        notifier.setMovieSort(
          field: value,
          direction: state.movieSortDirection,
        ),
      ),
      selectedDirection: state.movieSortDirection,
      onDirectionChanged: (value) => unawaited(
        notifier.setMovieSort(
          field: state.movieSortField == null ? null : selectedField,
          direction: value,
        ),
      ),
      directionVisibleWhen: (value) => value != null,
      useDrawer: widget.mobile,
      iconOnly: widget.mobile,
      glassGrouped: !widget.mobile,
      triggerKey: const Key('catalog-search-sort-trigger'),
      panelKey: const Key('catalog-search-sort-panel'),
      drawerKey: const Key('catalog-search-sort-drawer'),
      fieldKeyBuilder: (value) =>
          Key('catalog-search-sort-field-${value.name}'),
      directionKeyBuilder: (value) =>
          Key('catalog-search-sort-direction-${value.name}'),
      defaultOptionKey: const Key('catalog-search-sort-relevance'),
    );
  }

  String _movieFilterSummary(AppLocalizations l10n, CatalogSearchState state) {
    if (!state.hasActiveMovieFilters) {
      return l10n.baseFilterTooltip;
    }
    final filter = state.movieFilter;
    final labels = <String>[
      if (filter.status != MovieStatusFilter.all) filter.status.labelWith(l10n),
      if (filter.collectionType != MovieCollectionTypeFilter.all)
        filter.collectionType.labelWith(l10n),
      if (filter.numberSource != MovieNumberSourceFilter.all)
        filter.numberSource.labelWith(l10n),
      if (filter.years.isNotEmpty) movieFilterYearsLabel(filter.years, l10n),
      if (filter.hasInteractionRange)
        filter.interaction.localizedSummaryLabel(l10n),
      if (filter.hasActorAgeRange)
        movieActorAgeRangeLabel(filter.actorAgeMin, filter.actorAgeMax, l10n),
      if (filter.resolution != null) filter.resolution!.label,
    ];
    return labels.isEmpty ? l10n.baseFilterTooltip : labels.join(' · ');
  }

  MovieFilterState _resetSearchMovieFilter(MovieFilterState current) {
    return initialCatalogSearchMovieFilter.copyWith(
      sortField: current.sortField,
      sortDirection: current.sortDirection,
      dimensionSortId: current.dimensionSortId,
    );
  }

  Widget _buildLocalEmptyFallback(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context);
    return SliverToBoxAdapter(
      child: AppEmptyState(
        message: message,
        icon: Icons.travel_explore,
        onRetry: () {
          ref
              .read(catalogSearchProvider(_scope).notifier)
              .setUseOnlineSearch(true);
          _submitSearch();
        },
        retryLabel: l10n.widgetSearchFetchExternal,
        retryKey: const Key('catalog-search-online-fallback'),
      ),
    );
  }

  CatalogSearchKind _kindForIndex(int index) {
    return index == 0 ? CatalogSearchKind.movies : CatalogSearchKind.actors;
  }

  void _submitSearch() {
    final submittedQuery = _textController.text;
    final trimmedQuery = submittedQuery.trim();
    final searchState = ref.read(catalogSearchProvider(_scope));
    final useOnlineSearch = searchState.useOnlineSearch;
    final routeLocation = _routeLocationFor(
      query: submittedQuery,
      useOnlineSearch: useOnlineSearch,
    );
    final currentLocation = _currentRouteLocationOr(routeLocation);

    if (widget.mobile &&
        trimmedQuery.isEmpty &&
        currentLocation == mobileSearchPath) {
      return;
    }

    if (routeLocation == currentLocation &&
        widget.initialUseOnlineSearch == useOnlineSearch &&
        (widget.mobile || trimmedQuery.isNotEmpty)) {
      unawaited(
        ref
            .read(catalogSearchProvider(_scope).notifier)
            .submit(submittedQuery, useOnlineSearch: useOnlineSearch),
      );
      return;
    }

    if (widget.mobile) {
      MobileRoutes.search(
        query: trimmedQuery,
        useOnlineSearch: useOnlineSearch,
      ).push(context);
      return;
    }
    DesktopRoutes.search(
      query: submittedQuery,
      useOnlineSearch: useOnlineSearch,
    ).push(context);
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(catalogSearchProvider(_scope).notifier)
        .toggleMovieSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  Future<void> _toggleActorSubscription(int actorId) async {
    final result = await ref
        .read(catalogSearchProvider(_scope).notifier)
        .toggleActorSubscription(actorId);
    if (!mounted) {
      return;
    }
    showActorSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  String _pageCacheKey(String location) {
    return widget.mobile
        ? mobileSearchPageCacheKey(location)
        : desktopSearchPageCacheKey(location);
  }

  String _resolveCachePath() {
    return _currentRouteLocationOr(
      _routeLocationFor(
        query: widget.initialQuery,
        useOnlineSearch: widget.initialUseOnlineSearch,
      ),
    );
  }

  String _currentRouteLocationOr(String fallbackLocation) {
    try {
      return GoRouterState.of(context).uri.toString();
    } catch (_) {
      return fallbackLocation;
    }
  }

  String _routeLocationFor({
    required String query,
    required bool useOnlineSearch,
  }) {
    final trimmed = query.trim();
    if (widget.mobile) {
      return MobileRoutes.search(
        query: trimmed,
        useOnlineSearch: useOnlineSearch,
      ).location;
    }
    return DesktopRoutes.search(
      query: trimmed,
      useOnlineSearch: useOnlineSearch,
    ).location;
  }
}
