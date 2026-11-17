import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 影片详情页局部区块的空态面板（剧情图、标记点等）。
class MovieDetailEmptyPanel extends StatelessWidget {
  const MovieDetailEmptyPanel({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(context.appSpacing.lg),
      decoration: BoxDecoration(
        color: context.appColors.movieDetailEmptyBackground,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Text(
        message,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }
}
