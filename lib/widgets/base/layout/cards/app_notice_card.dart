import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_stat_tile.dart';

/// 页面顶部的「说明 / 概览」卡片，双端(桌面 + 移动)通用。
///
/// 覆盖两种常见形态：
/// - **overview 系**（configuration 三个 mobile 页、playlists、llm 概览、桌面 playlists 顶部）：
///   `title` + `description` +（可选）`leadingIcon` +（可选）1–4 个统计块；圆角 `lg`。
/// - **提示条系**（account 改密页两处的 `_NoticeCard`）：只有 `leadingIcon` + `description`；
///   圆角自动缩小为 `md`。
///
/// 内部规则：
/// - 是否有 `title` **或** 非空 `stats` 之一 → 使用 `lgBorder`；否则 → `mdBorder`。
/// - `stats.length >= 4` → 自动排 2×2 grid；1–3 项 → 单排横列。
/// - 背景恒 `noticeSurface` + border=`borderSubtle`。
class AppNoticeCard extends StatelessWidget {
  const AppNoticeCard({
    super.key,
    this.leadingIcon,
    this.title,
    required this.description,
    this.stats = const <AppNoticeStat>[],
  });

  final IconData? leadingIcon;
  final String? title;
  final String description;
  final List<AppNoticeStat> stats;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;
    final theme = Theme.of(context);

    final headerHasFullShape = title != null || stats.isNotEmpty;
    final radius = headerHasFullShape
        ? context.appRadius.lgBorder
        : context.appRadius.mdBorder;

    final descriptionText = Text(
      description,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s12,
        weight: AppTextWeight.regular,
        tone: AppTextTone.secondary,
      ),
    );

    final Widget textColumn;
    if (title != null) {
      textColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title!,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.semibold,
              tone: AppTextTone.primary,
            ),
          ),
          SizedBox(height: spacing.xs),
          descriptionText,
        ],
      );
    } else {
      textColumn = descriptionText;
    }

    final Widget header;
    if (leadingIcon != null) {
      header = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            leadingIcon,
            size: componentTokens.iconSizeMd,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: spacing.sm),
          Expanded(child: textColumn),
        ],
      );
    } else {
      header = textColumn;
    }

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: colors.noticeSurface,
        borderRadius: radius,
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          if (stats.isNotEmpty) ...[
            SizedBox(height: spacing.md),
            _NoticeStatsGrid(stats: stats),
          ],
        ],
      ),
    );
  }
}

/// 供 [AppNoticeCard.stats] 使用的统计项数据。
class AppNoticeStat {
  const AppNoticeStat({
    required this.label,
    required this.value,
    this.valueSize = AppTextSize.s16,
  });

  final String label;
  final String value;
  final AppTextSize valueSize;
}

class _NoticeStatsGrid extends StatelessWidget {
  const _NoticeStatsGrid({required this.stats});

  final List<AppNoticeStat> stats;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    if (stats.length >= 4) {
      // 2 列自动换行网格；覆盖 indexers 页 4-tile 场景。
      final rows = <Widget>[];
      for (var i = 0; i < stats.length; i += 2) {
        if (rows.isNotEmpty) {
          rows.add(SizedBox(height: spacing.sm));
        }
        final left = stats[i];
        final right = i + 1 < stats.length ? stats[i + 1] : null;
        rows.add(
          Row(
            children: [
              Expanded(child: AppStatTile(
                  label: left.label,
                  value: left.value,
                  valueSize: left.valueSize,
                )),
              SizedBox(width: spacing.sm),
              Expanded(
                child: right == null
                    ? const SizedBox.shrink()
                    : AppStatTile(
                        label: right.label,
                        value: right.value,
                        valueSize: right.valueSize,
                      ),
              ),
            ],
          ),
        );
      }
      return Column(children: rows);
    }

    // 单排：1-3 项等宽平分。
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        children.add(SizedBox(width: spacing.sm));
      }
      children.add(
        Expanded(
          child: AppStatTile(
            label: stats[i].label,
            value: stats[i].value,
            valueSize: stats[i].valueSize,
          ),
        ),
      );
    }
    return Row(children: children);
  }
}
