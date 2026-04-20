import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_detail_content.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';
import 'package:sakuramedia/widgets/actors/actor_avatar.dart';

class DesktopActorDetailPage extends StatefulWidget {
  const DesktopActorDetailPage({super.key, required this.actorId});

  final int actorId;

  @override
  State<DesktopActorDetailPage> createState() => _DesktopActorDetailPageState();
}

class _DesktopActorDetailPageState extends State<DesktopActorDetailPage> {
  @override
  Widget build(BuildContext context) {
    return ActorDetailContent(
      actorId: widget.actorId,
      surfaceColor: context.appColors.surfaceElevated,
      contentKey: const Key('actor-detail-page'),
      sectionSpacing: context.appSpacing.lg,
      onMovieTap:
          (context, movieNumber) => context.pushDesktopMovieDetail(
            movieNumber: movieNumber,
            fallbackPath: '/desktop/library/actors/${widget.actorId}',
          ),
      headerBuilder:
          (
            context,
            actor,
            total,
            isSubscribed,
            isSubscriptionUpdating,
            onSubscriptionTap,
          ) => _ActorDetailHeader(
            actor: actor,
            total: total,
            isSubscribed: isSubscribed,
            isSubscriptionUpdating: isSubscriptionUpdating,
            onSubscriptionTap: onSubscriptionTap,
          ),
      loadingBuilder: (_) => const _ActorDetailLoadingSkeleton(),
      errorBuilder:
          (context, message, onRetry) =>
              _ActorDetailErrorState(message: message, onRetry: onRetry),
      footerBuilder: _buildLoadMoreFooter,
      bodyBuilder:
          (context, scrollController, child, _) =>
              SingleChildScrollView(controller: scrollController, child: child),
    );
  }

  Widget? _buildLoadMoreFooter(
    BuildContext context,
    PagedMovieSummaryController moviesController,
  ) {
    if (moviesController.items.isEmpty) {
      return null;
    }

    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    if (moviesController.isLoadingMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.md),
          child: SizedBox(
            width: componentTokens.movieCardLoaderSize,
            height: componentTokens.movieCardLoaderSize,
            child: CircularProgressIndicator(
              strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (moviesController.loadMoreErrorMessage == null) {
      return null;
    }

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: componentTokens.iconSizeXl,
                color: context.appTextPalette.secondary,
              ),
              SizedBox(width: spacing.sm),
              Text(
                moviesController.loadMoreErrorMessage!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(width: spacing.sm),
              TextButton(
                onPressed: moviesController.loadMore,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.sm,
                    vertical: spacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActorDetailHeader extends StatelessWidget {
  const _ActorDetailHeader({
    required this.actor,
    required this.total,
    required this.isSubscribed,
    required this.isSubscriptionUpdating,
    required this.onSubscriptionTap,
  });

  final ActorListItemDto actor;
  final int total;
  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final VoidCallback? onSubscriptionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('actor-detail-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ActorAvatar(
          imageUrl: actor.profileImage?.bestAvailableUrl,
          size: context.appComponentTokens.movieDetailActorAvatarSize,
          placeholderKey: const Key('actor-detail-avatar-placeholder'),
        ),
        SizedBox(width: context.appSpacing.md),
        Expanded(
          child: Text(
            actor.displayName,
            key: const Key('actor-detail-name'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.lg),
        _ActorSubscriptionBadge(
          actorId: actor.id,
          isSubscribed: isSubscribed,
          isUpdating: isSubscriptionUpdating,
          onTap: onSubscriptionTap,
        ),
        SizedBox(width: context.appSpacing.sm),
        Text(
          '$total 部',
          key: const Key('actor-detail-total'),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    );
  }
}

class _ActorSubscriptionBadge extends StatelessWidget {
  const _ActorSubscriptionBadge({
    required this.actorId,
    required this.isSubscribed,
    required this.isUpdating,
    required this.onTap,
  });

  final int actorId;
  final bool isSubscribed;
  final bool isUpdating;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;
    final colors = context.appColors;

    final badge = SizedBox(
      key: Key('actor-detail-subscription-$actorId'),
      width: componentTokens.movieCardStatusBadgeSize,
      height: componentTokens.movieCardStatusBadgeSize,
      child: Center(
        child:
            isUpdating
                ? SizedBox(
                  width: componentTokens.movieCardLoaderSize,
                  height: componentTokens.movieCardLoaderSize,
                  child: CircularProgressIndicator(
                    key: Key('actor-detail-subscription-loading-$actorId'),
                    strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
                    color: colors.subscriptionHeartIcon,
                  ),
                )
                : Icon(
                  isSubscribed
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: componentTokens.iconSizeXl,
                  color: colors.subscriptionHeartIcon,
                ),
      ),
    );

    if (onTap == null || isUpdating) {
      return badge;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: badge,
      ),
    );
  }
}

class _ActorDetailLoadingSkeleton extends StatelessWidget {
  const _ActorDetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        key: const Key('actor-detail-loading-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonBlock(height: 54, width: 54),
              SizedBox(width: context.appSpacing.md),
              const Expanded(child: _SkeletonBlock(height: 24)),
              SizedBox(width: context.appSpacing.lg),
              const _SkeletonBlock(height: 24, width: 24),
              SizedBox(width: context.appSpacing.sm),
              const _SkeletonBlock(height: 18, width: 56),
            ],
          ),
          SizedBox(height: context.appSpacing.lg),
          const _SkeletonBlock(height: 32, width: 136),
          SizedBox(height: context.appSpacing.lg),
          const _SkeletonBlock(height: 360),
        ],
      ),
    );
  }
}

class _ActorDetailErrorState extends StatelessWidget {
  const _ActorDetailErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.lg),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, this.width});

  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
    );
  }
}
