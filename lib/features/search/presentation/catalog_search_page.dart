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
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actors/actor_summary_grid.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/search/catalog_search_field.dart';
import 'package:sakuramedia/widgets/search/catalog_search_stream_status_card.dart';

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
  void didUpdateWidget(covariant CatalogSearchPage oldWidget) {
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
        return Material(
          color: context.appColors.surfaceElevated,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CatalogSearchField(
                  key: const Key('catalog-search-page-field'),
                  fieldKey: const Key('catalog-search-page-input'),
                  searchButtonKey: const Key('catalog-search-page-submit'),
                  onlineToggleKey: const Key(
                    'catalog-search-page-online-toggle',
                  ),
                  controller: _textController,
                  hintText: '找影片',
                  showOnlineToggle: true,
                  isOnlineSearchEnabled: _useOnlineSearch,
                  onOnlineSearchToggle:
                      (value) => setState(() => _useOnlineSearch = value),
                  onSubmitted: (_) => _submitSearch(),
                  onSearchTap: _submitSearch,
                ),
                if (_controller.streamStatus != null) ...[
                  SizedBox(height: context.appSpacing.md),
                  CatalogSearchStreamStatusCard(
                    status: _controller.streamStatus!,
                  ),
                ],
                SizedBox(height: context.appSpacing.lg),
                AppTabBar(
                  controller: _tabController,
                  onTap: (index) {
                    _controller.setActiveKind(_kindForIndex(index));
                  },
                  tabs: const [Tab(text: '影片'), Tab(text: '女优')],
                ),
                SizedBox(height: context.appSpacing.lg),
                _buildBody(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.query.isEmpty && !_controller.isLoading) {
      return const AppEmptyState(message: '输入关键词开始搜索');
    }

    if (_controller.errorMessage != null) {
      return AppEmptyState(message: _controller.errorMessage!);
    }

    if (_controller.isLoading) {
      return const _CatalogSearchLoadingIndicator();
    }

    switch (_controller.activeKind) {
      case CatalogSearchKind.movies:
        return MovieSummaryGrid(
          items: _controller.movieResults,
          isLoading: false,
          emptyMessage:
              _controller.isOnlineSearchActive
                  ? '在线源未找到该番号或未成功入库'
                  : '本地库中没有匹配该番号的影片。',
          onMovieTap:
              (movie) => context.go(
                '$desktopMoviesPath/${Uri.encodeComponent(movie.movieNumber)}',
                extra: _currentSearchPath,
              ),
          onMovieSubscriptionTap:
              (movie) => _toggleMovieSubscription(movie.movieNumber),
          isMovieSubscriptionUpdating:
              (movie) =>
                  _controller.isMovieSubscriptionUpdating(movie.movieNumber),
        );
      case CatalogSearchKind.actors:
        return ActorSummaryGrid(
          items: _controller.actorResults,
          isLoading: false,
          emptyMessage:
              _controller.isOnlineSearchActive
                  ? '在线源未找到匹配女优'
                  : '本地库中没有匹配该关键词的女优记录。',
          onActorTap:
              (actor) => context.go(
                '$desktopActorsPath/${actor.id}',
                extra: _currentSearchPath,
              ),
          onActorSubscriptionTap: (actor) => _toggleActorSubscription(actor.id),
          isActorSubscriptionUpdating:
              (actor) => _controller.isActorSubscriptionUpdating(actor.id),
        );
    }
  }

  String get _currentSearchPath => buildDesktopSearchRoutePath(
    _controller.query.isEmpty ? widget.initialQuery : _controller.query,
  );

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
    final routePath = buildDesktopSearchRoutePath(submittedQuery);
    final currentPath = GoRouterState.of(context).uri.path;

    if (trimmedQuery.isNotEmpty &&
        routePath == currentPath &&
        widget.initialUseOnlineSearch == _useOnlineSearch) {
      unawaited(
        _controller.submit(submittedQuery, useOnlineSearch: _useOnlineSearch),
      );
      return;
    }

    context.go(
      routePath,
      extra: DesktopSearchRouteState(
        fallbackPath: widget.fallbackPath,
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

class _CatalogSearchLoadingIndicator extends StatelessWidget {
  const _CatalogSearchLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Center(
        child: SizedBox(
          key: const Key('catalog-search-loading-indicator'),
          width: 24,
          height: 24,
          child: const CircularProgressIndicator.adaptive(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
