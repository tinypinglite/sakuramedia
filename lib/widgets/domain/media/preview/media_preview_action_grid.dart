import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_mobile_skeleton.dart';

enum MediaPreviewActionGridLayout { wrap, fixedColumns, horizontalScroll }

class MediaPreviewActionItem {
  const MediaPreviewActionItem({
    required this.label,
    required this.icon,
    this.onTap,
    this.isLoading = false,
    this.visible = true,
    this.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool visible;
  final Key? key;
}

class MediaPreviewActionGrid extends StatelessWidget {
  const MediaPreviewActionGrid({
    super.key,
    required this.actions,
    this.layout = MediaPreviewActionGridLayout.wrap,
    this.columns = 3,
    this.spacing,
    this.tileWidth = 92,
    this.gridKey,
    this.isLoading = false,
    this.loadingItemCount = 4,
  }) : assert(columns > 0, 'columns must be greater than zero.'),
       assert(loadingItemCount >= 0, 'loadingItemCount must not be negative.');

  final List<MediaPreviewActionItem> actions;
  final MediaPreviewActionGridLayout layout;
  final int columns;
  final double? spacing;
  final double tileWidth;
  final Key? gridKey;
  final bool isLoading;
  final int loadingItemCount;

  @override
  Widget build(BuildContext context) {
    final resolvedSpacing = spacing ?? context.appSpacing.md;
    if (isLoading) {
      return _buildLoadingState(context, resolvedSpacing);
    }

    final visibleActions = actions
        .where((action) => action.visible)
        .toList(growable: false);
    if (visibleActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return switch (layout) {
      MediaPreviewActionGridLayout.wrap => Wrap(
        key: gridKey,
        alignment: WrapAlignment.start,
        runAlignment: WrapAlignment.start,
        spacing: resolvedSpacing,
        runSpacing: resolvedSpacing,
        children: [
          for (final action in visibleActions)
            SizedBox(
              width: tileWidth,
              child: MediaPreviewActionTile(item: action),
            ),
        ],
      ),
      MediaPreviewActionGridLayout.fixedColumns => GridView.builder(
        key: gridKey,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visibleActions.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: resolvedSpacing,
          mainAxisSpacing: resolvedSpacing,
          childAspectRatio: 1.5,
        ),
        itemBuilder:
            (context, index) =>
                MediaPreviewActionTile(item: visibleActions[index]),
      ),
      MediaPreviewActionGridLayout.horizontalScroll => ScrollConfiguration(
        key: gridKey,
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < visibleActions.length; index++) ...[
                if (index > 0) SizedBox(width: resolvedSpacing),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: tileWidth),
                  child: MediaPreviewActionTile(item: visibleActions[index]),
                ),
              ],
            ],
          ),
        ),
      ),
    };
  }

  Widget _buildLoadingState(BuildContext context, double resolvedSpacing) {
    if (loadingItemCount == 0) {
      return const SizedBox.shrink();
    }

    final skeletons = List<Widget>.generate(
      loadingItemCount,
      (index) => _MediaPreviewActionSkeleton(index: index),
      growable: false,
    );

    return switch (layout) {
      MediaPreviewActionGridLayout.wrap => Wrap(
        key: gridKey,
        alignment: WrapAlignment.start,
        runAlignment: WrapAlignment.start,
        spacing: resolvedSpacing,
        runSpacing: resolvedSpacing,
        children: [
          for (final skeleton in skeletons)
            SizedBox(width: tileWidth, child: skeleton),
        ],
      ),
      MediaPreviewActionGridLayout.fixedColumns => GridView.builder(
        key: gridKey,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: skeletons.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: resolvedSpacing,
          mainAxisSpacing: resolvedSpacing,
          childAspectRatio: 1.5,
        ),
        itemBuilder: (context, index) => skeletons[index],
      ),
      MediaPreviewActionGridLayout.horizontalScroll => ScrollConfiguration(
        key: gridKey,
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < skeletons.length; index++) ...[
                if (index > 0) SizedBox(width: resolvedSpacing),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: tileWidth),
                  child: skeletons[index],
                ),
              ],
            ],
          ),
        ),
      ),
    };
  }
}

class _MediaPreviewActionSkeleton extends StatelessWidget {
  const _MediaPreviewActionSkeleton({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      key: Key('media-preview-action-skeleton-$index'),
      mainAxisSize: MainAxisSize.min,
      children: [
        AppSkeletonBlock(
          width: 40,
          height: 40,
          radius: context.appRadius.pillBorder,
        ),
        SizedBox(height: spacing.xs),
        const AppSkeletonBlock(width: 40, height: 12),
      ],
    );
  }
}

class MediaPreviewActionTile extends StatelessWidget {
  const MediaPreviewActionTile({super.key, required this.item});

  final MediaPreviewActionItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final tokens = context.appComponentTokens;
    final canTap = item.onTap != null && !item.isLoading;
    final spacing = context.appSpacing;
    final iconColor =
        canTap ? context.appTextPalette.primary : context.appTextPalette.muted;
    final textTone = canTap ? AppTextTone.primary : AppTextTone.muted;

    return Material(
      key: item.key,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: context.appRadius.smBorder,
        onTap: canTap ? item.onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: context.appRadius.pillBorder,
                border: Border.all(color: colors.borderSubtle),
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child:
                      item.isLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                          )
                          : Icon(
                            item.icon,
                            size: tokens.iconSizeMd,
                            color: iconColor,
                          ),
                ),
              ),
            ),
            SizedBox(height: spacing.xs),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: textTone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
