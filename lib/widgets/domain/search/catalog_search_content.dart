import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_summary_grid.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_field.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_stream_status_card.dart';

class CatalogSearchContent extends StatelessWidget {
  const CatalogSearchContent({
    super.key,
    required this.state,
    required this.textController,
    required this.tabController,
    required this.useOnlineSearch,
    required this.onOnlineSearchToggle,
    required this.onSubmitSearch,
    required this.onTabSelected,
    required this.onMovieTap,
    this.onMovieMenuRequest,
    this.onMovieToggleCollectionType,
    this.onMovieBlacklist,
    required this.onActorTap,
    required this.onMovieSubscriptionTap,
    required this.onActorSubscriptionTap,
    this.onFallbackToOnlineSearch,
  });

  final CatalogSearchState state;
  final TextEditingController textController;
  final TabController tabController;
  final bool useOnlineSearch;
  final ValueChanged<bool> onOnlineSearchToggle;
  final VoidCallback onSubmitSearch;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<MovieListItemDto> onMovieTap;
  final void Function(MovieListItemDto movie, Offset globalPosition)?
  onMovieMenuRequest;

  /// 悬停动作行「标记为合集 / 单体」回调；为 `null` 时该按钮不显示。
  final ValueChanged<MovieListItemDto>? onMovieToggleCollectionType;

  /// 悬停动作行「屏蔽影片」回调；为 `null` 或影片已订阅时该按钮不显示。
  final ValueChanged<MovieListItemDto>? onMovieBlacklist;
  final ValueChanged<ActorListItemDto> onActorTap;
  final ValueChanged<MovieListItemDto> onMovieSubscriptionTap;
  final ValueChanged<ActorListItemDto> onActorSubscriptionTap;
  final VoidCallback? onFallbackToOnlineSearch;

  @override
  Widget build(BuildContext context) {
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
              controller: textController,
              hintText: l10n.widgetSearchHint,
              showOnlineToggle: true,
              isOnlineSearchEnabled: useOnlineSearch,
              onOnlineSearchToggle: onOnlineSearchToggle,
              onSubmitted: (_) => onSubmitSearch(),
              onSearchTap: onSubmitSearch,
            ),
            SizedBox(height: context.appSpacing.xs),
            AppTabBar(
              controller: tabController,
              onTap: onTabSelected,
              tabs: [
                Tab(text: l10n.widgetSearchTabMovies),
                Tab(text: l10n.widgetSearchTabActors),
              ],
            ),
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
            _buildBodySliver(context),
            ...bottomSafeAreaSliver(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBodySliver(BuildContext context) {
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
          onRetry: onSubmitSearch,
          retryKey: const Key('catalog-search-retry'),
        ),
      );
    }

    switch (state.activeKind) {
      case CatalogSearchKind.movies:
        if (!state.isOnlineSearchActive &&
            state.movieResults.isEmpty &&
            onFallbackToOnlineSearch != null) {
          if (!state.isLoading) {
            return _buildLocalEmptyFallback(
              context,
              l10n.widgetSearchLocalNoMovies,
            );
          }
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
            onMovieTap: onMovieTap,
            onMovieMenuRequest: onMovieMenuRequest,
            onMovieToggleCollectionType: onMovieToggleCollectionType,
            onMovieBlacklist: onMovieBlacklist,
            onMovieSubscriptionTap: onMovieSubscriptionTap,
            isMovieSubscriptionUpdating: (movie) =>
                state.isMovieSubscriptionUpdating(movie.movieNumber),
          ),
        );
      case CatalogSearchKind.actors:
        if (!state.isOnlineSearchActive &&
            state.actorResults.isEmpty &&
            onFallbackToOnlineSearch != null) {
          if (!state.isLoading) {
            return _buildLocalEmptyFallback(
              context,
              l10n.widgetSearchLocalNoActors,
            );
          }
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
            onActorTap: onActorTap,
            onActorSubscriptionTap: onActorSubscriptionTap,
            isActorSubscriptionUpdating: (actor) =>
                state.isActorSubscriptionUpdating(actor.id),
          ),
        );
    }
  }

  Widget _buildLocalEmptyFallback(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context);
    return SliverToBoxAdapter(
      child: AppEmptyState(
        message: message,
        icon: Icons.travel_explore,
        onRetry: onFallbackToOnlineSearch!,
        retryLabel: l10n.widgetSearchFetchExternal,
        retryKey: const Key('catalog-search-online-fallback'),
      ),
    );
  }
}
