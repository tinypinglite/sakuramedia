import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/desktop_search_route_state.dart';
import 'package:sakuramedia/widgets/search/catalog_search_content.dart';

class MobileCatalogSearchPage extends StatefulWidget {
  const MobileCatalogSearchPage({
    super.key,
    required this.initialQuery,
    this.initialUseOnlineSearch = false,
  });

  final String initialQuery;
  final bool initialUseOnlineSearch;

  @override
  State<MobileCatalogSearchPage> createState() =>
      _MobileCatalogSearchPageState();
}

class _MobileCatalogSearchPageState extends State<MobileCatalogSearchPage>
    with SingleTickerProviderStateMixin {
  late final CatalogSearchController _controller;
  late final TextEditingController _textController;
  late final TabController _tabController;
  late bool _useOnlineSearch;

  @override
  void initState() {
    super.initState();
    _controller = CatalogSearchController(
      moviesApi: context.read<MoviesApi>(),
      actorsApi: context.read<ActorsApi>(),
    )..addListener(_handleControllerChanged);
    _textController = TextEditingController(text: widget.initialQuery);
    _tabController = TabController(length: 2, vsync: this);
    _useOnlineSearch = widget.initialUseOnlineSearch;
    if (widget.initialQuery.trim().isNotEmpty) {
      _controller.submit(
        widget.initialQuery,
        useOnlineSearch: _useOnlineSearch,
      );
    }
  }

  @override
  void didUpdateWidget(covariant MobileCatalogSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final useOnlineSearchChanged =
        oldWidget.initialUseOnlineSearch != widget.initialUseOnlineSearch;
    if (useOnlineSearchChanged) {
      _useOnlineSearch = widget.initialUseOnlineSearch;
    }
    if (!useOnlineSearchChanged &&
        oldWidget.initialQuery == widget.initialQuery) {
      return;
    }
    _textController.text = widget.initialQuery;
    if (widget.initialQuery.trim().isEmpty) {
      return;
    }
    _controller.submit(widget.initialQuery, useOnlineSearch: _useOnlineSearch);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleControllerChanged)
      ..dispose();
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
          useOnlineSearch: _useOnlineSearch,
          onOnlineSearchToggle:
              (value) => setState(() => _useOnlineSearch = value),
          onSubmitSearch: _submitSearch,
          onTabSelected: (index) {
            _controller.setActiveKind(_kindForIndex(index));
          },
          onMovieTap: (movie) {
            final fallbackPath = GoRouterState.of(context).uri.path;
            context.push(
              buildMobileMovieDetailRoutePath(movie.movieNumber),
              extra: fallbackPath,
            );
          },
          onActorTap: (actor) {
            final fallbackPath = GoRouterState.of(context).uri.path;
            context.push(
              buildMobileActorDetailRoutePath(actor.id),
              extra: fallbackPath,
            );
          },
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
    final routePath = buildMobileSearchRoutePath(submittedQuery);
    final currentPath = GoRouterState.of(context).uri.path;

    if (trimmedQuery.isEmpty && currentPath == mobileSearchPath) {
      return;
    }

    if (routePath == currentPath &&
        widget.initialUseOnlineSearch == _useOnlineSearch) {
      unawaited(
        _controller.submit(submittedQuery, useOnlineSearch: _useOnlineSearch),
      );
      return;
    }

    context.push(
      routePath,
      extra: DesktopSearchRouteState(
        fallbackPath: mobileOverviewPath,
        useOnlineSearch: _useOnlineSearch,
      ),
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
}
