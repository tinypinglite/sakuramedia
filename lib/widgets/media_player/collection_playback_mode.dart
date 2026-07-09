import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 合集连播的两种播放形态：
/// - [playlist] 原生 media_kit `Playlist`：一集接一集，UI 显示当前集进度条。
/// - [merged] 把整张合集当一部影片：累加每集时长合成虚拟总时长，进度条 / 总位置统一。
///   集间切换仍由 mpv 走原生切换（短暂解码器重启），不是真正无缝；UI 上隐藏分集感。
enum CollectionPlaybackMode { playlist, merged }

/// 详情页 → 连播页 之间询问用户选哪种形态。
///
/// 桌面端默认走 [AppDesktopDialog]；移动 / 触摸端传 `useBottomDrawer: true` 走底部抽屉
/// （沿用其它图片菜单的两端范式）。点选项即返回并关闭；外部点击 / 关闭按钮返回 `null`，
/// 调用方据此放弃跳转。
Future<CollectionPlaybackMode?> showCollectionPlaybackModePicker({
  required BuildContext context,
  bool useBottomDrawer = false,
}) {
  if (useBottomDrawer) {
    return showAppBottomDrawer<CollectionPlaybackMode>(
      context: context,
      heightFactor: 0.45,
      builder: (drawerContext) {
        return _PlaybackModePickerBody(
          onSelect: (mode) => Navigator.of(drawerContext).pop(mode),
        );
      },
    );
  }
  return showDialog<CollectionPlaybackMode>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AppDesktopDialog(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _PlaybackModePickerBody(
          onSelect: (mode) => Navigator.of(dialogContext).pop(mode),
        ),
      );
    },
  );
}

class _PlaybackModePickerBody extends StatelessWidget {
  const _PlaybackModePickerBody({required this.onSelect});

  final ValueChanged<CollectionPlaybackMode> onSelect;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '选择播放方式',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.xs),
        Text(
          '此合集包含多个视频，请选择如何呈现。',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        _ModeOption(
          modeKey: const Key('collection-playback-mode-playlist'),
          icon: Icons.playlist_play_rounded,
          title: '列表连播',
          subtitle: '逐集播放，集间自动切换；分集进度条。',
          onTap: () => onSelect(CollectionPlaybackMode.playlist),
        ),
        SizedBox(height: spacing.sm),
        _ModeOption(
          modeKey: const Key('collection-playback-mode-merged'),
          icon: Icons.merge_type_rounded,
          title: '合并播放',
          subtitle: '把整张合集当作一部影片，进度条合并显示（Beta）。',
          onTap: () => onSelect(CollectionPlaybackMode.merged),
        ),
      ],
    );
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.modeKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key modeKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    return Material(
      color: colors.surfaceMuted,
      borderRadius: context.appRadius.mdBorder,
      child: InkWell(
        key: modeKey,
        borderRadius: context.appRadius.mdBorder,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.md,
            vertical: spacing.md,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: context.appComponentTokens.iconSizeMd,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s14,
                        weight: AppTextWeight.semibold,
                        tone: AppTextTone.primary,
                      ),
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      subtitle,
                      style: resolveAppTextStyle(
                        context,
                        size: AppTextSize.s12,
                        weight: AppTextWeight.regular,
                        tone: AppTextTone.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: context.appComponentTokens.iconSizeSm,
                color: colors.borderStrong,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
