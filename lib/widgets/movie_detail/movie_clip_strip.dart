import 'package:flutter/material.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/clips/clip_grid_card.dart';

/// 影片详情页「切片」区块：横向滚动的切片卡条，四态与「相似影片」一致
/// （骨架 → 错误+重试 → 空态 → 内容），内层复用 [ClipGridCard] 完整菜单。
class MovieClipStrip extends StatelessWidget {
  const MovieClipStrip({
    super.key,
    required this.clips,
    required this.isLoading,
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
  final ValueChanged<MediaClipDto> onPlayClip;
  final ValueChanged<MediaClipDto> onRenameClip;
  final ValueChanged<MediaClipDto> onDeleteClip;
  final ValueChanged<MediaClipDto> onAddClipToCollection;

  @override
  Widget build(BuildContext context) {
    final cardHeight =
        context.appComponentTokens.movieDetailPlotThumbnailHeight;
    final cardWidth = cardHeight * (16 / 9);

    if (isLoading) {
      return _MovieClipStripScroller(
        scrollViewKey: const Key('movie-clip-strip-loading'),
        children: List<Widget>.generate(
          4,
          (index) => _MovieClipSkeleton(
            key: Key('movie-clip-strip-skeleton-$index'),
            height: cardHeight,
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return _MovieClipFeedback(
        feedbackKey: const Key('movie-clip-strip-error'),
        message: errorMessage!,
        actionLabel: '重试',
        onAction: onRetry,
      );
    }

    if (clips.isEmpty) {
      return const _MovieClipFeedback(
        feedbackKey: Key('movie-clip-strip-empty'),
        message: '暂无切片',
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
            TextButton(
              key: const Key('movie-clip-strip-retry'),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _MovieClipSkeleton extends StatelessWidget {
  const _MovieClipSkeleton({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: height * (16 / 9),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.mdBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.appColors.surfaceMuted),
        ),
      ),
    );
  }
}
