import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_controller.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_page_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/desktop_routes.dart';
import 'package:sakuramedia/widgets/search/catalog_search_content.dart';

class CatalogSearchPage extends StatefulWidget {
  const CatalogSearchPage({
    super.key,
    required this.initialQuery,
    this.fallbackPath,
    this.initialUseOnlineSearch = false,
  });

  final String initialQuery;
  final String? fallbackPath;
  final bool initialUseOnlineSearch;

  @override
  State<CatalogSearchPage> createState() => _CatalogSearchPageState();
}

class _CatalogSearchPageState extends State<CatalogSearchPage>
    with SingleTickerProviderStateMixin {
  late final CachedPageStateHandle<CatalogSearchPageStateEntry>
  _pageStateHandle;
  late final TextEditingController _textController;
  late final TabController _tabController;

  CatalogSearchPageStateEntry get _pageState => _pageStateHandle.value;
  CatalogSearchController get _controller => _pageState.controller;

  @override
  void initState() {
    super.initState();
    _pageStateHandle = obtainCachedPageState<CatalogSearchPageStateEntry>(
      context,
      key: desktopSearchPageStateKey(_resolveCachePath()),
      create:
          () => CatalogSearchPageStateEntry(
            moviesApi: context.read<MoviesApi>(),
            actorsApi: context.read<ActorsApi>(),
            subscriptionChangeNotifier:
                context.read<MovieSubscriptionChangeNotifier>(),
          ),
    );

    _pageState.bootstrap(
      initialQuery: widget.initialQuery,
      initialUseOnlineSearch: widget.initialUseOnlineSearch,
    );
    _controller.addListener(_handleControllerChanged);
    _textController = TextEditingController(text: _pageState.queryText)
      ..addListener(_handleTextChanged);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _controller.activeKind == CatalogSearchKind.movies ? 0 : 1,
    );
  }

  @override
  void didUpdateWidget(covariant CatalogSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final useOnlineSearchChanged =
        oldWidget.initialUseOnlineSearch != widget.initialUseOnlineSearch;
    if (useOnlineSearchChanged) {
      _pageState.useOnlineSearch = widget.initialUseOnlineSearch;
    }
    if (!useOnlineSearchChanged &&
        oldWidget.initialQuery == widget.initialQuery) {
      return;
    }
    _pageState.queryText = widget.initialQuery;
    _textController.text = widget.initialQuery;
    if (widget.initialQuery.trim().isEmpty) {
      return;
    }
    _controller.submit(
      widget.initialQuery,
      useOnlineSearch: _pageState.useOnlineSearch,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _pageStateHandle.dispose();
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CatalogSearchContent(
          controller: _controller,
          textController: _textController,
          tabController: _tabController,
          useOnlineSearch: _pageState.useOnlineSearch,
          onOnlineSearchToggle:
              (value) => setState(() => _pageState.useOnlineSearch = value),
          onSubmitSearch: _submitSearch,
          onTabSelected: (index) {
            _controller.setActiveKind(_kindForIndex(index));
          },
          onMovieTap:
              (movie) => context.pushDesktopMovieDetail(
                movieNumber: movie.movieNumber,
              ),
          onActorTap:
              (actor) => context.pushDesktopActorDetail(actorId: actor.id),
          onMovieSubscriptionTap:
              (movie) => _toggleMovieSubscription(movie.movieNumber),
          onActorSubscriptionTap: (actor) => _toggleActorSubscription(actor.id),
        );
      },
    );
  }

  CatalogSearchKind _kindForIndex(int index) {
    return index == 0 ? CatalogSearchKind.movies : CatalogSearchKind.actors;
  }

  void _handleTextChanged() {
    _pageState.queryText = _textController.text;
  }

  void _handleControllerChanged() {
    final nextIndex =
        _controller.activeKind == CatalogSearchKind.movies ? 0 : 1;
    if (_tabController.index != nextIndex) {
      _tabController.animateTo(nextIndex);
    }
  }

  void _submitSearch() {
    final submittedQuery = _textController.text;
    final trimmedQuery = submittedQuery.trim();
    final routeLocation = _routeLocationFor(
      query: submittedQuery,
      useOnlineSearch: _pageState.useOnlineSearch,
    );
    final currentLocation = _currentRouteLocationOr(routeLocation);

    if (trimmedQuery.isNotEmpty &&
        routeLocation == currentLocation &&
        _pageState.useOnlineSearch == widget.initialUseOnlineSearch) {
      unawaited(
        _controller.submit(
          submittedQuery,
          useOnlineSearch: _pageState.useOnlineSearch,
        ),
      );
      return;
    }

    context.pushDesktopSearch(
      query: submittedQuery,
      useOnlineSearch: _pageState.useOnlineSearch,
    );
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await _controller.toggleMovieSubscription(
      movieNumber: movieNumber,
    );
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  Future<void> _toggleActorSubscription(int actorId) async {
    final result = await _controller.toggleActorSubscription(actorId: actorId);
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
      return DesktopSearchRouteData(useOnlineSearch: useOnlineSearch).location;
    }
    return DesktopSearchQueryRouteData(
      query: trimmed,
      useOnlineSearch: useOnlineSearch,
    ).location;
  }
}
