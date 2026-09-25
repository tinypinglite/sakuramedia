import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/page_cache_keys.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_provider.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_scope.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_content.dart';

class MobileCatalogSearchPage extends ConsumerStatefulWidget {
  const MobileCatalogSearchPage({
    super.key,
    required this.initialQuery,
    this.initialUseOnlineSearch = false,
  });

  final String initialQuery;
  final bool initialUseOnlineSearch;

  @override
  ConsumerState<MobileCatalogSearchPage> createState() =>
      _MobileCatalogSearchPageState();
}

class _MobileCatalogSearchPageState
    extends ConsumerState<MobileCatalogSearchPage>
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
          key: mobileSearchPageCacheKey(_scope.cacheKey),
          resolveLinks: () {
            final link =
                ref.read(catalogSearchProvider(_scope).notifier).cacheLink;
            return link == null ? const [] : [link];
          },
        );
    // 见桌面版同名处理：延到 post-frame，避免路由跳转触发 Riverpod
    // 「build 中修改 provider」断言。
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
  void didUpdateWidget(covariant MobileCatalogSearchPage oldWidget) {
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
            useOnlineSearch:
                ref.read(catalogSearchProvider(_scope)).useOnlineSearch,
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
    return CatalogSearchContent(
      state: searchState,
      textController: _textController,
      tabController: _tabController,
      useOnlineSearch: searchState.useOnlineSearch,
      onOnlineSearchToggle:
          (value) => ref
              .read(catalogSearchProvider(_scope).notifier)
              .setUseOnlineSearch(value),
      onSubmitSearch: _submitSearch,
      onTabSelected:
          (index) => ref
              .read(catalogSearchProvider(_scope).notifier)
              .setActiveKind(_kindForIndex(index)),
      onMovieTap: (movie) {
        MobileMovieDetailRouteData(
          movieNumber: movie.movieNumber,
        ).push(context);
      },
      onMovieMenuRequest:
          (movie, globalPosition) => requestMovieCollectionMenu(
            context,
            movie.movieNumber,
            globalPosition,
            isSubscribed: movie.isSubscribed,
          ),
      onMovieToggleCollectionType: _hoverFeatureActions.toggleCollectionType,
      onMovieBlacklist: _hoverFeatureActions.blacklist,
      onActorTap:
          (actor) =>
              MobileActorDetailRouteData(actorId: actor.id).push(context),
      onMovieSubscriptionTap:
          (movie) => _toggleMovieSubscription(movie.movieNumber),
      onActorSubscriptionTap: (actor) => _toggleActorSubscription(actor.id),
      onFallbackToOnlineSearch: () {
        ref
            .read(catalogSearchProvider(_scope).notifier)
            .setUseOnlineSearch(true);
        _submitSearch();
      },
    );
  }

  CatalogSearchKind _kindForIndex(int index) {
    return index == 0 ? CatalogSearchKind.movies : CatalogSearchKind.actors;
  }

  void _submitSearch() {
    final submittedQuery = _textController.text;
    final trimmedQuery = submittedQuery.trim();
    final routeLocation = _routeLocationFor(
      query: submittedQuery,
      useOnlineSearch: ref.read(catalogSearchProvider(_scope)).useOnlineSearch,
    );
    final currentLocation = _currentRouteLocationOr(routeLocation);

    if (trimmedQuery.isEmpty && currentLocation == mobileSearchPath) {
      return;
    }

    if (routeLocation == currentLocation &&
        widget.initialUseOnlineSearch ==
            ref.read(catalogSearchProvider(_scope)).useOnlineSearch) {
      unawaited(
        ref
            .read(catalogSearchProvider(_scope).notifier)
            .submit(
              submittedQuery,
              useOnlineSearch:
                  ref.read(catalogSearchProvider(_scope)).useOnlineSearch,
            ),
      );
      return;
    }

    if (trimmedQuery.isEmpty) {
      MobileSearchRouteData(
        useOnlineSearch:
            ref.read(catalogSearchProvider(_scope)).useOnlineSearch,
      ).push(context);
      return;
    }
    MobileSearchQueryRouteData(
      query: trimmedQuery,
      useOnlineSearch: ref.read(catalogSearchProvider(_scope)).useOnlineSearch,
    ).push(context);
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(catalogSearchProvider(_scope).notifier)
        .toggleMovieSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  Future<void> _toggleActorSubscription(int actorId) async {
    final result = await ref
        .read(catalogSearchProvider(_scope).notifier)
        .toggleActorSubscription(actorId);
    if (!mounted) {
      return;
    }
    showActorSubscriptionFeedback(result);
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
    if (trimmed.isEmpty) {
      return MobileSearchRouteData(useOnlineSearch: useOnlineSearch).location;
    }
    return MobileSearchQueryRouteData(
      query: trimmed,
      useOnlineSearch: useOnlineSearch,
    ).location;
  }
}
