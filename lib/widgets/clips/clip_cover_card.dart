import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clips/data/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

/// 移动端切片网格卡：整卡即封面 + 底部一条信息栏（左番号、右时长，连成一行），
/// 仿「时刻」卡 [MomentCard] 的版式。整卡点击触发 [onTap]（通常弹出操作抽屉）。
class ClipCoverCard extends StatelessWidget {
  const ClipCoverCard({super.key, required this.clip, required this.onTap});

  final MediaClipDto clip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final coverUrl = clip.coverImage?.bestAvailableUrl ?? '';
    final number = clip.displayNumber;
    final labelTextStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      weight: AppTextWeight.regular,
      tone: AppTextTone.onMedia,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('clip-cover-card-${clip.clipId}'),
        borderRadius: context.appRadius.lgBorder,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: context.appRadius.lgBorder,
            border: Border.all(color: colors.borderSubtle),
            boxShadow: context.appShadows.card,
          ),
          child: ClipRRect(
            borderRadius: context.appRadius.lgBorder,
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverUrl.isNotEmpty)
                    MaskedImage(url: coverUrl, fit: BoxFit.cover)
                  else
                    ColoredBox(color: colors.surfaceMuted),
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
                                number,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: labelTextStyle,
                              ),
                            ),
                            SizedBox(width: spacing.sm),
                            Text(
                              formatMediaTimecode(clip.durationSeconds),
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
