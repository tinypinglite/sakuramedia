import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_detail_content.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_profile_details.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

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
          MobileRoutes.movieDetail(movieNumber: movieNumber).push(context),
      headerBuilder:
          (
            context,
            actor,
            isSubscribed,
            isSubscriptionUpdating,
            onSubscriptionTap,
            onEditTap,
            onMergeTap,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MobileActorDetailHeader(
                actor: actor.summary,
                isSubscribed: isSubscribed,
                isSubscriptionUpdating: isSubscriptionUpdating,
                onSubscriptionTap: onSubscriptionTap,
                onEditTap: onEditTap,
                onMergeTap: onMergeTap,
              ),
              ActorProfileDetails(actor: actor, compact: true),
            ],
          ),
      // loading 用占位女优渲染真实详情头与影片网格，由 [AppSkeletonizer] 灰化。
      loadingBuilder: (context) => AppSkeletonizer(
        enabled: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MobileActorDetailHeader(
                actor: actorDetailPlaceholder().summary,
                isSubscribed: false,
                isSubscriptionUpdating: false,
                onSubscriptionTap: () {},
                onEditTap: () {},
                onMergeTap: () {},
              ),
              SizedBox(height: context.appSpacing.md),
              AppAdaptiveCardGrid(
                gridKey: const Key('movie-summary-grid'),
                items: movieListItemPlaceholders(count: 12),
                itemBuilder: (context, movie, index) =>
                    MovieSummaryCard(movie: movie, onTap: () {}),
              ),
            ],
          ),
        ),
      ),
      errorBuilder: (context, message, onRetry) => AppEmptyState(
        key: const Key('mobile-actor-detail-error-state'),
        message: message,
        onRetry: onRetry,
      ),
      bodyBuilder: (context, scrollController, child, onRefresh) =>
          AppAdaptiveRefreshScrollView(
            onRefresh: onRefresh!,
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[child],
          ),
      enableRefresh: true,
      onRefreshFailure: (_) => showToast(
        AppLocalizations.of(context).actorRefreshFailed,
        tone: AppToastTone.error,
      ),
      // 与移动影片页同一套移动范式：筛选走底部抽屉，多选态顶栏只留退出/计数/
      // 全选、批量动作下沉到底部条。
      useMobileFilterDrawer: true,
      useMobileSelectionLayout: true,
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
    required this.onMergeTap,
  });

  final ActorListItemDto actor;
  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final VoidCallback? onSubscriptionTap;
  final VoidCallback onEditTap;
  final VoidCallback onMergeTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('mobile-actor-detail-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ActorAvatar(
          imageUrl: actor.profileImage?.origin,
          size: context.appComponentTokens.movieDetailActorAvatarSize,
          placeholderKey: const Key('mobile-actor-detail-avatar-placeholder'),
        ),
        SizedBox(width: context.appSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectionArea(
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
              if (actor.isLocal) ...[
                SizedBox(height: context.appSpacing.xs),
                Text(
                  AppLocalizations.of(context).actorLocalSubscriptionHint,
                  key: const Key('mobile-actor-detail-local-subscription-hint'),
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s10,
                    tone: AppTextTone.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: context.appSpacing.md),
        if (!actor.isLocal) ...[
          AppIconButton(
            key: const Key('mobile-actor-detail-merge-button'),
            icon: const Icon(Icons.call_merge_outlined),
            size: AppIconButtonSize.mini,
            tooltip: AppLocalizations.of(context).actorMergeTooltip,
            semanticLabel: AppLocalizations.of(context).actorMergeTooltip,
            onPressed: onMergeTap,
          ),
          SizedBox(width: context.appSpacing.sm),
        ],
        AppIconButton(
          key: const Key('mobile-actor-detail-edit-button'),
          icon: const Icon(Icons.edit_outlined),
          size: AppIconButtonSize.mini,
          tooltip: AppLocalizations.of(context).actorEditProfileTooltip,
          semanticLabel: AppLocalizations.of(context).actorEditProfileTooltip,
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
