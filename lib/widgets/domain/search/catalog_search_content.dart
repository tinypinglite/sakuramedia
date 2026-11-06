import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/search/presentation/providers/catalog_search_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_summary_grid.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_field.dart';
import 'package:sakuramedia/widgets/domain/search/catalog_search_stream_status_card.dart';

class CatalogSearchContent extends StatelessWidget {
  const CatalogSearchContent({
    super.key,
    required this.surfaceColor,
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

  final Color surfaceColor;
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

    if (state.isLoading) {
      return const SliverToBoxAdapter(child: _CatalogSearchLoadingIndicator());
    }

    switch (state.activeKind) {
      case CatalogSearchKind.movies:
        if (!state.isOnlineSearchActive &&
            state.movieResults.isEmpty &&
            onFallbackToOnlineSearch != null) {
          return _buildLocalEmptyFallback(l10n.widgetSearchLocalNoMovies);
        }
        return MovieSummarySliver(
          items: state.movieResults,
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
        );
      case CatalogSearchKind.actors:
        if (!state.isOnlineSearchActive &&
            state.actorResults.isEmpty &&
            onFallbackToOnlineSearch != null) {
          return _buildLocalEmptyFallback(l10n.widgetSearchLocalNoActors);
        }
        return ActorSummarySliver(
          items: state.actorResults,
          emptyMessage: state.isOnlineSearchActive
              ? l10n.widgetSearchOnlineNoActor
              : l10n.widgetSearchLocalNoMatchingActors,
          onActorTap: onActorTap,
          onActorSubscriptionTap: onActorSubscriptionTap,
          isActorSubscriptionUpdating: (actor) =>
              state.isActorSubscriptionUpdating(actor.id),
        );
    }
  }

  Widget _buildLocalEmptyFallback(String message) {
    return SliverToBoxAdapter(
      child: _CatalogSearchOnlineFallback(
        message: message,
        onPressed: onFallbackToOnlineSearch!,
      ),
    );
  }
}

class _CatalogSearchLoadingIndicator extends StatelessWidget {
  const _CatalogSearchLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 240,
      child: Center(
        child: SizedBox(
          key: Key('catalog-search-loading-indicator'),
          width: 24,
          height: 24,
          child: CircularProgressIndicator.adaptive(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _CatalogSearchOnlineFallback extends StatelessWidget {
  const _CatalogSearchOnlineFallback({
    required this.message,
    required this.onPressed,
  });

  final String message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.xxl,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore,
              size: context.appComponentTokens.iconSize4xl,
              color: resolveAppTextToneColor(context, AppTextTone.secondary),
            ),
            SizedBox(height: spacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
            SizedBox(height: spacing.lg),
            AppButton(
              key: const Key('catalog-search-online-fallback'),
              variant: AppButtonVariant.primary,
              label: AppLocalizations.of(context).widgetSearchFetchExternal,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}
