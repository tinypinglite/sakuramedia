import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/tv/tv_focusable.dart';

class TvActorChip extends StatelessWidget {
  const TvActorChip({
    super.key,
    required this.name,
    required this.onPressed,
    this.imageUrl,
  });

  final String name;
  final String? imageUrl;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onPressed: onPressed,
      borderRadius: context.appRadius.pillBorder,
      scale: 1.025,
      semanticLabel: name,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          context.appSpacing.xs,
          context.appSpacing.xs,
          context.appSpacing.lg,
          context.appSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: context.appColors.surfaceElevated,
          borderRadius: context.appRadius.pillBorder,
          border: Border.all(color: context.appColors.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: SizedBox(
                width: context.appComponentTokens.iconSize4xl,
                height: context.appComponentTokens.iconSize4xl,
                child: imageUrl != null && imageUrl!.trim().isNotEmpty
                    ? MaskedImage(url: imageUrl!, fit: BoxFit.cover)
                    : ColoredBox(color: context.appColors.surfaceMuted),
              ),
            ),
            SizedBox(width: context.appSpacing.sm),
            Text(
              name,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
