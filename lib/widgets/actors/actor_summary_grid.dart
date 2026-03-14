import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actors/actor_summary_card.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

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
    if (isLoading) {
      return _ActorSummaryGridLayout(
        children: List<Widget>.generate(
          placeholderCount,
          (index) => _ActorSummaryCardSkeleton(
            key: Key('actor-summary-card-skeleton-$index'),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return AppEmptyState(message: errorMessage!);
    }

    if (items.isEmpty) {
      return AppEmptyState(message: emptyMessage);
    }

    return _ActorSummaryGridLayout(
      children: items
          .map(
            (actor) => ActorSummaryCard(
              actor: actor,
              onTap: onActorTap == null ? null : () => onActorTap!(actor),
              onSubscriptionTap:
                  onActorSubscriptionTap == null
                      ? null
                      : () => onActorSubscriptionTap!(actor),
              isSubscriptionUpdating:
                  isActorSubscriptionUpdating?.call(actor) ?? false,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ActorSummaryGridLayout extends StatelessWidget {
  const _ActorSummaryGridLayout({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing.md;
        final componentTokens = context.appComponentTokens;
        final columns = _resolveColumnCount(
          width: constraints.maxWidth,
          spacing: spacing,
          targetWidth: componentTokens.movieCardTargetWidth,
        );

        return GridView.builder(
          key: const Key('actor-summary-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: componentTokens.movieCardAspectRatio,
          ),
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }

  int _resolveColumnCount({
    required double width,
    required double spacing,
    required double targetWidth,
  }) {
    final columns = ((width + spacing) / (targetWidth + spacing)).floor();
    return math.max(2, math.min(6, columns));
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
