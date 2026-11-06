import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_cover_hover_info.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_cover_card.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_action_trigger.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

/// 图片搜索结果卡：整卡即封面，收起态不铺文字；桌面悬停时底部渐显
/// 「番号 + 相似度」与整行动作按钮（播放 / 相似图片 / 保存到本地 / 影片详情，
/// 按回调是否为空显隐），与全站封面卡片的悬停范式统一。右下角常驻相似度角标。
///
/// 标记 / 加入合集等需要匹配时刻的动作仍走右键 / 长按菜单。
class ImageSearchResultCard extends StatelessWidget {
  const ImageSearchResultCard({
    super.key,
    required this.item,
    this.onTap,
    this.onRequestMenu,
    this.onSearchSimilar,
    this.onSaveToLocal,
    this.onPlay,
    this.onMovieDetail,
  });

  final ImageSearchResultItemDto item;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onRequestMenu;

  /// 悬停动作行里的「相似图片」；为 `null` 时不显示按钮。
  final VoidCallback? onSearchSimilar;

  /// 悬停动作行里的「保存到本地」；为 `null` 时不显示按钮。
  final VoidCallback? onSaveToLocal;

  /// 悬停动作行里的播放主按钮；为 `null` 或来源媒体缺失时不显示按钮。
  final VoidCallback? onPlay;

  /// 悬停动作行里的「影片详情」；为 `null` 时不显示按钮。
  final VoidCallback? onMovieDetail;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final scoreText = formatImageSearchScore(item.score);

    final card = AppCoverCard(
      cover: MaskedImage(url: item.image.origin, fit: BoxFit.cover),
      infoBuilder: (context) => _buildHoverInfo(context, scoreText),
      overlays: [
        Positioned(
          right: spacing.sm,
          bottom: spacing.sm,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: context.appRadius.smBorder,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.sm,
                  vertical: spacing.xs,
                ),
                child: Text(
                  scoreText,
                  style: resolveCoverOverlayTextStyle(
                    context,
                    size: AppTextSize.s12,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    final surface = AppInteractiveSurface(
      key: Key('image-search-result-card-${item.resultImageId}'),
      onTap: onTap,
      child: card,
    );

    final requestMenu = onRequestMenu;
    if (requestMenu == null) {
      return surface;
    }
    return AppImageActionTrigger(onRequestMenu: requestMenu, child: surface);
  }

  /// 悬停展开内容：单行「番号 + 相似度」，下方一整行动作按钮。
  Widget _buildHoverInfo(BuildContext context, String scoreText) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final searchSimilar = onSearchSimilar;
    final saveToLocal = onSaveToLocal;
    final play = onPlay;
    final movieDetail = onMovieDetail;
    final resultImageId = item.resultImageId;
    final actions = <Widget>[
      if (play != null && item.mediaId > 0)
        AppCoverHoverActionButton(
          key: Key('image-search-result-card-play-$resultImageId'),
          icon: Icons.play_arrow_rounded,
          onTap: play,
          primary: true,
          tooltip: l10n.imageSearchPlay,
        ),
      if (searchSimilar != null)
        AppCoverHoverActionButton(
          key: Key('image-search-result-card-search-similar-$resultImageId'),
          icon: Icons.image_search_outlined,
          onTap: searchSimilar,
          tooltip: l10n.imageSearchSimilarAction,
        ),
      if (saveToLocal != null)
        AppCoverHoverActionButton(
          key: Key('image-search-result-card-save-$resultImageId'),
          icon: Icons.download_outlined,
          onTap: saveToLocal,
          tooltip: l10n.imageSearchSaveToLocal,
        ),
      if (movieDetail != null)
        AppCoverHoverActionButton(
          key: Key('image-search-result-card-movie-$resultImageId'),
          icon: Icons.info_outline_rounded,
          onTap: movieDetail,
          tooltip: l10n.imageSearchMovieDetail,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCoverHoverInfoRow(
          label: item.movieNumber,
          meta: l10n.imageSearchSimilarityLabel(scoreText),
        ),
        if (actions.isNotEmpty) ...[
          SizedBox(height: spacing.sm),
          AppCoverHoverActionBar(actions: actions),
        ],
      ],
    );
  }
}

String formatImageSearchScore(double score) {
  return formatAppPercent(score);
}
