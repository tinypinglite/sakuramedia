import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_cover_card_skeleton.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_summary_card.dart';

class ActorSummaryGrid extends StatelessWidget {
  const ActorSummaryGrid({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
    this.onActorTap,
    this.onActorSubscriptionTap,
    this.isActorSubscriptionUpdating,
    this.emptyMessage = '当前没有可展示的女优数据。',
    this.placeholderCount = 8,
  });

  final List<ActorListItemDto> items;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<ActorListItemDto>? onActorTap;
  final ValueChanged<ActorListItemDto>? onActorSubscriptionTap;
  final bool Function(ActorListItemDto actor)? isActorSubscriptionUpdating;
  final String emptyMessage;
  final int placeholderCount;

  @override
  Widget build(BuildContext context) {
    return AppAdaptiveCardGrid<ActorListItemDto>(
      gridKey: const Key('actor-summary-grid'),
      items: items,
      isLoading: isLoading,
      errorMessage: errorMessage,
      emptyMessage: emptyMessage,
      placeholderCount: placeholderCount,
      skeletonBuilder: (context, index) => AppCoverCardSkeleton(
        key: Key('actor-summary-card-skeleton-$index'),
        posterKey: Key('actor-summary-card-skeleton-poster-$index'),
        aspectRatio: context.appComponentTokens.movieCardAspectRatio,
      ),
      itemBuilder: (context, actor, index) => ActorSummaryCard(
        actor: actor,
        onTap: onActorTap == null ? null : () => onActorTap!(actor),
        onSubscriptionTap: onActorSubscriptionTap == null
            ? null
            : () => onActorSubscriptionTap!(actor),
        isSubscriptionUpdating:
            isActorSubscriptionUpdating?.call(actor) ?? false,
      ),
    );
  }
}

