import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

/// 口味画像里的标签胶囊：前三名有品牌色层次，其余走中性色。
///
/// [rank] 从 0 开始，仅用于视觉分层；实际排序由后端完成。
class TasteTagPill extends StatelessWidget {
  const TasteTagPill({
    super.key,
    required this.name,
    required this.matchedMovieCount,
    required this.rank,
    this.onTap,
  });

  final String name;
  final int matchedMovieCount;
  final int rank;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final tokens = context.appComponentTokens;
    final spacing = context.appSpacing;

    final isTop = rank == 0;
    final isRunnerUp = rank == 1 || rank == 2;
    final background = isTop
        ? null
        : isRunnerUp
        ? colors.primary.withValues(alpha: 0.12)
        : appColors.surfaceMuted;
    final borderColor = isTop
        ? null
        : isRunnerUp
        ? colors.primary.withValues(alpha: 0.24)
        : appColors.borderSubtle;
    final foreground = isTop
        ? colors.onPrimary
        : isRunnerUp
        ? colors.primary
        : context.appTextPalette.secondary;
    final countColor = foreground.withValues(alpha: 0.72);

    final pill = Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.movieDetailPillHorizontalPadding,
        vertical: tokens.movieDetailPillVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: background,
        gradient: isTop
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[colors.primary, colors.secondary],
              )
            : null,
        borderRadius: context.appRadius.pillBorder,
        border: borderColor == null ? null : Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isTop) ...<Widget>[
            Icon(
              Icons.local_fire_department_rounded,
              size: tokens.iconSize2xs,
              color: foreground,
            ),
            SizedBox(width: spacing.xs),
          ],
          Text(
            name,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: isTop ? AppTextWeight.semibold : AppTextWeight.medium,
            ).copyWith(color: foreground),
          ),
          SizedBox(width: spacing.xs),
          Text(
            '$matchedMovieCount',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.medium,
            ).copyWith(color: countColor),
          ),
        ],
      ),
    );

    return AppInteractiveSurface(
      onTap: onTap,
      semanticLabel: AppLocalizations.of(context).discoveryTagSemanticLabel(name),
      child: pill,
    );
  }
}
