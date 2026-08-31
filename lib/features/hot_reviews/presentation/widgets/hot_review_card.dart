import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

const double _hotReviewCardHeight = 150;

class HotReviewSliver extends StatelessWidget {
  const HotReviewSliver({
    super.key,
    required this.items,
    required this.isLoading,
    required this.minColumns,
    required this.maxColumns,
    required this.targetCardWidth,
    this.onItemTap,
  });

  final List<HotReviewListItemDto> items;
  final bool isLoading;
  final int minColumns;
  final int maxColumns;
  final double targetCardWidth;
  final ValueChanged<HotReviewListItemDto>? onItemTap;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardSliver<HotReviewListItemDto>(
      gridKey: const Key('hot-review-grid'),
      items: items,
      isLoading: isLoading,
      placeholderCount: 8,
      minColumns: minColumns,
      maxColumns: maxColumns,
      targetColumnWidth: targetCardWidth,
      mainAxisExtent: _hotReviewCardHeight,
      skeletonBuilder:
          (context, index) => HotReviewCardSkeleton(
            key: Key('hot-review-card-skeleton-$index'),
          ),
      itemBuilder:
          (context, item, index) => HotReviewCard(
            item: item,
            onTap: onItemTap == null ? null : () => onItemTap!(item),
          ),
    );
  }
}

class HotReviewCard extends StatelessWidget {
  const HotReviewCard({super.key, required this.item, this.onTap});

  final HotReviewListItemDto item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    final reviewDate =
        item.createdAt == null
            ? '--/--/--'
            : DateFormat('yy/MM/dd').format(item.createdAt!.toLocal());
    final username = item.username.trim().isEmpty ? '匿名用户' : item.username;
    final content = item.content.trim().isEmpty ? '暂无评论内容' : item.content;
    final compactTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s10,
      weight: AppTextWeight.regular,
      tone: AppTextTone.secondary,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('hot-review-card-${item.reviewId}'),
        borderRadius: context.appRadius.lgBorder,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: context.appRadius.lgBorder,
            border: Border.all(color: colors.borderSubtle),
            boxShadow: context.appShadows.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width:
                    _hotReviewCardHeight * componentTokens.movieCardAspectRatio,
                child: ColoredBox(
                  key: Key('hot-review-card-cover-pane-${item.reviewId}'),
                  color: colors.surfaceMuted,
                  child: SizedBox.expand(
                    child: MaskedImage(
                      key: Key('hot-review-card-cover-${item.reviewId}'),
                      url: item.movie.coverImage?.bestAvailableUrl ?? '',
                      fit: BoxFit.cover,
                      visibleWidthFactor:
                          context
                              .appComponentTokens
                              .movieCardCoverVisibleWidthFactor,
                      visibleAlignment: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(spacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        key: Key('hot-review-card-meta-row-${item.reviewId}'),
                        children: [
                          Expanded(
                            child: Text(
                              '$username · $reviewDate',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: compactTextStyle,
                            ),
                          ),
                          SizedBox(width: spacing.xs),
                          HotReviewMetaStat(
                            icon: Icons.thumb_up_alt_rounded,
                            color: colors.movieCardPlayableBadgeBackground,
                            value: '${item.likeCount}',
                          ),
                          SizedBox(width: spacing.xs),
                          HotReviewMetaStat(
                            icon: Icons.star_rounded,
                            color: colors.movieDetailScoreIcon,
                            value: '${item.score}',
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.sm),
                      Expanded(
                        child: SizedBox(
                          key: Key(
                            'hot-review-card-content-box-${item.reviewId}',
                          ),
                          child: SingleChildScrollView(
                            key: Key(
                              'hot-review-card-content-scroll-${item.reviewId}',
                            ),
                            padding: EdgeInsets.zero,
                            child: Text(
                              content,
                              style: resolveAppTextStyle(
                                context,
                                size: AppTextSize.s14,
                                tone: AppTextTone.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HotReviewMetaStat extends StatelessWidget {
  const HotReviewMetaStat({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    final compactTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s10,
      weight: AppTextWeight.regular,
      tone: AppTextTone.secondary,
    );
    final compactIconSize =
        (resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ).fontSize ??
            context.appComponentTokens.iconSizeXs) +
        1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compactIconSize, color: color),
        SizedBox(width: context.appSpacing.xs),
        Text(value, style: compactTextStyle),
      ],
    );
  }
}

class HotReviewCardSkeleton extends StatelessWidget {
  const HotReviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _hotReviewCardHeight * componentTokens.movieCardAspectRatio,
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.surfaceMuted),
              child: SizedBox.expand(
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: context.appComponentTokens.iconSize2xl,
                    color: context.appTextPalette.muted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HotReviewSkeletonLine(width: 112),
                  SizedBox(height: spacing.xs),
                  HotReviewSkeletonLine(width: 168),
                  SizedBox(height: spacing.sm),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceMuted,
                        borderRadius: context.appRadius.smBorder,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(spacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const HotReviewSkeletonLine(
                              width: double.infinity,
                            ),
                            SizedBox(height: spacing.xs),
                            const HotReviewSkeletonLine(
                              width: double.infinity,
                            ),
                            SizedBox(height: spacing.xs),
                            const HotReviewSkeletonLine(width: 144),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HotReviewSkeletonLine extends StatelessWidget {
  const HotReviewSkeletonLine({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: context.appColors.borderSubtle,
        borderRadius: context.appRadius.smBorder,
      ),
    );
  }
}
