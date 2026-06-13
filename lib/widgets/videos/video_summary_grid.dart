import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/videos/video_summary_card.dart';

/// 视频卡片网格：骨架屏 → 错误态 → 空态 → 卡片，复用影片网格的列数自适应逻辑。
class VideoSummaryGrid extends StatelessWidget {
  const VideoSummaryGrid({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onVideoTap,
    this.onVideoMenuRequest,
    this.emptyMessage = '当前没有可展示的视频数据。',
    this.placeholderCount = 8,
  });

  final List<VideoItemListItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<VideoItemListItemDto>? onVideoTap;
  final void Function(VideoItemListItemDto video, Offset globalPosition)?
  onVideoMenuRequest;
  final String emptyMessage;
  final int placeholderCount;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _VideoSummaryGridLayout(
        children: List<Widget>.generate(
          placeholderCount,
          (index) => _VideoSummaryCardSkeleton(
            key: Key('video-summary-card-skeleton-$index'),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return AppEmptyState(message: errorMessage!);
    }

    if (items.isEmpty) {
      return AppEmptyState(message: emptyMessage);
    }

    return _VideoSummaryGridLayout(
      children: items
          .map(
            (video) => VideoSummaryCard(
              video: video,
              onTap: onVideoTap == null ? null : () => onVideoTap!(video),
              onRequestMenu: onVideoMenuRequest == null
                  ? null
                  : (globalPosition) => onVideoMenuRequest!(video, globalPosition),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _VideoSummaryGridLayout extends StatelessWidget {
  const _VideoSummaryGridLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing.md;
        final componentTokens = context.appComponentTokens;
        final columns = _resolveColumnCount(
          width: constraints.maxWidth,
          spacing: spacing,
          targetWidth: componentTokens.movieCardTargetWidth,
        );

        return GridView.builder(
          key: const Key('video-summary-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: componentTokens.movieCardAspectRatio,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }

  int _resolveColumnCount({
    required double width,
    required double spacing,
    required double targetWidth,
  }) {
    final columns = ((width + spacing) / (targetWidth + spacing)).floor();
    return math.max(2, math.min(6, columns));
  }
}

class _VideoSummaryCardSkeleton extends StatelessWidget {
  const _VideoSummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: context.appComponentTokens.movieCardAspectRatio,
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.appColors.surfaceMuted),
        ),
      ),
    );
  }
}
