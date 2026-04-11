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
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

typedef HotReviewMovieOpenHandler =
    void Function(BuildContext context, HotReviewListItemDto item);
const double _hotReviewCardHeight = 150;

class DesktopHotReviewsPage extends StatefulWidget {
  const DesktopHotReviewsPage({
    super.key,
    this.onOpenMovieDetail,
    this.minColumns = 2,
    this.maxColumns = 4,
    this.targetCardWidth = 420,
    this.enablePullToRefresh = false,
    this.scrollPhysics,
  }) : assert(minColumns >= 1),
       assert(maxColumns >= minColumns),
       assert(targetCardWidth > 0);

  final HotReviewMovieOpenHandler? onOpenMovieDetail;
  final int minColumns;
  final int maxColumns;
  final double targetCardWidth;
  final bool enablePullToRefresh;
  final ScrollPhysics? scrollPhysics;

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
    final scrollView = SingleChildScrollView(
      key: const Key('desktop-hot-reviews-scroll-view'),
      physics:
          widget.enablePullToRefresh
              ? widget.scrollPhysics ?? const AlwaysScrollableScrollPhysics()
              : widget.scrollPhysics,
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
    );

    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child:
          widget.enablePullToRefresh
              ? AppPullToRefresh(onRefresh: _handleRefresh, child: scrollView)
              : scrollView,
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await _controller.refresh();
    } catch (_) {
      if (mounted) {
        showToast('刷新失败');
      }
    }
  }

  Widget _buildBody(BuildContext context) {
    if (_controller.isInitialLoading && _controller.items.isEmpty) {
      return _HotReviewGrid(
        isLoading: true,
        items: <HotReviewListItemDto>[],
        minColumns: widget.minColumns,
        maxColumns: widget.maxColumns,
        targetCardWidth: widget.targetCardWidth,
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
      minColumns: widget.minColumns,
      maxColumns: widget.maxColumns,
      targetCardWidth: widget.targetCardWidth,
    );
  }

  void _openMovieDetail(HotReviewListItemDto item) {
    final movieNumber = item.movie.movieNumber.trim();
    if (movieNumber.isEmpty) {
      return;
    }
    final onOpenMovieDetail = widget.onOpenMovieDetail;
    if (onOpenMovieDetail != null) {
      onOpenMovieDetail(context, item);
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
          targetWidth: targetCardWidth,
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
            mainAxisExtent: _hotReviewCardHeight,
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
    return math.max(minColumns, math.min(maxColumns, columns));
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
    final componentTokens = context.appComponentTokens;
    final reviewDate =
        item.createdAt == null
            ? '--/--/--'
            : DateFormat('yy/MM/dd').format(item.createdAt!.toLocal());
    final username = item.username.trim().isEmpty ? '匿名用户' : item.username;
    final content = item.content.trim().isEmpty ? '暂无评论内容' : item.content;
    final compactTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colors.textSecondary,
      fontWeight: FontWeight.w600,
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
                          _MetaStat(
                            icon: Icons.thumb_up_alt_rounded,
                            color: colors.movieCardPlayableBadgeBackground,
                            value: '${item.likeCount}',
                          ),
                          SizedBox(width: spacing.xs),
                          _MetaStat(
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
                            padding: EdgeInsets.all(spacing.sm),
                            child: Text(
                              content,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.textPrimary),
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
    final compactTextStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: context.appColors.textSecondary,
      fontWeight: FontWeight.w700,
    );
    final compactIconSize =
        (Theme.of(context).textTheme.labelSmall?.fontSize ??
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

class _HotReviewCardSkeleton extends StatelessWidget {
  const _HotReviewCardSkeleton({super.key});

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
                    color: colors.textMuted,
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
