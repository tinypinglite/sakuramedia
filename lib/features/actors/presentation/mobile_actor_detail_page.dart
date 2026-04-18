import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_detail_content.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_pull_to_refresh.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

class MobileActorDetailPage extends StatefulWidget {
  const MobileActorDetailPage({super.key, required this.actorId});

  final int actorId;

  @override
  State<MobileActorDetailPage> createState() => _MobileActorDetailPageState();
}

class _MobileActorDetailPageState extends State<MobileActorDetailPage> {
  @override
  Widget build(BuildContext context) {
    return ActorDetailContent(
      actorId: widget.actorId,
      surfaceColor: context.appColors.surfaceCard,
      contentKey: const Key('mobile-actor-detail-page'),
      sectionSpacing: context.appSpacing.md,
      onMovieTap:
          (context, movieNumber) => MobileMovieDetailRouteData(
            movieNumber: movieNumber,
          ).push(context),
      headerBuilder:
          (
            context,
            actor,
            total,
            isSubscribed,
            isSubscriptionUpdating,
            onSubscriptionTap,
          ) => _MobileActorDetailHeader(
            actor: actor,
            total: total,
            isSubscribed: isSubscribed,
            isSubscriptionUpdating: isSubscriptionUpdating,
            onSubscriptionTap: onSubscriptionTap,
          ),
      loadingBuilder: (_) => const _MobileActorDetailLoadingSkeleton(),
      errorBuilder:
          (context, message, onRetry) =>
              _MobileActorDetailErrorState(message: message, onRetry: onRetry),
      footerBuilder: _buildLoadMoreFooter,
      bodyBuilder:
          (context, scrollController, child, onRefresh) => AppPullToRefresh(
            onRefresh: onRefresh!,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: scrollController,
              child: child,
            ),
          ),
      enableRefresh: true,
      onRefreshFailure: (_) => showToast('刷新失败'),
    );
  }

  Widget? _buildLoadMoreFooter(
    BuildContext context,
    PagedMovieSummaryController moviesController,
  ) {
    if (moviesController.items.isEmpty) {
      return null;
    }
    return AppPagedLoadMoreFooter(
      isLoading: moviesController.isLoadingMore,
      errorMessage: moviesController.loadMoreErrorMessage,
      onRetry: moviesController.loadMore,
    );
  }
}

class _MobileActorDetailHeader extends StatelessWidget {
  const _MobileActorDetailHeader({
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
      key: const Key('mobile-actor-detail-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ActorAvatar(
          imageUrl: actor.profileImage?.bestAvailableUrl,
          size: context.appComponentTokens.movieDetailActorAvatarSize,
          placeholderKey: const Key('mobile-actor-detail-avatar-placeholder'),
        ),
        SizedBox(width: context.appSpacing.md),
        Expanded(
          child: Text(
            actor.displayName,
            key: const Key('mobile-actor-detail-name'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: context.appColors.textPrimary,
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        _MobileActorSubscriptionBadge(
          actorId: actor.id,
          isSubscribed: isSubscribed,
          isUpdating: isSubscriptionUpdating,
          onTap: onSubscriptionTap,
        ),
        SizedBox(width: context.appSpacing.sm),
        Text(
          '$total 部',
          key: const Key('mobile-actor-detail-total'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: context.appColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MobileActorSubscriptionBadge extends StatelessWidget {
  const _MobileActorSubscriptionBadge({
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
      key: Key('mobile-actor-detail-subscription-$actorId'),
      width: componentTokens.movieCardStatusBadgeSize,
      height: componentTokens.movieCardStatusBadgeSize,
      child: Center(
        child:
            isUpdating
                ? SizedBox(
                  width: componentTokens.movieCardLoaderSize,
                  height: componentTokens.movieCardLoaderSize,
                  child: CircularProgressIndicator(
                    key: Key(
                      'mobile-actor-detail-subscription-loading-$actorId',
                    ),
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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: badge,
    );
  }
}

class _MobileActorDetailLoadingSkeleton extends StatelessWidget {
  const _MobileActorDetailLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        key: const Key('mobile-actor-detail-loading-skeleton'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SkeletonBlock(height: 54, width: 54),
              SizedBox(width: context.appSpacing.md),
              const Expanded(child: _SkeletonBlock(height: 24)),
              SizedBox(width: context.appSpacing.md),
              const _SkeletonBlock(height: 24, width: 24),
              SizedBox(width: context.appSpacing.sm),
              const _SkeletonBlock(height: 18, width: 56),
            ],
          ),
          SizedBox(height: context.appSpacing.md),
          const _SkeletonBlock(height: 32, width: 136),
          SizedBox(height: context.appSpacing.md),
          const _SkeletonBlock(height: 360),
        ],
      ),
    );
  }
}

class _MobileActorDetailErrorState extends StatelessWidget {
  const _MobileActorDetailErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('mobile-actor-detail-error-state'),
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
