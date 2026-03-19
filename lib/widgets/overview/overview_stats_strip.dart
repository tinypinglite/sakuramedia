import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class OverviewStatItem {
  const OverviewStatItem({
    required this.id,
    required this.label,
    required this.value,
  });

  final String id;
  final String label;
  final String value;
}

class OverviewStatsStrip extends StatelessWidget {
  const OverviewStatsStrip({
    super.key,
    required this.items,
    required this.isLoading,
    this.errorMessage,
  });

  final List<OverviewStatItem> items;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (isLoading) {
      content = Wrap(
        spacing: context.appSpacing.lg,
        runSpacing: context.appSpacing.lg,
        children: List<Widget>.generate(
          6,
          (index) => const _OverviewStatSkeleton(),
        ),
      );
    } else if (errorMessage != null) {
      content = Text(
        errorMessage!,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      content = Wrap(
        spacing: context.appSpacing.lg,
        runSpacing: context.appSpacing.lg,
        children: items
            .map((item) => _OverviewStatTile(item: item))
            .toList(growable: false),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('系统信息', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: context.appSpacing.lg),
        content,
      ],
    );
  }
}

class _OverviewStatTile extends StatelessWidget {
  const _OverviewStatTile({required this.item});

  final OverviewStatItem item;

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;

    return Container(
      key: Key('overview-stat-${item.id}'),
      constraints: BoxConstraints(
        minWidth: componentTokens.overviewStatTileMinWidth,
        maxWidth: componentTokens.overviewStatTileMaxWidth,
      ),
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.lgBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.appColors.textMuted),
          ),
          SizedBox(height: context.appSpacing.sm),
          Text(
            item.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: context.appColors.textPrimary,
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _OverviewStatSkeleton extends StatelessWidget {
  const _OverviewStatSkeleton();

  @override
  Widget build(BuildContext context) {
    final componentTokens = context.appComponentTokens;

    return Container(
      constraints: BoxConstraints(
        minWidth: componentTokens.overviewStatTileMinWidth,
        maxWidth: componentTokens.overviewStatTileMaxWidth,
      ),
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.lgBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: componentTokens.overviewStatSkeletonLabelWidth,
            height: componentTokens.overviewStatSkeletonLabelHeight,
            decoration: BoxDecoration(
              color: context.appColors.borderSubtle,
              borderRadius: context.appRadius.pillBorder,
            ),
          ),
          SizedBox(height: context.appSpacing.md),
          Container(
            width: componentTokens.overviewStatSkeletonValueWidth,
            height: componentTokens.overviewStatSkeletonValueHeight,
            decoration: BoxDecoration(
              color: context.appColors.borderSubtle,
              borderRadius: context.appRadius.mdBorder,
            ),
          ),
        ],
      ),
    );
  }
}
