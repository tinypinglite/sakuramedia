import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';

/// 「外部数据源」JavDB 连通性状态徽章行，桌面 overview 瓦片与
/// 移动系统概览瓦片共用。
///
/// 不用 ✅/❌ emoji 文本表达状态；[AppStatusChip] 走 MaterialIcons 图标字体，
/// 在桌面端和移动端保持一致。
class ExternalDataSourceStatusChips extends StatelessWidget {
  const ExternalDataSourceStatusChips({
    super.key,
    required this.javdbHealthy,
    required this.isTesting,
    this.keyPrefix = 'overview',
  });

  final bool? javdbHealthy;
  final bool isTesting;

  /// 让同一组徽章在不同页面产生不同 Key（桌面/移动各自的测试锚点）。
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.appSpacing.xs,
      runSpacing: context.appSpacing.xs,
      children: [
        AppStatusChip(
          key: Key('$keyPrefix-external-data-source-javdb'),
          label: 'JavDB',
          palette: _resolvePalette(context, javdbHealthy),
          isBusy: isTesting,
          dense: true,
        ),
      ],
    );
  }

  AppStatusChipPalette _resolvePalette(BuildContext context, bool? healthy) {
    if (healthy == null) {
      return AppStatusChipPalette.neutral(context);
    }
    return healthy
        ? AppStatusChipPalette.success(context)
        : AppStatusChipPalette.error(context);
  }
}
