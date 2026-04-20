import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class OverviewStatItem {
  const OverviewStatItem({
    required this.id,
    required this.label,
    required this.value,
    this.isLoading = false,
  });

  final String id;
  final String label;
  final String value;
  final bool isLoading;
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
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ).copyWith(color: Theme.of(context).colorScheme.error),
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
        Text(
          '系统信息',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
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
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
          if (item.isLoading)
            SizedBox(
              width: componentTokens.iconSizeMd,
              height: componentTokens.iconSizeMd,
              child: CircularProgressIndicator.adaptive(
                key: Key('overview-stat-loading-${item.id}'),
                strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
              ),
            )
          else
            Text(
              item.value,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
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
