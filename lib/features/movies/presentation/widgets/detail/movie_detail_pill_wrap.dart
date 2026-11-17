import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

class MovieDetailPillItem {
  const MovieDetailPillItem({
    this.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  final Key? key;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
}

class MovieDetailPillWrap extends StatelessWidget {
  const MovieDetailPillWrap({
    super.key,
    required this.items,
    required this.emptyMessage,
  });

  final List<MovieDetailPillItem> items;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(
        emptyMessage,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      );
    }

    final tokens = context.appComponentTokens;

    return Wrap(
      spacing: tokens.movieDetailPillGap,
      runSpacing: tokens.movieDetailPillGap,
      children: items
          .map((item) => _MovieDetailPill(key: item.key, item: item))
          .toList(growable: false),
    );
  }
}

class _MovieDetailPill extends StatelessWidget {
  const _MovieDetailPill({super.key, required this.item});

  final MovieDetailPillItem item;

  @override
  Widget build(BuildContext context) {
    final isInteractive = item.onTap != null;
    final primary = Theme.of(context).colorScheme.primary;
    // 描边胶囊（对齐封面卡上「热度」徽标那套语言）：只有一层半透明底色，靠 1px
    // 边框成形，底下的封面底色透上来（当前 0.2，调小更透、调大更实）。
    // 选中态给品牌底色。
    final backgroundColor = item.isSelected
        ? primary.withValues(alpha: 0.14)
        : context.appColors.surfaceCard.withValues(alpha: 0.2);
    final foregroundColor = item.isSelected
        ? primary
        : (isInteractive ? context.appTextPalette.primary : primary);
    // 边框取正文色的淡化版：`borderSubtle` / `borderStrong` 是给纯白底配的，
    // 压在详情页的带色底上会糊到看不见。
    final borderColor = item.isSelected
        ? primary
        : context.appTextPalette.primary.withValues(alpha: 0.26);
    final radius = context.appRadius.pillBorder;
    final tokens = context.appComponentTokens;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.movieDetailPillHorizontalPadding,
        vertical: tokens.movieDetailPillVerticalPadding,
      ),
      child: Text(
        item.label,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: item.isSelected
              ? AppTextWeight.semibold
              : AppTextWeight.medium,
          tone: AppTextTone.primary,
        ).copyWith(color: foregroundColor),
      ),
    );

    final decoration = BoxDecoration(
      color: backgroundColor,
      borderRadius: radius,
      border: Border.all(color: borderColor),
    );

    if (!isInteractive) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return DecoratedBox(
      decoration: decoration,
      child: AppInteractiveSurface(onTap: item.onTap, child: content),
    );
  }
}
