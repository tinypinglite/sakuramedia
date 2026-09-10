import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_detail_content.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_profile_details.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

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
      onMovieTap: (context, movieNumber) => context.pushDesktopMovieDetail(
        movieNumber: movieNumber,
        fallbackPath: '/desktop/library/actors/${widget.actorId}',
      ),
      headerBuilder:
          (
            context,
            actor,
            isSubscribed,
            isSubscriptionUpdating,
            onSubscriptionTap,
            onEditTap,
          ) => _ActorDetailHeader(
            actor: actor,
            isSubscribed: isSubscribed,
            isSubscriptionUpdating: isSubscriptionUpdating,
            onSubscriptionTap: onSubscriptionTap,
            onEditTap: onEditTap,
          ),
      loadingBuilder: (_) => const _ActorDetailLoadingSkeleton(),
      errorBuilder: (context, message, onRetry) =>
          _ActorDetailErrorState(message: message, onRetry: onRetry),
      footerBuilder: _buildLoadMoreFooter,
      bodyBuilder: (context, scrollController, child, _) => CustomScrollView(
        controller: scrollController,
        slivers: <Widget>[child],
      ),
    );
  }

  Widget? _buildLoadMoreFooter(
    BuildContext context,
    MovieSummaryState movies,
    VoidCallback onRetry,
  ) {
    if (movies.paged.items.isEmpty) {
      return null;
    }
    return AppPagedLoadMoreFooter(
      isLoading: movies.paged.isLoadingMore,
      errorMessage: movies.paged.loadMoreErrorMessage,
      onRetry: onRetry,
    );
  }
}

class _ActorDetailHeader extends StatelessWidget {
  const _ActorDetailHeader({
    required this.actor,
    required this.isSubscribed,
    required this.isSubscriptionUpdating,
    required this.onSubscriptionTap,
    required this.onEditTap,
  });

  final ActorDetailDto actor;
  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final VoidCallback? onSubscriptionTap;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('actor-detail-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ActorAvatar(
          imageUrl: actor.summary.profileImage?.bestAvailableUrl,
          size: context.appComponentTokens.movieDetailActorAvatarSize,
          placeholderKey: const Key('actor-detail-avatar-placeholder'),
        ),
        SizedBox(width: context.appSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectionArea(
                child: Text(
                  actor.summary.displayName,
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
              ActorProfileDetails(actor: actor, compact: false),
            ],
          ),
        ),
        SizedBox(width: context.appSpacing.lg),
        AppIconButton(
          key: const Key('actor-detail-edit-button'),
          icon: const Icon(Icons.edit_outlined),
          size: AppIconButtonSize.compact,
          tooltip: '编辑女优资料',
          semanticLabel: '编辑女优资料',
          onPressed: onEditTap,
        ),
        SizedBox(width: context.appSpacing.sm),
        SubscriptionHeartBadge(
          key: Key('actor-detail-subscription-${actor.summary.id}'),
          loadingKey: Key(
            'actor-detail-subscription-loading-${actor.summary.id}',
          ),
          isSubscribed: isSubscribed,
          isUpdating: isSubscriptionUpdating,
          onTap: onSubscriptionTap,
        ),
      ],
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
