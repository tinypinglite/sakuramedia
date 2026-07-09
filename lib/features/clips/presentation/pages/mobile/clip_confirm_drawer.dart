import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_mobile_confirm_actions.dart';

/// 移动端切片/合集场景的通用确认底部抽屉：确认返回 `true`，取消返回 `null`。
///
/// 供删除切片、删除合集、移除切片等不可逆操作复用，对齐影片/播放列表的删除确认范式。
Future<bool?> showMobileClipConfirmDrawer(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = '删除',
  Key? drawerKey,
  Key? confirmButtonKey,
}) {
  return showAppBottomDrawer<bool>(
    context: context,
    drawerKey: drawerKey ?? const Key('mobile-clip-confirm-drawer'),
    maxHeightFactor: 0.42,
    builder:
        (sheetContext) => _MobileClipConfirmDrawer(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          confirmButtonKey: confirmButtonKey,
        ),
  );
}

class _MobileClipConfirmDrawer extends StatelessWidget {
  const _MobileClipConfirmDrawer({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.confirmButtonKey,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Key? confirmButtonKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s16,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: spacing.sm),
        Text(
          message,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.xl),
        AppMobileConfirmActions(
          confirmKey: confirmButtonKey,
          confirmLabel: confirmLabel,
          isDangerous: true,
          onCancel: () => Navigator.of(context).pop(),
          onConfirm: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
