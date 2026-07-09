import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actors/actor_summary_card.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';

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
      skeletonBuilder: (context, index) => _ActorSummaryCardSkeleton(
        key: Key('actor-summary-card-skeleton-$index'),
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

class _ActorSummaryCardSkeleton extends StatelessWidget {
  const _ActorSummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.lgBorder,
        border: Border.all(color: context.appColors.borderSubtle),
        boxShadow: context.appShadows.card,
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: context.appComponentTokens.movieCardAspectRatio,
        child: DecoratedBox(
          key: Key('actor-summary-card-skeleton-poster-${_indexFromKey()}'),
          decoration: BoxDecoration(color: context.appColors.surfaceMuted),
        ),
      ),
    );
  }

  String _indexFromKey() {
    final currentKey = key;
    if (currentKey is ValueKey<String>) {
      const prefix = 'actor-summary-card-skeleton-';
      if (currentKey.value.startsWith(prefix)) {
        return currentKey.value.substring(prefix.length);
      }
      return currentKey.value;
    }
    return 'unknown';
  }
}
