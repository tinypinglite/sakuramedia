import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

/// 在 Web 应用本次启动后提示一次当前平台仍处于测试阶段。
class WebPlatformNoticeHost extends StatefulWidget {
  const WebPlatformNoticeHost({
    super.key,
    required this.enabled,
    required this.navigatorKey,
    required this.child,
  });

  final bool enabled;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<WebPlatformNoticeHost> createState() => _WebPlatformNoticeHostState();
}

class _WebPlatformNoticeHostState extends State<WebPlatformNoticeHost> {
  bool _hasScheduledNotice = false;

  @override
  void initState() {
    super.initState();
    _scheduleNoticeIfNeeded();
  }

  @override
  void didUpdateWidget(covariant WebPlatformNoticeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleNoticeIfNeeded();
  }

  void _scheduleNoticeIfNeeded() {
    if (!widget.enabled || _hasScheduledNotice) {
      return;
    }
    _hasScheduledNotice = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final navigatorContext =
          widget.navigatorKey.currentState?.overlay?.context;
      if (navigatorContext == null) {
        return;
      }
      showDialog<void>(
        context: navigatorContext,
        builder: (dialogContext) => const _WebPlatformNoticeDialog(),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _WebPlatformNoticeDialog extends StatelessWidget {
  const _WebPlatformNoticeDialog();

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final iconContainerSize = context.appLayoutTokens.panelIconContainerSize;

    return AppDesktopDialog(
      dialogKey: const Key('web-platform-notice-dialog'),
      width: context.appLayoutTokens.dialogWidthSm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: iconContainerSize,
            height: iconContainerSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.appColors.warningSurface,
              borderRadius: context.appRadius.mdBorder,
            ),
            child: Icon(
              Icons.devices_rounded,
              color: context.appTextPalette.warning,
              size: context.appComponentTokens.iconSizeLg,
            ),
          ),
          SizedBox(height: spacing.lg),
          Text(
            '建议使用 SakuraMedia 客户端',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s18,
              weight: AppTextWeight.semibold,
            ),
          ),
          SizedBox(height: spacing.sm),
          Text(
            '当前 Web 端尚未经过充分测试，部分功能可能不稳定。为了获得更完整、可靠的使用体验，建议尽快下载并使用 SakuraMedia 客户端进行操作。',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: spacing.xl),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: '我知道了',
              variant: AppButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
