import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

enum MediaPreviewActionGridLayout { wrap, horizontalScroll }

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
    this.spacing,
    this.tileWidth = 92,
    this.gridKey,
    this.isLoading = false,
    this.loadingItemCount = 4,
  }) : assert(loadingItemCount >= 0, 'loadingItemCount must not be negative.');

  final List<MediaPreviewActionItem> actions;
  final MediaPreviewActionGridLayout layout;
  final double? spacing;
  final double tileWidth;
  final Key? gridKey;
  final bool isLoading;
  final int loadingItemCount;

  @override
  Widget build(BuildContext context) {
    final resolvedSpacing = spacing ?? context.appSpacing.md;
    if (isLoading) {
      // loading 用占位动作渲染真实动作格，由 [AppSkeletonizer] 灰化。
      return AppSkeletonizer(
        enabled: true,
        child: _buildLayout(context, resolvedSpacing, _placeholderActions()),
      );
    }

    final visibleActions = actions
        .where((action) => action.visible)
        .toList(growable: false);
    if (visibleActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildLayout(context, resolvedSpacing, visibleActions);
  }

  List<MediaPreviewActionItem> _placeholderActions() {
    return List<MediaPreviewActionItem>.generate(
      loadingItemCount,
      (index) => MediaPreviewActionItem(
        label: BoneMock.words(1),
        icon: Icons.photo_library_outlined,
      ),
      growable: false,
    );
  }

  Widget _buildLayout(
    BuildContext context,
    double resolvedSpacing,
    List<MediaPreviewActionItem> items,
  ) {
    return switch (layout) {
      MediaPreviewActionGridLayout.wrap => Wrap(
        key: gridKey,
        alignment: WrapAlignment.start,
        runAlignment: WrapAlignment.start,
        spacing: resolvedSpacing,
        runSpacing: resolvedSpacing,
        children: [
          for (final action in items)
            SizedBox(
              width: tileWidth,
              child: MediaPreviewActionTile(item: action),
            ),
        ],
      ),
      MediaPreviewActionGridLayout.horizontalScroll => ScrollConfiguration(
        key: gridKey,
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0) SizedBox(width: resolvedSpacing),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: tileWidth),
                  child: MediaPreviewActionTile(item: items[index]),
                ),
              ],
            ],
          ),
        ),
      ),
    };
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
    final iconColor = canTap
        ? context.appTextPalette.primary
        : context.appTextPalette.muted;
    final textTone = canTap ? AppTextTone.primary : AppTextTone.muted;

    return AppInteractiveSurface(
      key: item.key,
      enabled: canTap,
      onTap: item.onTap,
      semanticLabel: item.label,
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
                child: item.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
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
    );
  }
}
