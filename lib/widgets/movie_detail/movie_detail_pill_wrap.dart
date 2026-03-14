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
    final backgroundColor = Theme.of(context).colorScheme.primary;
    final radius = context.appRadius.xsBorder;
    final tokens = context.appComponentTokens;
    final colors = context.appColors;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.movieDetailPillHorizontalPadding,
        vertical: tokens.movieDetailPillVerticalPadding,
      ),
      child: Text(
        item.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.textOnMedia,
          height: 1.2,
          fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );

    if (item.onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(color: backgroundColor, borderRadius: radius),
        child: content,
      );
    }

    return Material(
      color: backgroundColor,
      borderRadius: radius,
      child: InkWell(borderRadius: radius, onTap: item.onTap, child: content),
    );
  }
}
