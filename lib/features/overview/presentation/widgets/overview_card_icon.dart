import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 概览主卡的标题图标：品牌色实心渐变块，用来建立两张主卡的第一眼识别。
class OverviewHeroIcon extends StatelessWidget {
  const OverviewHeroIcon({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: context.appSpacing.xxxl,
      height: context.appSpacing.xxxl,
      decoration: BoxDecoration(
        borderRadius: context.appRadius.mdBorder,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            scheme.primary,
            Color.lerp(scheme.primary, scheme.secondary, 0.72)!,
          ],
        ),
        border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.18)),
      ),
      child: Icon(
        icon,
        size: context.appComponentTokens.iconSizeMd,
        color: scheme.onPrimary,
      ),
    );
  }
}

/// 概览页次级卡片的标题图标：中性底 + 品牌色图标。
///
/// 主卡「媒体资产」使用渐变图标块，不在这个层级里重复。
class OverviewCardIcon extends StatelessWidget {
  const OverviewCardIcon({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.appSpacing.xl,
      height: context.appSpacing.xl,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.smBorder,
      ),
      child: Icon(
        icon,
        size: context.appComponentTokens.iconSizeSm,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
