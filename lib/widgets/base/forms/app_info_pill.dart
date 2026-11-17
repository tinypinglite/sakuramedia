import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

class AppInfoTile extends StatelessWidget {
  const AppInfoTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.appSpacing.sm,
        vertical: context.appSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.appColors.surfaceCard,
        borderRadius: context.appRadius.smBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: Text(
        '$label: $value',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }
}

@Deprecated('Use AppInfoTile instead.')
class AppInfoPill extends AppInfoTile {
  const AppInfoPill({super.key, required super.label, required super.value});
}
