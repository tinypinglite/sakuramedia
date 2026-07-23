import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_filter_drawer.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_list_page_state.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/notifiers/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_tab_header.dart';

class MobileMoviesPage extends StatefulWidget {
  const MobileMoviesPage({super.key});

  @override
  State<MobileMoviesPage> createState() => _MobileMoviesPageState();
}

class _MobileMoviesPageState extends State<MobileMoviesPage> {
  late final CachedPageStateHandle<MovieListPageStateEntry> _pageStateHandle;

  MovieListPageStateEntry get _pageState => _pageStateHandle.value;

  @override
  void initState() {
    super.initState();
    _pageStateHandle = obtainCachedPageState<MovieListPageStateEntry>(
      context,
      key: mobileMoviesPageStateKey(),
      create:
          () => MovieListPageStateEntry(
            moviesApi: context.read<MoviesApi>(),
            subscriptionChangeNotifier:
                context.read<MovieSubscriptionChangeNotifier>(),
          ),
    );
  }

  @override
  void dispose() {
    _pageStateHandle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MovieListContent(
      pageState: _pageState,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('mobile-movies-page'),
      totalKey: const Key('mobile-movies-page-total'),
      sectionSpacing: context.appSpacing.md,
      onMovieTap:
          (context, movieNumber) => MobileMovieDetailRouteData(
            movieNumber: movieNumber,
          ).push(context),
      headerBuilder: _buildMobileHeader,
      bodyBuilder:
          (context, scrollController, sliver, onRefresh) =>
              AppAdaptiveRefreshScrollView(
                onRefresh: onRefresh!,
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: <Widget>[sliver],
              ),
      enableRefresh: true,
      onRefreshFailure: (_) => showToast('刷新失败'),
    );
  }

  Widget _buildMobileHeader(BuildContext context, MovieListHeaderArgs args) {
    return AppMobileTabHeader(
      filterButtonKey: const Key('mobile-movies-filter-button'),
      filterTooltip: '筛选',
      onFilterTap: () => _openFilterDrawer(context, args),
      chips: [
        AppMobileTabChip(
          key: const Key('movies-filter-preset-all'),
          label: '全部',
          isSelected: args.filterState.isDefault,
          onTap: args.onReset,
        ),
        for (final preset in MovieFilterPreset.values)
          AppMobileTabChip(
            key: Key('movies-filter-preset-${preset.key}'),
            label: preset.label,
            isSelected: args.filterState.matchesPreset(preset),
            onTap: () => args.onApply(preset.filterState),
          ),
      ],
    );
  }

  Future<void> _openFilterDrawer(
    BuildContext context,
    MovieListHeaderArgs args,
  ) async {
    final next = await showMobileMovieFilterDrawer(
      context,
      current: args.filterState,
    );
    if (next != null) {
      args.onApply(next);
    }
  }
}
