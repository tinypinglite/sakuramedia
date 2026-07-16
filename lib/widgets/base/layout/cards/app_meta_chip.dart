import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

/// 元数据 chip：小图标 + 短文本，无包装（不像 [AppBadge] 有 pill 背景）。
///
/// 用于卡片头下的属性 / 计数流：多颗横排 `Wrap` 展示形如「导入 12 · 失败 3 · 115 网盘」的行内元数据。
/// [tone] 同时驱动图标与文字色，默认 `secondary`；需要突出状态计数时可传 `success` / `error` / `info`。
class AppMetaChip extends StatelessWidget {
  const AppMetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.tone = AppTextTone.secondary,
  });

  final IconData icon;
  final String label;
  final AppTextTone tone;

  @override
  Widget build(BuildContext context) {
    final color = resolveAppTextToneColor(context, tone);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: context.appComponentTokens.iconSizeXs,
          color: color,
        ),
        SizedBox(width: context.appSpacing.xs),
        Text(
          label,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: tone,
          ),
        ),
      ],
    );
  }
}
