import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 口味区块的小标题：品牌渐变圆点 + 文案。
class TasteSectionLabel extends StatelessWidget {
  const TasteSectionLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: context.appSpacing.xs,
          height: context.appSpacing.xs,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: <Color>[colors.primary, colors.secondary],
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    );
  }
}
