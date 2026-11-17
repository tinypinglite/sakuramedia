import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_toggle_provider.dart';
import 'package:sakuramedia/features/discovery/data/taste_profile_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/taste_profile_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_actress_section.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_entrance.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_panel.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_split_layout.dart';

/// 女优页顶部的常看女优面板：已订阅与推荐共用横向女优卡，只有心的状态不同。
class ActorTasteRecommendationRail extends ConsumerWidget {
  const ActorTasteRecommendationRail({super.key, required this.onActorTap});

  final ValueChanged<int> onActorTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(tasteProfileProvider);

    final profile = profileAsync.value;
    if (profileAsync.isLoading && profile == null) {
      return _buildSkeleton(context);
    }
    if (profile == null || profile.sampleMovieCount < 2) {
      return const SizedBox.shrink();
    }

    final subscribed = profile.subscribedActresses
        .take(8)
        .toList(growable: false);
    final recommended = profile.unsubscribedActresses
        .take(8)
        .toList(growable: false);
    if (subscribed.isEmpty && recommended.isEmpty) {
      return const SizedBox.shrink();
    }
    final updatingActorIds = ref.watch(actorSubscriptionToggleProvider);
    Future<void> toggleFollow(TasteProfileActressDto entry) =>
        toggleActorSubscriptionWithFeedback(
          context,
          ref,
          actorId: entry.actor.id,
          isSubscribed: entry.actor.isSubscribed,
        );

    final subscribedSection = TasteActressSection(
      title: AppLocalizations.of(context).actorTasteSubscribedTitle,
      entries: subscribed,
      onActorTap: (entry) => onActorTap(entry.actor.id),
      onFollowTap: toggleFollow,
      isFollowUpdating: (entry) => updatingActorIds.contains(entry.actor.id),
    );
    final recommendedSection = TasteActressSection(
      title: AppLocalizations.of(context).actorTasteRecommendedTitle,
      entries: recommended,
      onActorTap: (entry) => onActorTap(entry.actor.id),
      onFollowTap: toggleFollow,
      isFollowUpdating: (entry) => updatingActorIds.contains(entry.actor.id),
    );

    final Widget body;
    if (subscribed.isEmpty) {
      body = recommendedSection;
    } else if (recommended.isEmpty) {
      body = subscribedSection;
    } else {
      body = TasteSplitLayout(
        primary: subscribedSection,
        secondary: recommendedSection,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.lg),
      child: TasteEntrance(
        child: TastePanel(
          key: const Key('actor-taste-recommendation'),
          title: AppLocalizations.of(context).actorTastePanelTitle,
          icon: Icons.auto_awesome_rounded,
          sampleMovieCount: profile.sampleMovieCount,
          compact: true,
          child: body,
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final placeholders = actorListItemPlaceholders(count: 8);
    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.lg),
      child: AppSkeletonizer(
        enabled: true,
        child: TastePanel(
          sampleMovieCount: 0,
          title: AppLocalizations.of(context).actorTastePanelTitle,
          icon: Icons.auto_awesome_rounded,
          compact: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TasteActressSection(
                title: AppLocalizations.of(context).actorTasteSubscribedTitle,
                entries: placeholders
                    .take(3)
                    .map(
                      (actor) => TasteProfileActressDto(
                        actor: actor,
                        matchedMovieCount: 0,
                      ),
                    )
                    .toList(growable: false),
              ),
              SizedBox(height: context.appSpacing.lg),
              TasteActressSection(
                title: AppLocalizations.of(context).actorTasteRecommendedTitle,
                entries: placeholders
                    .skip(3)
                    .map(
                      (actor) => TasteProfileActressDto(
                        actor: actor,
                        matchedMovieCount: 0,
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
