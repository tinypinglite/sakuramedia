import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_profile_details.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_error_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_card.dart';
import 'package:sakuramedia/widgets/domain/movies/subscription_heart_badge.dart';

class ActorDetailHeader extends StatelessWidget {
  const ActorDetailHeader({
    super.key,
    required this.mobile,
    required this.actor,
    required this.isSubscribed,
    required this.isSubscriptionUpdating,
    required this.onSubscriptionTap,
    required this.onEditTap,
    required this.onMergeTap,
  });

  final bool mobile;
  final ActorDetailDto actor;
  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final VoidCallback? onSubscriptionTap;
  final VoidCallback onEditTap;
  final VoidCallback onMergeTap;

  @override
  Widget build(BuildContext context) {
    if (!mobile) {
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
                _ActorName(actor: actor, mobile: false),
                ActorProfileDetails(actor: actor, compact: false),
                _LocalHint(actor: actor, mobile: false),
              ],
            ),
          ),
          SizedBox(width: context.appSpacing.lg),
          _ActorActions(
            actor: actor,
            mobile: false,
            isSubscribed: isSubscribed,
            isSubscriptionUpdating: isSubscriptionUpdating,
            onSubscriptionTap: onSubscriptionTap,
            onEditTap: onEditTap,
            onMergeTap: onMergeTap,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: const Key('mobile-actor-detail-header'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ActorAvatar(
              imageUrl: actor.summary.profileImage?.origin,
              size: context.appComponentTokens.movieDetailActorAvatarSize,
              placeholderKey: const Key(
                'mobile-actor-detail-avatar-placeholder',
              ),
            ),
            SizedBox(width: context.appSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActorName(actor: actor, mobile: true),
                  _LocalHint(actor: actor, mobile: true),
                ],
              ),
            ),
            SizedBox(width: context.appSpacing.md),
            _ActorActions(
              actor: actor,
              mobile: true,
              isSubscribed: isSubscribed,
              isSubscriptionUpdating: isSubscriptionUpdating,
              onSubscriptionTap: onSubscriptionTap,
              onEditTap: onEditTap,
              onMergeTap: onMergeTap,
            ),
          ],
        ),
        ActorProfileDetails(actor: actor, compact: true),
      ],
    );
  }
}

class _ActorName extends StatelessWidget {
  const _ActorName({required this.actor, required this.mobile});

  final ActorDetailDto actor;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: Text(
        actor.summary.displayName,
        key: Key(mobile ? 'mobile-actor-detail-name' : 'actor-detail-name'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: resolveAppTextStyle(
          context,
          size: mobile ? AppTextSize.s14 : AppTextSize.s18,
          weight: mobile ? AppTextWeight.regular : AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ),
      ),
    );
  }
}

class _LocalHint extends StatelessWidget {
  const _LocalHint({required this.actor, required this.mobile});

  final ActorDetailDto actor;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    if (!actor.summary.isLocal) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(top: context.appSpacing.xs),
      child: Text(
        AppLocalizations.of(context).actorLocalSubscriptionHint,
        key: Key(
          mobile
              ? 'mobile-actor-detail-local-subscription-hint'
              : 'actor-detail-local-subscription-hint',
        ),
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s10,
          tone: AppTextTone.muted,
        ),
      ),
    );
  }
}

class _ActorActions extends StatelessWidget {
  const _ActorActions({
    required this.actor,
    required this.mobile,
    required this.isSubscribed,
    required this.isSubscriptionUpdating,
    required this.onSubscriptionTap,
    required this.onEditTap,
    required this.onMergeTap,
  });

  final ActorDetailDto actor;
  final bool mobile;
  final bool isSubscribed;
  final bool isSubscriptionUpdating;
  final VoidCallback? onSubscriptionTap;
  final VoidCallback onEditTap;
  final VoidCallback onMergeTap;

  @override
  Widget build(BuildContext context) {
    final prefix = mobile ? 'mobile-actor-detail' : 'actor-detail';
    final size = mobile ? AppIconButtonSize.mini : AppIconButtonSize.compact;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!actor.summary.isLocal) ...[
          AppIconButton(
            key: Key('$prefix-merge-button'),
            icon: const Icon(Icons.call_merge_outlined),
            size: size,
            tooltip: AppLocalizations.of(context).actorMergeTooltip,
            semanticLabel: AppLocalizations.of(context).actorMergeTooltip,
            onPressed: onMergeTap,
          ),
          SizedBox(width: context.appSpacing.sm),
        ],
        AppIconButton(
          key: Key('$prefix-edit-button'),
          icon: const Icon(Icons.edit_outlined),
          size: size,
          tooltip: AppLocalizations.of(context).actorEditProfileTooltip,
          semanticLabel: AppLocalizations.of(context).actorEditProfileTooltip,
          onPressed: onEditTap,
        ),
        SizedBox(width: context.appSpacing.sm),
        SubscriptionHeartBadge(
          key: Key('$prefix-subscription-${actor.summary.id}'),
          loadingKey: Key('$prefix-subscription-loading-${actor.summary.id}'),
          isSubscribed: isSubscribed,
          isUpdating: isSubscriptionUpdating,
          onTap: onSubscriptionTap,
        ),
      ],
    );
  }
}

class ActorDetailLoadingBody extends StatelessWidget {
  const ActorDetailLoadingBody({super.key, required this.mobile});

  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return AppSkeletonizer(
      enabled: true,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ActorDetailHeader(
              mobile: mobile,
              actor: actorDetailPlaceholder(),
              isSubscribed: false,
              isSubscriptionUpdating: false,
              onSubscriptionTap: () {},
              onEditTap: () {},
              onMergeTap: () {},
            ),
            SizedBox(
              height: mobile ? context.appSpacing.md : context.appSpacing.lg,
            ),
            AppAdaptiveCardGrid(
              gridKey: const Key('movie-summary-grid'),
              items: movieListItemPlaceholders(count: 12),
              itemBuilder: (context, movie, index) =>
                  MovieSummaryCard(movie: movie, onTap: () {}),
            ),
          ],
        ),
      ),
    );
  }
}

class ActorDetailErrorBody extends StatelessWidget {
  const ActorDetailErrorBody({
    super.key,
    required this.mobile,
    required this.message,
    required this.onRetry,
  });

  final bool mobile;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      key: mobile ? const Key('mobile-actor-detail-error-state') : null,
      title: AppLocalizations.of(context).baseActionFailed,
      message: message,
      onRetry: onRetry,
    );
  }
}

class ActorDetailPageBody extends StatelessWidget {
  const ActorDetailPageBody({
    super.key,
    required this.mobile,
    required this.scrollController,
    required this.child,
    required this.onRefresh,
  });

  final bool mobile;
  final ScrollController scrollController;
  final Widget child;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (mobile) {
      return AppAdaptiveRefreshScrollView(
        onRefresh: onRefresh!,
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[child],
      );
    }
    return CustomScrollView(
      controller: scrollController,
      slivers: <Widget>[child],
    );
  }
}
