import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

class MovieDetailPillItem {
  const MovieDetailPillItem({
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

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
          .map((item) => _MovieDetailPill(item: item))
          .toList(growable: false),
    );
  }
}

class _MovieDetailPill extends StatelessWidget {
  const _MovieDetailPill({required this.item});

  final MovieDetailPillItem item;

  @override
  Widget build(BuildContext context) {
    final isInteractive = item.onTap != null;
    final primary = Theme.of(context).colorScheme.primary;
    final staticBorderColor = primary.withValues(alpha: 0.22);
    final backgroundColor =
        isInteractive
            ? (item.isSelected
                ? primary.withValues(alpha: 0.14)
                : context.appColors.surfaceMuted)
            : primary.withValues(alpha: 0.12);
    final foregroundColor =
        isInteractive
            ? (item.isSelected ? primary : context.appTextPalette.primary)
            : primary;
    final borderColor =
        isInteractive
            ? (item.isSelected ? primary : context.appColors.borderSubtle)
            : staticBorderColor;
    final radius = context.appRadius.xsBorder;
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
          weight:
              item.isSelected ? AppTextWeight.semibold : AppTextWeight.medium,
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

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: DecoratedBox(
        decoration: decoration,
        child: InkWell(borderRadius: radius, onTap: item.onTap, child: content),
      ),
    );
  }
}
