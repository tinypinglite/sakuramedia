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
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: context.appColors.textSecondary,
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
    final theme = Theme.of(context);
    final isInteractive = item.onTap != null;
    final backgroundColor =
        isInteractive
            ? (item.isSelected
                ? theme.colorScheme.primary
                : context.appColors.surfaceMuted)
            : theme.colorScheme.primary;
    final foregroundColor =
        isInteractive
            ? (item.isSelected
                ? context.appColors.textOnMedia
                : context.appColors.textPrimary)
            : context.appColors.textOnMedia;
    final borderColor =
        isInteractive
            ? (item.isSelected
                ? theme.colorScheme.primary
                : context.appColors.borderSubtle)
            : Colors.transparent;
    final radius = context.appRadius.xsBorder;
    final tokens = context.appComponentTokens;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.movieDetailPillHorizontalPadding,
        vertical: tokens.movieDetailPillVerticalPadding,
      ),
      child: Text(
        item.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: foregroundColor,
          height: 1.2,
          fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
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
