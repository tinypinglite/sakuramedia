import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/features/clips/data/dto/media_clip_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/media/masked_image.dart';

class ClipCard extends StatelessWidget {
  const ClipCard({
    super.key,
    required this.clip,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  });

  final MediaClipDto clip;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final coverUrl = clip.coverImage?.bestAvailableUrl;
    final title = clip.title.trim();
    final metaParts = <String>[
      if (clip.movieNumber != null && clip.movieNumber!.isNotEmpty)
        clip.movieNumber!
      else
        '无番号',
      formatMediaTimecode(clip.durationSeconds),
      if (clip.fileSizeBytes > 0) formatFileSize(clip.fileSizeBytes),
    ];

    return Material(
      color: colors.surfaceCard,
      borderRadius: context.appRadius.mdBorder,
      child: InkWell(
        key: Key('clip-card-tap-${clip.clipId}'),
        borderRadius: context.appRadius.mdBorder,
        onTap: onPlay,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: context.appRadius.mdBorder,
            border: Border.all(color: colors.borderSubtle),
          ),
          padding: EdgeInsets.all(spacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: context.appRadius.smBorder,
                child: SizedBox(
                  width: 152,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (coverUrl != null && coverUrl.isNotEmpty)
                          MaskedImage(url: coverUrl, fit: BoxFit.cover)
                        else
                          ColoredBox(color: colors.surfaceMuted),
                        const _ClipPlayOverlay(),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title.isEmpty ? '未命名切片' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      metaParts.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.sm),
              AppIconButton(
                key: Key('clip-card-rename-${clip.clipId}'),
                tooltip: '重命名',
                onPressed: onRename,
                icon: Icon(
                  Icons.edit_outlined,
                  size: context.appComponentTokens.iconSizeSm,
                ),
              ),
              SizedBox(width: spacing.xs),
              AppIconButton(
                key: Key('clip-card-delete-${clip.clipId}'),
                tooltip: '删除',
                iconColor: context.appTextPalette.error,
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: context.appComponentTokens.iconSizeSm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClipPlayOverlay extends StatelessWidget {
  const _ClipPlayOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
      ),
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: context.appComponentTokens.iconSize2xl,
        ),
      ),
    );
  }
}
