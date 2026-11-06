import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/features/clips/presentation/clip_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_grid_card.dart';

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
        child: _MovieClipStripScroller(
          scrollViewKey: const Key('movie-clip-strip-loading'),
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
      return _MovieClipFeedback(
        feedbackKey: const Key('movie-clip-strip-error'),
        message: errorMessage!,
        actionLabel: AppLocalizations.of(context).commonRetry,
        onAction: onRetry,
      );
    }

    if (clips.isEmpty) {
      return _MovieClipFeedback(
        feedbackKey: const Key('movie-clip-strip-empty'),
        message: AppLocalizations.of(context).movieWidgetNoClips,
      );
    }

    return _MovieClipStripScroller(
      scrollViewKey: const Key('movie-clip-strip-scroll'),
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

class _MovieClipStripScroller extends StatelessWidget {
  const _MovieClipStripScroller({required this.children, this.scrollViewKey});

  final List<Widget> children;
  final Key? scrollViewKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing.sm;
    return SingleChildScrollView(
      key: scrollViewKey,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(children.length, (index) {
          return Padding(
            padding: EdgeInsets.only(
              right: index == children.length - 1 ? 0 : spacing,
            ),
            child: children[index],
          );
        }),
      ),
    );
  }
}

class _MovieClipFeedback extends StatelessWidget {
  const _MovieClipFeedback({
    required this.message,
    this.feedbackKey,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Key? feedbackKey;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: feedbackKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.md,
        vertical: context.appSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.movieDetailEmptyBackground,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(width: context.appSpacing.sm),
            AppTextButton(
              key: const Key('movie-clip-strip-retry'),
              label: actionLabel!,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
