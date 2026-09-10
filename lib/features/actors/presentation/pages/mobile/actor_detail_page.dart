import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_detail_content.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_profile_details.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

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
      onMovieTap: (context, movieNumber) =>
          MobileMovieDetailRouteData(movieNumber: movieNumber).push(context),
      headerBuilder:
          (
            context,
            actor,
            isSubscribed,
            isSubscriptionUpdating,
            onSubscriptionTap,
            onEditTap,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MobileActorDetailHeader(
                actor: actor.summary,
                isSubscribed: isSubscribed,
                isSubscriptionUpdating: isSubscriptionUpdating,
                onSubscriptionTap: onSubscriptionTap,
                onEditTap: onEditTap,
              ),
              ActorProfileDetails(actor: actor, compact: true),
            ],
          ),
      loadingBuilder: (_) => const _MobileActorDetailLoadingSkeleton(),
      errorBuilder: (context, message, onRetry) => AppEmptyState(
        key: const Key('mobile-actor-detail-error-state'),
        message: message,
        onRetry: onRetry,
      ),
      footerBuilder: _buildLoadMoreFooter,
      bodyBuilder: (context, scrollController, child, onRefresh) =>
          AppAdaptiveRefreshScrollView(
            onRefresh: onRefresh!,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[child],
          ),
      enableRefresh: true,
      onRefreshFailure: (_) => showToast('刷新失败'),
      // 与移动影片页同一套移动范式：筛选走底部抽屉，多选态顶栏只留退出/计数/
      // 全选、批量动作下沉到底部条。
      useMobileFilterDrawer: true,
      useMobileSelectionLayout: true,
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

class _MobileActorDetailHeader extends StatelessWidget {
  const _MobileActorDetailHeader({
    required this.actor,
    required this.isSubscribed,
    required this.isSubscriptionUpdating,
    required this.onSubscriptionTap,
    required this.onEditTap,
  });

  final ActorListItemDto actor;
  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final VoidCallback? onSubscriptionTap;
  final VoidCallback onEditTap;

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
          child: SelectionArea(
            child: Text(
              actor.displayName,
              key: const Key('mobile-actor-detail-name'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.primary,
              ),
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        AppIconButton(
          key: const Key('mobile-actor-detail-edit-button'),
          icon: const Icon(Icons.edit_outlined),
          size: AppIconButtonSize.mini,
          tooltip: '编辑女优资料',
          semanticLabel: '编辑女优资料',
          onPressed: onEditTap,
        ),
        SizedBox(width: context.appSpacing.sm),
        SubscriptionHeartBadge(
          key: Key('mobile-actor-detail-subscription-${actor.id}'),
          loadingKey: Key(
            'mobile-actor-detail-subscription-loading-${actor.id}',
          ),
          isSubscribed: isSubscribed,
          isUpdating: isSubscriptionUpdating,
          onTap: onSubscriptionTap,
        ),
      ],
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
