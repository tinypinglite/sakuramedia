import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clip_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_grid_card.dart';

import 'movie_detail_strip.dart';

/// 影片详情页「切片」区块：横向滚动的切片卡条，四态与「相似影片」一致
/// （骨架 → 错误+重试 → 空态 → 内容），内层复用 [ClipGridCard] 完整菜单。
class MovieClipStrip extends StatelessWidget {
  const MovieClipStrip({
    super.key,
    required this.clips,
    required this.isLoading,
    required this.onOpenClipActions,
    required this.onPlayClip,
    required this.onRenameClip,
    required this.onDeleteClip,
    required this.onAddClipToCollection,
    this.errorMessage,
    this.onRetry,
  });

  final List<MediaClipDto> clips;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  /// 点击卡片主体：打开切片动作面板（不直接播放）。
  final ValueChanged<MediaClipDto> onOpenClipActions;

  /// 悬停面板的播放主按钮：直接播放。
  final ValueChanged<MediaClipDto> onPlayClip;
  final ValueChanged<MediaClipDto> onRenameClip;
  final ValueChanged<MediaClipDto> onDeleteClip;
  final ValueChanged<MediaClipDto> onAddClipToCollection;

  @override
  Widget build(BuildContext context) {
    final cardHeight =
        context.appComponentTokens.movieDetailPlotThumbnailHeight;
    final cardWidth = cardHeight * (16 / 9);

    if (isLoading && clips.isEmpty) {
      // loading 用占位切片渲染真实卡片，由 [AppSkeletonizer] 灰化。
      return AppSkeletonizer(
        enabled: true,
        child: MovieDetailStripScroller(
          scrollViewKey: const Key('movie-clip-strip-loading'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final clip in clipPlaceholders(count: 4))
              SizedBox(
                width: cardWidth,
                child: ClipGridCard(
                  key: Key('movie-clip-strip-card-${clip.clipId}'),
                  clip: clip,
                  onTap: () {},
                ),
              ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return MovieDetailStripFeedback(
        feedbackKey: const Key('movie-clip-strip-error'),
        message: errorMessage!,
        actionLabel: AppLocalizations.of(context).commonRetry,
        onAction: onRetry,
        retryKey: const Key('movie-clip-strip-retry'),
      );
    }

    if (clips.isEmpty) {
      return MovieDetailStripFeedback(
        feedbackKey: const Key('movie-clip-strip-empty'),
        message: AppLocalizations.of(context).movieWidgetNoClips,
      );
    }

    return MovieDetailStripScroller(
      scrollViewKey: const Key('movie-clip-strip-scroll'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: clips
          .map(
            (clip) => SizedBox(
              width: cardWidth,
              child: ClipGridCard(
                key: Key('movie-clip-strip-card-${clip.clipId}'),
                clip: clip,
                onTap: () => onOpenClipActions(clip),
                onPlay: () => onPlayClip(clip),
                onRename: () => onRenameClip(clip),
                onDelete: () => onDeleteClip(clip),
                onAddToCollection: () => onAddClipToCollection(clip),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}
