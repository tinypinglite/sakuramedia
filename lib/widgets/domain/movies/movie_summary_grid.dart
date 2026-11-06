import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card_wiring.dart';

/// 累计分页影片列表使用的 Sliver 网格版本。
class MovieSummarySliver extends ConsumerWidget {
  const MovieSummarySliver({
    super.key,
    required this.items,
    this.errorMessage,
    this.onMovieTap,
    this.onMovieMenuRequest,
    this.onMovieSubscriptionTap,
    this.onMovieToggleCollectionType,
    this.onMovieBlacklist,
    this.isMovieSubscriptionUpdating,
    this.useDefaultSubscriptionActions = false,
    this.secondaryLabelForMovie,
    this.trailingLabelForMovie,
    this.emptyMessage,
    this.selectionMode = false,
    this.isMovieSelected,
    this.onMovieSelectedChanged,
  });

  final List<MovieListItemDto> items;
  final String? errorMessage;
  final ValueChanged<MovieListItemDto>? onMovieTap;
  final void Function(MovieListItemDto movie, Offset globalPosition)?
  onMovieMenuRequest;
  final ValueChanged<MovieListItemDto>? onMovieSubscriptionTap;

  /// 悬停动作行「标记为合集 / 单体」回调；为 `null` 时该按钮不显示。
  final ValueChanged<MovieListItemDto>? onMovieToggleCollectionType;

  /// 悬停动作行「屏蔽影片」回调；为 `null` 或影片已订阅时该按钮不显示。
  final ValueChanged<MovieListItemDto>? onMovieBlacklist;
  final bool Function(MovieListItemDto movie)? isMovieSubscriptionUpdating;

  /// 未传自定义订阅回调时，接入跨列表复用的默认订阅动作。
  final bool useDefaultSubscriptionActions;
  final String? Function(MovieListItemDto movie)? secondaryLabelForMovie;

  /// 收起态番号行右侧文案（如「总分 4.0」）；null 时不显示。
  final String? Function(MovieListItemDto movie)? trailingLabelForMovie;

  /// 空态文案；为 `null` 时使用当前语言的默认文案。
  final String? emptyMessage;

  final bool selectionMode;
  final bool Function(MovieListItemDto movie)? isMovieSelected;
  final void Function(MovieListItemDto movie, bool selected)?
  onMovieSelectedChanged;

  MovieSummaryCardWiring get _wiring => MovieSummaryCardWiring(
    onMovieTap: onMovieTap,
    onMovieMenuRequest: onMovieMenuRequest,
    onMovieSubscriptionTap: onMovieSubscriptionTap,
    onMovieToggleCollectionType: onMovieToggleCollectionType,
    onMovieBlacklist: onMovieBlacklist,
    isMovieSubscriptionUpdating: isMovieSubscriptionUpdating,
    useDefaultSubscriptionActions: useDefaultSubscriptionActions,
    secondaryLabelForMovie: secondaryLabelForMovie,
    trailingLabelForMovie: trailingLabelForMovie,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return AppAdaptiveCardSliver<MovieListItemDto>(
      gridKey: const Key('movie-summary-grid'),
      items: items,
      errorMessage: errorMessage,
      emptyMessage: emptyMessage ?? l10n.widgetMovieEmptyList,
      itemBuilder: (context, movie, index) => _wiring.build(
        context,
        ref,
        movie,
        selectionMode: selectionMode,
        isSelected: isMovieSelected?.call(movie) ?? false,
        onSelectedChanged: onMovieSelectedChanged == null
            ? null
            : (selected) => onMovieSelectedChanged!(movie, selected),
      ),
    );
  }
}
