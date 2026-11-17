import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_candidate_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_avatar.dart';

class ActorCandidateSliver extends StatelessWidget {
  const ActorCandidateSliver({
    super.key,
    required this.candidates,
    required this.importingCandidateIds,
    required this.onOpenActor,
    required this.onImport,
  });

  final List<ActorCandidateDto> candidates;
  final Set<String> importingCandidateIds;
  final ValueChanged<ActorCandidateDto> onOpenActor;
  final ValueChanged<ActorCandidateDto> onImport;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return SliverPadding(
      padding: EdgeInsets.only(bottom: spacing.lg),
      sliver: SliverList.builder(
        itemCount: candidates.length,
        itemBuilder: (context, index) {
          final candidate = candidates[index];
          return Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : spacing.sm),
            child: _ActorCandidateCard(
              candidate: candidate,
              isImporting: importingCandidateIds.contains(
                candidate.candidateId,
              ),
              onOpenActor: () => onOpenActor(candidate),
              onImport: () => onImport(candidate),
            ),
          );
        },
      ),
    );
  }
}

class _ActorCandidateCard extends StatelessWidget {
  const _ActorCandidateCard({
    required this.candidate,
    required this.isImporting,
    required this.onOpenActor,
    required this.onImport,
  });

  final ActorCandidateDto candidate;
  final bool isImporting;
  final VoidCallback onOpenActor;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final exists = candidate.existingActorId != null;
    final aliases = candidate.aliasNames.take(4).join(' / ');
    return AppContentCard(
      key: Key('actor-candidate-${candidate.candidateId}'),
      padding: EdgeInsets.all(spacing.md),
      child: Row(
        children: [
          ActorAvatar(
            imageUrl: candidate.avatarUrl,
            size: context.appComponentTokens.iconSize2xl,
            placeholderKey: Key(
              'actor-candidate-avatar-placeholder-${candidate.candidateId}',
            ),
          ),
          SizedBox(width: spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        candidate.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                    ),
                    if (exists) ...[
                      SizedBox(width: spacing.xs),
                      Text(
                        l10n.actorCandidateExisting,
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s10,
                          weight: AppTextWeight.medium,
                          tone: AppTextTone.success,
                        ),
                      ),
                    ],
                  ],
                ),
                if (aliases.isNotEmpty) ...[
                  SizedBox(height: spacing.xs),
                  Text(
                    aliases,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s12,
                      tone: AppTextTone.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: spacing.md),
          AppButton(
            key: Key('actor-candidate-action-${candidate.candidateId}'),
            label: exists ? l10n.actorCandidateView : l10n.actorCandidateImport,
            size: AppButtonSize.small,
            variant: exists
                ? AppButtonVariant.secondary
                : AppButtonVariant.primary,
            isLoading: isImporting,
            onPressed: isImporting ? null : (exists ? onOpenActor : onImport),
          ),
        ],
      ),
    );
  }
}
