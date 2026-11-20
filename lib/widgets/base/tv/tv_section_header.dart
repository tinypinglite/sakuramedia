import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

class TvSectionHeader extends StatelessWidget {
  const TvSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s32,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
        ),
        if (trailing case final trailing?) trailing,
      ],
    );
  }
}
