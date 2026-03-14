import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/image_search/data/image_search_result_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/app_image_action_trigger.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

class ImageSearchResultCard extends StatelessWidget {
  const ImageSearchResultCard({
    super.key,
    required this.item,
    this.onTap,
    this.onRequestMenu,
  });

  final ImageSearchResultItemDto item;
  final VoidCallback? onTap;
  final ValueChanged<Offset>? onRequestMenu;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final spacing = context.appSpacing;
    final scoreText = formatImageSearchScore(item.score);

    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('image-search-result-card-${item.thumbnailId}'),
        borderRadius: context.appRadius.lgBorder,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: context.appRadius.lgBorder,
            border: Border.all(color: colors.borderSubtle),
            boxShadow: context.appShadows.card,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MaskedImage(url: item.image.bestAvailableUrl, fit: BoxFit.cover),
              Positioned(
                right: spacing.sm,
                bottom: spacing.sm,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: context.appRadius.smBorder,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.sm,
                      vertical: spacing.xs,
                    ),
                    child: Text(
                      scoreText,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final requestMenu = onRequestMenu;
    if (requestMenu == null) {
      return child;
    }
    return AppImageActionTrigger(
      onTap: onTap,
      onRequestMenu: requestMenu,
      child: child,
    );
  }
}

String formatImageSearchScore(double score) {
  return '${(score * 100).toStringAsFixed(1)}%';
}

String formatImageSearchOffset(int seconds) {
  return formatMediaTimecode(seconds);
}
