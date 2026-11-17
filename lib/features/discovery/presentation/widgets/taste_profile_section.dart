import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_toggle_provider.dart';
import 'package:sakuramedia/features/discovery/data/taste_profile_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/taste_profile_provider.dart';
import 'package:sakuramedia/features/discovery/presentation/widgets/taste_tag_pill.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_actress_section.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_entrance.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_panel.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_section_label.dart';
import 'package:sakuramedia/widgets/domain/taste/taste_split_layout.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// 发现页「观影偏好」区块：标签画像 + 可能想关注的女优。
class TasteProfileSection extends ConsumerWidget {
  const TasteProfileSection({
    super.key,
    required this.onTagTap,
    required this.onActorTap,
  });

  final ValueChanged<int> onTagTap;
  final ValueChanged<int> onActorTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(tasteProfileProvider);

    final profile = profileAsync.value;
    if (profileAsync.isLoading && profile == null) {
      return _buildSkeleton(context);
    }
    if (profile == null) {
      if (profileAsync.hasError) {
        return AppInlineErrorBanner(
          key: const Key('taste-profile-error'),
          message: AppLocalizations.of(context).errorTasteProfileLoadFailed,
          retryKey: const Key('taste-profile-retry'),
          onRetry: () async {
            await ref.read(tasteProfileProvider.notifier).refresh();
          },
        );
      }
      return const SizedBox.shrink();
    }
    if (profile.sampleMovieCount < 2 || !profile.hasContent) {
      return const SizedBox.shrink();
    }

    final unsubscribed = profile.unsubscribedActresses;
    final hasRecommendations = unsubscribed.isNotEmpty;
    final actresses = hasRecommendations
        ? unsubscribed
        : profile.subscribedActresses;
    final updatingActorIds = ref.watch(actorSubscriptionToggleProvider);
    final panel = _TastePanelContent(
      key: const Key('taste-profile-panel'),
      sampleMovieCount: profile.sampleMovieCount,
      tags: profile.tags.take(8).toList(growable: false),
      actresses: actresses.take(6).toList(growable: false),
      actressTitle:
          hasRecommendations
              ? l10n.discoveryTasteSuggestedActors
              : l10n.discoveryTasteFrequentActors,
      onTagTap: onTagTap,
      onActorTap: onActorTap,
      onFollowTap: (entry) => toggleActorSubscriptionWithFeedback(
        context,
        ref,
        actorId: entry.actor.id,
        isSubscribed: entry.actor.isSubscribed,
      ),
      isFollowUpdating: (entry) => updatingActorIds.contains(entry.actor.id),
    );

    return TasteEntrance(child: panel);
  }

  Widget _buildSkeleton(BuildContext context) {
    final placeholderActors = actorListItemPlaceholders(count: 5);
    return AppSkeletonizer(
      enabled: true,
      child: _TastePanelContent(
        key: const Key('taste-profile-panel-skeleton'),
        sampleMovieCount: 0,
        tags: List<TasteProfileTagDto>.generate(
          6,
          (index) => TasteProfileTagDto(
            tagId: -1 - index,
            name: BoneMock.words(2),
            matchedMovieCount: 0,
          ),
          growable: false,
        ),
        actresses: placeholderActors
            .map(
              (actor) =>
                  TasteProfileActressDto(actor: actor, matchedMovieCount: 0),
            )
            .toList(growable: false),
        actressTitle: AppLocalizations.of(context).discoveryTasteSuggestedActors,
        onTagTap: null,
        onActorTap: null,
        onFollowTap: null,
        isFollowUpdating: (_) => false,
      ),
    );
  }
}

class _TastePanelContent extends StatelessWidget {
  const _TastePanelContent({
    super.key,
    required this.sampleMovieCount,
    required this.tags,
    required this.actresses,
    required this.actressTitle,
    required this.onTagTap,
    required this.onActorTap,
    required this.onFollowTap,
    required this.isFollowUpdating,
  });

  final int sampleMovieCount;
  final List<TasteProfileTagDto> tags;
  final List<TasteProfileActressDto> actresses;
  final String actressTitle;
  final ValueChanged<int>? onTagTap;
  final ValueChanged<int>? onActorTap;
  final ValueChanged<TasteProfileActressDto>? onFollowTap;
  final bool Function(TasteProfileActressDto entry) isFollowUpdating;

  @override
  Widget build(BuildContext context) {
    final hasTags = tags.isNotEmpty;
    final hasActresses = actresses.isNotEmpty;

    final tagsBlock = _TasteTagsBlock(tags: tags, onTagTap: onTagTap);
    final actressesBlock = TasteActressSection(
      title: actressTitle,
      entries: actresses,
      onActorTap: onActorTap == null
          ? null
          : (entry) => onActorTap!(entry.actor.id),
      onFollowTap: onFollowTap,
      isFollowUpdating: isFollowUpdating,
    );

    final Widget body;
    if (!hasTags) {
      body = actressesBlock;
    } else if (!hasActresses) {
      body = tagsBlock;
    } else {
      body = TasteSplitLayout(
        primaryFlex: 3,
        primary: tagsBlock,
        secondaryFlex: 2,
        secondary: actressesBlock,
      );
    }

    return TastePanel(
      title: AppLocalizations.of(context).discoveryTasteTitle,
      icon: Icons.auto_awesome_rounded,
      sampleMovieCount: sampleMovieCount,
      child: body,
    );
  }
}

class _TasteTagsBlock extends StatelessWidget {
  const _TasteTagsBlock({required this.tags, required this.onTagTap});

  final List<TasteProfileTagDto> tags;
  final ValueChanged<int>? onTagTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TasteSectionLabel(
          label: AppLocalizations.of(context).discoveryTasteFrequentTags,
        ),
        SizedBox(height: context.appSpacing.sm),
        Wrap(
          spacing: tokens.movieDetailPillGap,
          runSpacing: tokens.movieDetailPillGap,
          children: <Widget>[
            for (var index = 0; index < tags.length; index++)
              TasteTagPill(
                key: Key('taste-tag-${tags[index].tagId}'),
                name: tags[index].name,
                matchedMovieCount: tags[index].matchedMovieCount,
                rank: index,
                onTap: onTagTap == null
                    ? null
                    : () => onTagTap!(tags[index].tagId),
              ),
          ],
        ),
      ],
    );
  }
}
