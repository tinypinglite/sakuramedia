import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sakuramedia/features/movies/data/movie_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

class MobileFollowMovieCard extends StatefulWidget {
  const MobileFollowMovieCard({
    super.key,
    required this.movie,
    required this.onTap,
    required this.onSubscriptionTap,
    required this.isSubscriptionUpdating,
    required this.isDetailLoading,
    required this.detailStillImageUrls,
    required this.detailSummary,
    required this.detailThinCoverUrl,
    this.onVisible,
  });

  final MovieListItemDto movie;
  final VoidCallback onTap;
  final VoidCallback onSubscriptionTap;
  final bool isSubscriptionUpdating;
  final bool isDetailLoading;
  final List<String> detailStillImageUrls;
  final String? detailSummary;
  final String? detailThinCoverUrl;
  final VoidCallback? onVisible;

  @override
  State<MobileFollowMovieCard> createState() => _MobileFollowMovieCardState();
}

class _MobileFollowMovieCardState extends State<MobileFollowMovieCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onVisible?.call();
    });
  }

  @override
  void didUpdateWidget(covariant MobileFollowMovieCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.movieNumber != widget.movie.movieNumber) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.onVisible?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;
    final cardHeight = componentTokens.mobileFollowMovieCardHeight;
    final topMediaBorderRadius = BorderRadius.only(
      topLeft: Radius.circular(context.appRadius.md),
      topRight: Radius.circular(context.appRadius.md),
    );
    final titleText =
        widget.detailSummary?.trim().isNotEmpty ?? false
            ? widget.detailSummary!.trim()
            : widget.movie.title;
    final thinCoverUrl =
        widget.detailThinCoverUrl?.trim().isNotEmpty ?? false
            ? widget.detailThinCoverUrl!.trim()
            : widget.movie.coverImage?.bestAvailableUrl;

    return InkWell(
      key: Key('mobile-follow-movie-card-${widget.movie.movieNumber}'),
      onTap: widget.onTap,
      borderRadius: context.appRadius.mdBorder,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceCard,
          borderRadius: context.appRadius.mdBorder,
          border: Border.all(color: colors.borderSubtle),
          boxShadow: context.appShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.xs),
              child: SizedBox(
                height: cardHeight,
                child: ClipRRect(
                  borderRadius: topMediaBorderRadius,
                  child: Row(
                    children: [
                      _FollowThinCover(
                        movieNumber: widget.movie.movieNumber,
                        imageUrl: thinCoverUrl,
                        isSubscribed: widget.movie.isSubscribed,
                        isSubscriptionUpdating: widget.isSubscriptionUpdating,
                        onSubscriptionTap: widget.onSubscriptionTap,
                      ),
                      Expanded(
                        child: _StillImagesStrip(
                          movieNumber: widget.movie.movieNumber,
                          isLoading: widget.isDetailLoading,
                          imageUrls: widget.detailStillImageUrls,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleText,
                    key: Key(
                      'mobile-follow-movie-card-title-${widget.movie.movieNumber}',
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: spacing.xs),
                  Wrap(
                    spacing: spacing.sm,
                    runSpacing: spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        widget.movie.movieNumber,
                        key: Key(
                          'mobile-follow-movie-card-number-${widget.movie.movieNumber}',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _formatReleaseDate(widget.movie.releaseDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (widget.movie.canPlay)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              size: componentTokens.iconSizeXs,
                              color: colors.movieCardPlayableBadgeBackground,
                            ),
                            SizedBox(width: spacing.xs),
                            Text(
                              '可播放',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: colors.movieCardPlayableBadgeBackground,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatReleaseDate(DateTime? value) {
    if (value == null) {
      return '发行日期未知';
    }
    return DateFormat('yyyy-MM-dd').format(value.toLocal());
  }
}

class _FollowThinCover extends StatelessWidget {
  const _FollowThinCover({
    required this.movieNumber,
    required this.imageUrl,
    required this.isSubscribed,
    required this.isSubscriptionUpdating,
    required this.onSubscriptionTap,
  });

  final String movieNumber;
  final String? imageUrl;
  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final VoidCallback onSubscriptionTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final coverWidth = componentTokens.mobileFollowMovieThinCoverWidth;
    final cardHeight = componentTokens.mobileFollowMovieCardHeight;
    final cover = SizedBox(
      width: coverWidth,
      height: cardHeight,
      child:
          imageUrl == null || imageUrl!.isEmpty
              ? DecoratedBox(
                key: Key(
                  'mobile-follow-movie-card-cover-placeholder-$movieNumber',
                ),
                decoration: BoxDecoration(color: colors.surfaceMuted),
                child: Icon(
                  Icons.movie_creation_outlined,
                  size: componentTokens.iconSize2xl,
                  color: colors.textMuted,
                ),
              )
              : MaskedImage(
                url: imageUrl!,
                fit: BoxFit.cover,
                visibleWidthFactor:
                    componentTokens.movieCardCoverVisibleWidthFactor,
                visibleAlignment: Alignment.centerRight,
              ),
    );

    return Stack(
      children: [
        cover,
        Positioned(
          top: context.appSpacing.xs,
          left: context.appSpacing.xs,
          child: SizedBox(
            width: 30,
            height: 30,
            child:
                isSubscriptionUpdating
                    ? Padding(
                      padding: const EdgeInsets.all(5),
                      child: CircularProgressIndicator(
                        key: Key(
                          'mobile-follow-movie-card-subscription-loading-$movieNumber',
                        ),
                        strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
                        color: colors.subscriptionHeartIcon,
                      ),
                    )
                    : IconButton(
                      key: Key(
                        'mobile-follow-movie-card-subscription-$movieNumber',
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                      onPressed: onSubscriptionTap,
                      icon: Icon(
                        isSubscribed
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: colors.subscriptionHeartIcon,
                        size: componentTokens.iconSizeXl,
                      ),
                    ),
          ),
        ),
      ],
    );
  }
}

class _StillImagesStrip extends StatelessWidget {
  const _StillImagesStrip({
    required this.movieNumber,
    required this.isLoading,
    required this.imageUrls,
  });

  final String movieNumber;
  final bool isLoading;
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final cardHeight = context.appComponentTokens.mobileFollowMovieCardHeight;
    final stillWidth = context.appComponentTokens.mobileFollowMovieStillWidth;
    final thumbnailRadius = context.appRadius.smBorder;
    if (isLoading) {
      return Container(
        key: Key('mobile-follow-movie-card-detail-loading-$movieNumber'),
        height: cardHeight,
        decoration: BoxDecoration(color: colors.surfaceMuted),
      );
    }

    if (imageUrls.isEmpty) {
      return Container(
        key: Key('mobile-follow-movie-card-detail-empty-$movieNumber'),
        height: cardHeight,
        decoration: BoxDecoration(color: colors.surfaceMuted),
        child: Center(
          child: Text(
            '暂无剧照',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ),
      );
    }

    return Container(
      key: Key('mobile-follow-movie-card-strip-$movieNumber'),
      height: cardHeight,
      decoration: BoxDecoration(color: colors.surfaceMuted),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) => SizedBox(width: spacing.xs),
        itemBuilder: (context, index) {
          final url = imageUrls[index];
          return ClipRRect(
            borderRadius: thumbnailRadius,
            child: SizedBox(
              width: stillWidth,
              child: MaskedImage(url: url, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}
