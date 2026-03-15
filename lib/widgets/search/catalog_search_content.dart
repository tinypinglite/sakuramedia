import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/features/search/presentation/catalog_search_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actors/actor_summary_grid.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/navigation/app_tab_bar.dart';
import 'package:sakuramedia/widgets/search/catalog_search_field.dart';
import 'package:sakuramedia/widgets/search/catalog_search_stream_status_card.dart';

class CatalogSearchContent extends StatelessWidget {
  const CatalogSearchContent({
    super.key,
    required this.controller,
    required this.textController,
    required this.tabController,
    required this.useOnlineSearch,
    required this.onOnlineSearchToggle,
    required this.onSubmitSearch,
    required this.onTabSelected,
    required this.onMovieTap,
    required this.onActorTap,
    required this.onMovieSubscriptionTap,
    required this.onActorSubscriptionTap,
  });

  final CatalogSearchController controller;
  final TextEditingController textController;
  final TabController tabController;
  final bool useOnlineSearch;
  final ValueChanged<bool> onOnlineSearchToggle;
  final VoidCallback onSubmitSearch;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<MovieListItemDto> onMovieTap;
  final ValueChanged<ActorListItemDto> onActorTap;
  final ValueChanged<MovieListItemDto> onMovieSubscriptionTap;
  final ValueChanged<ActorListItemDto> onActorSubscriptionTap;

  @override
  Widget build(BuildContext context) {
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
              onlineToggleKey: const Key('catalog-search-page-online-toggle'),
              controller: textController,
              hintText: '找影片',
              showOnlineToggle: true,
              isOnlineSearchEnabled: useOnlineSearch,
              onOnlineSearchToggle: onOnlineSearchToggle,
              onSubmitted: (_) => onSubmitSearch(),
              onSearchTap: onSubmitSearch,
            ),
            if (controller.streamStatus != null) ...[
              SizedBox(height: context.appSpacing.md),
              CatalogSearchStreamStatusCard(status: controller.streamStatus!),
            ],
            SizedBox(height: context.appSpacing.xs),
            AppTabBar(
              controller: tabController,
              onTap: onTabSelected,
              tabs: const [Tab(text: '影片'), Tab(text: '女优')],
            ),
            SizedBox(height: context.appSpacing.lg),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (controller.query.isEmpty && !controller.isLoading) {
      return const AppEmptyState(message: '输入关键词开始搜索');
    }

    if (controller.errorMessage != null) {
      return AppEmptyState(message: controller.errorMessage!);
    }

    if (controller.isLoading) {
      return const _CatalogSearchLoadingIndicator();
    }

    switch (controller.activeKind) {
      case CatalogSearchKind.movies:
        return MovieSummaryGrid(
          items: controller.movieResults,
          isLoading: false,
          emptyMessage:
              controller.isOnlineSearchActive
                  ? '在线源未找到该番号或未成功入库'
                  : '本地库中没有匹配该番号的影片。',
          onMovieTap: onMovieTap,
          onMovieSubscriptionTap: onMovieSubscriptionTap,
          isMovieSubscriptionUpdating:
              (movie) =>
                  controller.isMovieSubscriptionUpdating(movie.movieNumber),
        );
      case CatalogSearchKind.actors:
        return ActorSummaryGrid(
          items: controller.actorResults,
          isLoading: false,
          emptyMessage:
              controller.isOnlineSearchActive
                  ? '在线源未找到匹配女优'
                  : '本地库中没有匹配该关键词的女优记录。',
          onActorTap: onActorTap,
          onActorSubscriptionTap: onActorSubscriptionTap,
          isActorSubscriptionUpdating:
              (actor) => controller.isActorSubscriptionUpdating(actor.id),
        );
    }
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
