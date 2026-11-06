import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/recent_views/data/dto/recent_view_dto.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/widgets/recent_view_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';

/// 「最近浏览」更多页的四态网格（sliver 版）：加载 / 错误 / 空 / 内容。
///
/// 影片与女优混排进同一张自适应海报卡网格，卡片比例与「最近添加」页一致；
/// 加载态用占位卡渲染真实网格再骨架化。
class RecentViewsGridSliver extends ConsumerWidget {
  const RecentViewsGridSliver({
    super.key,
    required this.onRetry,
    required this.onMovieTap,
    required this.onActorTap,
  });

  final VoidCallback onRetry;
  final ValueChanged<String> onMovieTap;
  final ValueChanged<int> onActorTap;

  static const int _placeholderCount = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recentViewsProvider);
    final entries = async.value;
    final l10n = AppLocalizations.of(context);
    if (async.hasError && entries == null) {
      return SliverToBoxAdapter(
        child: AppErrorState(
          key: const Key('recent-views-error'),
          title: l10n.baseActionFailed,
          message: l10n.recentLoadFailed,
          onRetry: onRetry,
          retryKey: const Key('recent-views-retry-button'),
        ),
      );
    }
    final isInitialLoading = async.isLoading && entries == null;
    final grid = AppSkeletonizer.sliver(
      enabled: isInitialLoading,
      child: AppAdaptiveCardSliver<RecentViewEntryDto>(
        gridKey: const Key('recent-views-grid'),
        items: isInitialLoading
            ? _placeholderEntries(_placeholderCount)
            : entries ?? const <RecentViewEntryDto>[],
        emptyMessage: l10n.recentEmpty,
        itemBuilder: (context, entry, index) => RecentViewCard(
          entry: entry,
          onMovieTap: onMovieTap,
          onActorTap: onActorTap,
        ),
      ),
    );
    if (!async.hasError || entries == null) {
      return grid;
    }
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(bottom: context.appSpacing.md),
            child: AppInlineErrorBanner(
              key: const Key('recent-views-refresh-error'),
              message: l10n.recentRefreshFailed,
              onRetry: () async => onRetry(),
              retryKey: const Key('recent-views-refresh-retry'),
            ),
          ),
        ),
        grid,
      ],
    );
  }
}

List<RecentViewEntryDto> _placeholderEntries(int count) {
  return [
    for (final movie in movieListItemPlaceholders(count: count))
      RecentViewEntryDto(
        entityType: RecentViewEntityType.movie,
        viewedAt: DateTime(2026, 1, 1),
        movie: movie,
      ),
  ];
}
