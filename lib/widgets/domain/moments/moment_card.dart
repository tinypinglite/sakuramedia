import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/moments/presentation/moment_listing_models.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';

class MomentCard extends StatelessWidget {
  const MomentCard({
    super.key,
    required this.item,
    this.onTap,
    this.onAddToCollection,
  });

  final MomentListItem item;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCollection;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final labelTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.onMedia,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('moment-card-${item.pointId}'),
        borderRadius: context.appRadius.lgBorder,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.appColors.surfaceCard,
            borderRadius: context.appRadius.lgBorder,
            border: Border.all(color: context.appColors.borderSubtle),
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
                if (onAddToCollection != null)
                  Positioned(
                    top: spacing.xs,
                    right: spacing.xs,
                    child: Tooltip(
                      message: '加入时刻合集',
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.48),
                        borderRadius: context.appRadius.pillBorder,
                        child: IconButton(
                          key: Key('moment-add-to-collection-${item.pointId}'),
                          tooltip: '加入时刻合集',
                          color: Colors.white,
                          iconSize: context.appComponentTokens.iconSizeSm,
                          onPressed: onAddToCollection,
                          icon: const Icon(Icons.bookmarks_outlined),
                        ),
                      ),
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
