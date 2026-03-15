import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

class MomentCard extends StatelessWidget {
  const MomentCard({super.key, required this.item, this.onTap});

  final MomentListItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final labelTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
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
            child: AspectRatio(
              aspectRatio: 16 / 10,
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
                                item.movieNumber,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
