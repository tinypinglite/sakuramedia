import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_detail_content.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_profile_details.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';
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
      surfaceColor: context.appColors.surfacePage,
      contentKey: const Key('actor-detail-page'),
      sectionSpacing: context.appSpacing.lg,
      onMovieTap: (context, movieNumber) => DesktopRoutes.movieDetail(
        movieNumber: movieNumber,
        fallbackPath: '/desktop/library/actors/${widget.actorId}',
      ).push(context),
      headerBuilder:
          (
            context,
            actor,
            isSubscribed,
            isSubscriptionUpdating,
            onSubscriptionTap,
            onEditTap,
            onMergeTap,
          ) => _ActorDetailHeader(
            actor: actor,
            isSubscribed: isSubscribed,
            isSubscriptionUpdating: isSubscriptionUpdating,
            onSubscriptionTap: onSubscriptionTap,
            onEditTap: onEditTap,
            onMergeTap: onMergeTap,
          ),
      // loading 用占位女优渲染真实详情头与影片网格，由 [AppSkeletonizer] 灰化。
      loadingBuilder: (context) => AppSkeletonizer(
        enabled: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActorDetailHeader(
                actor: actorDetailPlaceholder(),
                isSubscribed: false,
                isSubscriptionUpdating: false,
                onSubscriptionTap: () {},
                onEditTap: () {},
                onMergeTap: () {},
              ),
              SizedBox(height: context.appSpacing.lg),
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
      errorBuilder: (context, message, onRetry) =>
          _ActorDetailErrorState(message: message, onRetry: onRetry),
      bodyBuilder: (context, scrollController, child, _) => CustomScrollView(
        controller: scrollController,
        slivers: <Widget>[child],
      ),
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
    required this.onMergeTap,
  });

  final ActorDetailDto actor;
  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final VoidCallback? onSubscriptionTap;
  final VoidCallback onEditTap;
  final VoidCallback onMergeTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('actor-detail-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ActorAvatar(
          imageUrl: actor.summary.profileImage?.origin,
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
              if (actor.summary.isLocal) ...[
                SizedBox(height: context.appSpacing.xs),
                Text(
                  AppLocalizations.of(context).actorLocalSubscriptionHint,
                  key: const Key('actor-detail-local-subscription-hint'),
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
        SizedBox(width: context.appSpacing.lg),
        if (!actor.summary.isLocal) ...[
          AppIconButton(
            key: const Key('actor-detail-merge-button'),
            icon: const Icon(Icons.call_merge_outlined),
            size: AppIconButtonSize.compact,
            tooltip: AppLocalizations.of(context).actorMergeTooltip,
            semanticLabel: AppLocalizations.of(context).actorMergeTooltip,
            onPressed: onMergeTap,
          ),
          SizedBox(width: context.appSpacing.sm),
        ],
        AppIconButton(
          key: const Key('actor-detail-edit-button'),
          icon: const Icon(Icons.edit_outlined),
          size: AppIconButtonSize.compact,
          tooltip: AppLocalizations.of(context).actorEditProfileTooltip,
          semanticLabel: AppLocalizations.of(context).actorEditProfileTooltip,
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

class _ActorDetailErrorState extends StatelessWidget {
  const _ActorDetailErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      title: AppLocalizations.of(context).baseActionFailed,
      message: message,
      onRetry: onRetry,
    );
  }
}
