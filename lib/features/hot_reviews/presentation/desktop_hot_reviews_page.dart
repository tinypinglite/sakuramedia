import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_list_item_dto.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_period.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';
import 'package:sakuramedia/features/hot_reviews/presentation/paged_hot_review_controller.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

class DesktopHotReviewsPage extends StatefulWidget {
  const DesktopHotReviewsPage({super.key});

  @override
  State<DesktopHotReviewsPage> createState() => _DesktopHotReviewsPageState();
}

class _DesktopHotReviewsPageState extends State<DesktopHotReviewsPage> {
  late final PagedHotReviewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PagedHotReviewController(
      fetchPage:
          (page, pageSize, period) => context
              .read<HotReviewsApi>()
              .getHotReviews(period: period, page: page, pageSize: pageSize),
      pageSize: 20,
      loadMoreTriggerOffset: 300,
    );
    _controller.attachScrollListener();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        key: const Key('desktop-hot-reviews-scroll-view'),
        controller: _controller.scrollController,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final showFooter =
                _controller.items.isNotEmpty &&
                (_controller.isLoadingMore ||
                    _controller.loadMoreErrorMessage != null);
            return Column(
              key: const Key('desktop-hot-reviews-page'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFilterTotalHeader(
                  leading: Wrap(
                    spacing: context.appSpacing.xs,
                    runSpacing: context.appSpacing.xs,
                    children: [
                      for (final period in HotReviewPeriod.values)
                        AppButton(
                          key: Key(
                            'desktop-hot-reviews-period-${period.apiValue}',
                          ),
                          label: period.label,
                          size: AppButtonSize.small,
                          variant: AppButtonVariant.secondary,
                          isSelected: _controller.period == period,
                          onPressed:
                              () => unawaited(_controller.setPeriod(period)),
                        ),
                    ],
                  ),
                  totalText: '${_controller.total} 条',
                  totalKey: const Key('desktop-hot-reviews-page-total'),
                ),
                SizedBox(height: context.appSpacing.lg),
                _buildBody(context),
                if (showFooter) ...[
                  SizedBox(height: context.appSpacing.md),
                  AppPagedLoadMoreFooter(
                    isLoading: _controller.isLoadingMore,
                    errorMessage: _controller.loadMoreErrorMessage,
                    onRetry: _controller.loadMore,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isInitialLoading && _controller.items.isEmpty) {
      return const _HotReviewGrid(
        isLoading: true,
        items: <HotReviewListItemDto>[],
      );
    }

    if (_controller.initialErrorMessage != null && _controller.items.isEmpty) {
      return AppEmptyState(message: _controller.initialErrorMessage!);
    }

    if (_controller.items.isEmpty) {
      return const AppEmptyState(message: '暂无热评数据');
    }

    return _HotReviewGrid(
      isLoading: false,
      items: _controller.items,
      onItemTap: _openMovieDetail,
    );
  }

  void _openMovieDetail(HotReviewListItemDto item) {
    final movieNumber = item.movie.movieNumber.trim();
    if (movieNumber.isEmpty) {
      return;
    }
    context.pushDesktopMovieDetail(
      movieNumber: movieNumber,
      fallbackPath: desktopHotReviewsPath,
    );
  }
}

class _HotReviewGrid extends StatelessWidget {
  const _HotReviewGrid({
    required this.items,
    required this.isLoading,
    this.onItemTap,
  });

  final List<HotReviewListItemDto> items;
  final bool isLoading;
  final ValueChanged<HotReviewListItemDto>? onItemTap;

  @override
  Widget build(BuildContext context) {
    final children =
        isLoading
            ? List<Widget>.generate(
              8,
              (index) => _HotReviewCardSkeleton(
                key: Key('hot-review-card-skeleton-$index'),
              ),
            )
            : items
                .map(
                  (item) => _HotReviewCard(
                    item: item,
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
                )
                .toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing.md;
        final columns = _resolveColumns(
          width: constraints.maxWidth,
          spacing: spacing,
          targetWidth: 420,
        );
        return GridView.builder(
          key: const Key('hot-review-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            mainAxisExtent: 150,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }

  int _resolveColumns({
    required double width,
    required double spacing,
    required double targetWidth,
  }) {
    final columns = ((width + spacing) / (targetWidth + spacing)).floor();
    return math.max(2, math.min(4, columns));
  }
}

class _HotReviewCard extends StatelessWidget {
  const _HotReviewCard({required this.item, this.onTap});

  final HotReviewListItemDto item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final reviewDate =
        item.createdAt == null
            ? '--/--/--'
            : DateFormat('yy/MM/dd').format(item.createdAt!.toLocal());
    final username = item.username.trim().isEmpty ? '匿名用户' : item.username;
    final content = item.content.trim().isEmpty ? '暂无评论内容' : item.content;

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
            children: [
              Expanded(
                flex: 4,
                child: ColoredBox(
                  color: colors.surfaceMuted,
                  child: Padding(
                    padding: EdgeInsets.all(spacing.sm),
                    child: MaskedImage(
                      key: Key('hot-review-card-cover-${item.reviewId}'),
                      url: item.movie.coverImage?.bestAvailableUrl ?? '',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Padding(
                  padding: EdgeInsets.all(spacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: spacing.xs),
                      Wrap(
                        spacing: spacing.xs,
                        runSpacing: spacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            reviewDate,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                          _MetaStat(
                            icon: Icons.thumb_up_alt_rounded,
                            color: colors.movieCardPlayableBadgeBackground,
                            value: '${item.likeCount}',
                          ),
                          _MetaStat(
                            icon: Icons.star_rounded,
                            color: colors.movieDetailScoreIcon,
                            value: '${item.score}',
                          ),
                        ],
                      ),
                      SizedBox(height: spacing.sm),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.surfaceMuted,
                            borderRadius: context.appRadius.smBorder,
                          ),
                          child: SingleChildScrollView(
                            key: Key(
                              'hot-review-card-content-scroll-${item.reviewId}',
                            ),
                            padding: EdgeInsets.all(spacing.sm),
                            child: Text(
                              content,
                              style: Theme.of(context).textTheme.bodySmall,
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

class _MetaStat extends StatelessWidget {
  const _MetaStat({
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: context.appComponentTokens.iconSizeXs, color: color),
        SizedBox(width: context.appSpacing.xs),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _HotReviewCardSkeleton extends StatelessWidget {
  const _HotReviewCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(color: colors.surfaceMuted),
              child: SizedBox.expand(
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: context.appComponentTokens.iconSize2xl,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: EdgeInsets.all(spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReviewSkeletonLine(width: 112),
                  SizedBox(height: spacing.xs),
                  _ReviewSkeletonLine(width: 168),
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
                            const _ReviewSkeletonLine(width: double.infinity),
                            SizedBox(height: spacing.xs),
                            const _ReviewSkeletonLine(width: double.infinity),
                            SizedBox(height: spacing.xs),
                            const _ReviewSkeletonLine(width: 144),
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

class _ReviewSkeletonLine extends StatelessWidget {
  const _ReviewSkeletonLine({required this.width});

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
