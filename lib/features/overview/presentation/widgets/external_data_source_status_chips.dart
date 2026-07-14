import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_status_chip.dart';

/// 「外部数据源」JavDB / DMM 连通性状态徽章行，桌面 overview 瓦片与
/// 移动系统概览瓦片共用。
///
/// 不用 ✅/❌ emoji 文本表达状态：Web 端主字体是 NotoSansSC 子集，
/// 不含 emoji 字形且 fallback 需联网，会渲染成空白；
/// [AppStatusChip] 走 MaterialIcons 图标字体，双端可靠。
class ExternalDataSourceStatusChips extends StatelessWidget {
  const ExternalDataSourceStatusChips({
    super.key,
    required this.javdbHealthy,
    required this.dmmHealthy,
    required this.isTesting,
    this.keyPrefix = 'overview',
  });

  final bool? javdbHealthy;
  final bool? dmmHealthy;
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
        AppStatusChip(
          key: Key('$keyPrefix-external-data-source-dmm'),
          label: 'DMM',
          palette: _resolvePalette(context, dmmHealthy),
          isBusy: isTesting,
          dense: true,
        ),
      ],
    );
  }

  AppStatusChipPalette _resolvePalette(BuildContext context, bool? healthy) {
    final colors = context.appColors;
    if (healthy == null) {
      return AppStatusChipPalette(
        background: colors.surfaceMuted,
        borderColor: colors.borderSubtle,
        tone: AppTextTone.secondary,
        foreground: context.appTextPalette.secondary,
        icon: Icons.radio_button_unchecked,
      );
    }
    if (healthy) {
      return AppStatusChipPalette(
        background: colors.successSurface,
        borderColor: null,
        tone: AppTextTone.success,
        foreground: resolveAppTextToneColor(context, AppTextTone.success),
        icon: Icons.check_circle_outline,
      );
    }
    return AppStatusChipPalette(
      background: colors.errorSurface,
      borderColor: null,
      tone: AppTextTone.error,
      foreground: resolveAppTextToneColor(context, AppTextTone.error),
      icon: Icons.error_outline,
    );
  }
}
