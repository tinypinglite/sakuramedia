import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranked_movie_list_item_dto.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';

/// 累计分页排行榜使用的 Sliver 网格版本。
class RankedMovieSummarySliver extends StatelessWidget {
  const RankedMovieSummarySliver({
    super.key,
    required this.items,
    this.errorMessage,
    this.onMovieTap,
    this.onMovieMenuRequest,
    this.onMovieSubscriptionTap,
    this.onMovieToggleCollectionType,
    this.onMovieBlacklist,
    this.isMovieSubscriptionUpdating,
    this.emptyMessage = '暂无榜单数据',
    this.selectionMode = false,
    this.isMovieSelected,
    this.onMovieSelectedChanged,
  });

  final List<RankedMovieListItemDto> items;
  final String? errorMessage;
  final ValueChanged<RankedMovieListItemDto>? onMovieTap;
  final void Function(RankedMovieListItemDto movie, Offset globalPosition)?
  onMovieMenuRequest;
  final ValueChanged<RankedMovieListItemDto>? onMovieSubscriptionTap;

  /// 悬停动作行「标记为合集 / 单体」回调；为 `null` 时该按钮不显示。
  ///
  /// 悬停动作行回调统一收 [MovieListItemDto]（榜单条目内部转成通用 DTO 再回调），
  /// 与 `MovieSummaryGrid` 的悬停回调保持一致，页面可直接复用同一组接线。
  final ValueChanged<MovieListItemDto>? onMovieToggleCollectionType;

  /// 悬停动作行「屏蔽影片」回调；为 `null` 或影片已订阅时该按钮不显示。
  final ValueChanged<MovieListItemDto>? onMovieBlacklist;
  final bool Function(RankedMovieListItemDto movie)?
  isMovieSubscriptionUpdating;
  final String emptyMessage;

  final bool selectionMode;
  final bool Function(RankedMovieListItemDto movie)? isMovieSelected;
  final void Function(RankedMovieListItemDto movie, bool selected)?
  onMovieSelectedChanged;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardSliver<RankedMovieListItemDto>(
      gridKey: const Key('ranked-movie-summary-grid'),
      items: items,
      errorMessage: errorMessage,
      emptyMessage: emptyMessage,
      itemBuilder:
          (context, item, index) => MovieSummaryCard(
            movie: item.toMovieListItem(),
            rank: item.rank,
            onTap: onMovieTap == null ? null : () => onMovieTap!(item),
            onRequestMenu:
                onMovieMenuRequest == null
                    ? null
                    : (globalPosition) =>
                        onMovieMenuRequest!(item, globalPosition),
            onSubscriptionTap:
                onMovieSubscriptionTap == null
                    ? null
                    : () => onMovieSubscriptionTap!(item),
            onToggleCollectionType:
                onMovieToggleCollectionType == null
                    ? null
                    : () => onMovieToggleCollectionType!(item.toMovieListItem()),
            onBlacklist:
                onMovieBlacklist == null
                    ? null
                    : () => onMovieBlacklist!(item.toMovieListItem()),
            isSubscriptionUpdating:
                isMovieSubscriptionUpdating?.call(item) ?? false,
            selectionMode: selectionMode,
            isSelected: isMovieSelected?.call(item) ?? false,
            onSelectedChanged:
                onMovieSelectedChanged == null
                    ? null
                    : (selected) => onMovieSelectedChanged!(item, selected),
          ),
    );
  }
}
