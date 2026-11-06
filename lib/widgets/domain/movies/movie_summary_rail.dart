import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_list_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_scroll_rail.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card_wiring.dart';

/// 影片摘要的横向 rail 版本：首页/发现预览区专用。
///
/// 卡宽按平台对齐既有规格：移动端取 [AppComponentTokens.mobileLatestMovieCardWidth]
/// （与首页「最近添加」逐像素一致），桌面端取 [AppComponentTokens.movieCardTargetWidth]
/// 的 0.75（与影片详情「相似影片」一致）。三态顺序与 [MovieSummarySliver] 相同：
/// 错误 → 空态 → 内容；loading 由调用方传占位项并外包 `AppSkeletonizer`。
class MovieSummaryRail extends ConsumerWidget {
  const MovieSummaryRail({
    super.key,
    required this.items,
    this.errorMessage,
    this.onErrorRetry,
    this.onMovieTap,
    this.onMovieMenuRequest,
    this.onMovieSubscriptionTap,
    this.onMovieToggleCollectionType,
    this.onMovieBlacklist,
    this.isMovieSubscriptionUpdating,
    this.useDefaultSubscriptionActions = false,
    this.secondaryLabelForMovie,
    this.emptyMessage,
    this.scrollViewKey = const Key('movie-summary-rail'),
  });

  final List<MovieListItemDto> items;
  final String? errorMessage;

  /// 错误态的重试回调；为 `null` 时错误态不带重试按钮。
  final VoidCallback? onErrorRetry;
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

  /// 空态文案；为 `null` 时使用当前语言的默认文案。
  final String? emptyMessage;
  final Key scrollViewKey;

  /// 桌面 rail 卡宽相对 [AppComponentTokens.movieCardTargetWidth] 的系数；
  /// 与影片详情「相似影片」保持同一密度。
  static const double _desktopCardWidthFactor = 0.75;

  MovieSummaryCardWiring get _wiring => MovieSummaryCardWiring(
    onMovieTap: onMovieTap,
    onMovieMenuRequest: onMovieMenuRequest,
    onMovieSubscriptionTap: onMovieSubscriptionTap,
    onMovieToggleCollectionType: onMovieToggleCollectionType,
    onMovieBlacklist: onMovieBlacklist,
    isMovieSubscriptionUpdating: isMovieSubscriptionUpdating,
    useDefaultSubscriptionActions: useDefaultSubscriptionActions,
    secondaryLabelForMovie: secondaryLabelForMovie,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (errorMessage != null) {
      return AppEmptyState(message: errorMessage!, onRetry: onErrorRetry);
    }
    if (items.isEmpty) {
      return AppEmptyState(
        message:
            emptyMessage ?? AppLocalizations.of(context).widgetMovieEmptyList,
      );
    }

    final tokens = context.appComponentTokens;
    final isMobile = AppPlatformScope.maybeOf(context) == AppPlatform.mobile;
    final cardWidth = isMobile
        ? tokens.mobileLatestMovieCardWidth
        : tokens.movieCardTargetWidth * _desktopCardWidthFactor;
    final cardHeight = cardWidth / tokens.movieCardAspectRatio;

    return AppScrollRail(
      height: cardHeight,
      itemCount: items.length,
      scrollViewKey: scrollViewKey,
      itemBuilder: (context, index) {
        final movie = items[index];
        return SizedBox(
          width: cardWidth,
          child: _wiring.build(context, ref, movie),
        );
      },
    );
  }
}
