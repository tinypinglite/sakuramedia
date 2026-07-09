import 'package:flutter/material.dart';
import 'package:sakuramedia/core/format/media_timecode.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 圈选切片状态栏：展示起点/终点/时长并提供「清除」「创建」操作。
///
/// 由播放器缩略图面板与影片详情缩略图 tab 共用，[keyPrefix] 用于区分两处的
/// Widget Key 命名空间。
class ClipSelectionStatusBar extends StatelessWidget {
  const ClipSelectionStatusBar({
    super.key,
    required this.keyPrefix,
    required this.startSeconds,
    required this.endSeconds,
    required this.durationSeconds,
    required this.canCreate,
    required this.onCreate,
    required this.onClear,
  });

  final String keyPrefix;
  final int? startSeconds;
  final int? endSeconds;
  final int? durationSeconds;
  final bool canCreate;
  final VoidCallback? onCreate;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final hasSelection = startSeconds != null || endSeconds != null;
    final String hint;
    if (startSeconds == null) {
      hint = '点击缩略图设为起点';
    } else if (endSeconds == null) {
      hint = '起点 ${formatMediaTimecode(startSeconds!)} · 点击设为终点';
    } else {
      final duration = durationSeconds ?? 0;
      hint =
          '起点 ${formatMediaTimecode(startSeconds!)} · '
          '终点 ${formatMediaTimecode(endSeconds!)} · '
          '时长 ${formatMediaTimecode(duration)}';
    }

    return Container(
      key: Key('$keyPrefix-clip-selection-status'),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: context.appRadius.smBorder,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hint,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ),
          if (hasSelection) ...[
            AppTextButton(
              key: Key('$keyPrefix-clip-clear'),
              label: '清除',
              size: AppTextButtonSize.xSmall,
              onPressed: onClear,
            ),
            SizedBox(width: spacing.sm),
          ],
          AppButton(
            key: Key('$keyPrefix-clip-create'),
            label: '创建',
            size: AppButtonSize.small,
            variant: AppButtonVariant.primary,
            onPressed: canCreate ? onCreate : null,
          ),
        ],
      ),
    );
  }
}
