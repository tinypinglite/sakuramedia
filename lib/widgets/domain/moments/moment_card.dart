import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/selection_check_badge.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

class MomentCard extends StatelessWidget {
  const MomentCard({
    super.key,
    required this.item,
    this.onTap,
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.onLongPress,
  });

  final MomentListItem item;
  final VoidCallback? onTap;
  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<bool>? onSelectedChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final labelTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.onMedia,
    );
    final selected = selectionMode && isSelected;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('moment-card-${item.pointId}'),
        borderRadius: context.appRadius.lgBorder,
        onTap: selectionMode
            ? () => onSelectedChanged?.call(!isSelected)
            : onTap,
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.appColors.surfaceCard,
            borderRadius: context.appRadius.lgBorder,
            border: Border.all(
              color: selected
                  ? context.appColors.selectionBorder
                  : context.appColors.borderSubtle,
              width: selected ? 2 : 1,
            ),
            boxShadow: context.appShadows.card,
          ),
          child: ClipRRect(
            borderRadius: context.appRadius.lgBorder,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MaskedImage(
                  url: item.image?.bestAvailableUrl ?? '',
                  fit: BoxFit.cover,
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.44),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: spacing.md,
                        vertical: spacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.displayLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: labelTextStyle,
                            ),
                          ),
                          SizedBox(width: spacing.sm),
                          Text(
                            formatMediaTimecode(item.offsetSeconds),
                            style: labelTextStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (selectionMode)
                  Positioned(
                    top: spacing.xs,
                    left: spacing.xs,
                    child: IgnorePointer(
                      child: SelectionCheckBadge(isSelected: isSelected),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
