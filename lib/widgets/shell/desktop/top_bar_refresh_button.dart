import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 桌面顶栏刷新按钮。
///
/// 刷新是受控动作：[onPressed] 只负责触发刷新，[isRefreshing] 由壳层持有。
/// 玻璃壳层使用 32 的玻璃圆钮；非玻璃壳层和玻璃高对比度回退使用紧凑普通
/// 图标按钮。刷新中按钮禁用并切换为加载态。
class TopBarRefreshButton extends StatelessWidget {
  const TopBarRefreshButton({
    super.key,
    required this.onPressed,
    required this.isRefreshing,
    this.glass = false,
    this.overlay = false,
  });

  final VoidCallback onPressed;
  final bool isRefreshing;
  final bool glass;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    if (glass && !highContrast) {
      final l10n = appL10n(context);
      return AppGlassIconButton(
        key: Key(
          isRefreshing
              ? 'topbar-refresh-button-loading'
              : 'topbar-refresh-button',
        ),
        tooltip: l10n.commonRefresh,
        semanticLabel: l10n.commonRefresh,
        icon: Icons.refresh_rounded,
        iconWidget: isRefreshing
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color?>(
                    context.appTextPalette.primary,
                  ),
                ),
              )
            : null,
        iconSize: 18,
        size: 32,
        onPressed: isRefreshing ? null : onPressed,
      );
    }
    return _TopBarSolidRefreshButton(
      onPressed: onPressed,
      isRefreshing: isRefreshing,
      overlay: overlay,
    );
  }
}

/// 非玻璃顶栏刷新按钮的占位宽度，与 AppIconButton(compact) 同宽。
const double _topBarActionSlotWidth = appCompactIconButtonSize;

class _TopBarSolidRefreshButton extends StatelessWidget {
  const _TopBarSolidRefreshButton({
    required this.onPressed,
    required this.isRefreshing,
    this.overlay = false,
  });

  final VoidCallback onPressed;
  final bool isRefreshing;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final tokens = context.appComponentTokens;
    final iconSize = tokens.iconSizeSm;

    if (isRefreshing) {
      return SizedBox(
        key: const Key('topbar-refresh-button-loading'),
        width: _topBarActionSlotWidth,
        child: Center(
          child: SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator.adaptive(
              backgroundColor: switch (Theme.of(context).platform) {
                TargetPlatform.iOS || TargetPlatform.macOS =>
                  overlay
                      ? context.appTextPalette.onMedia
                      : context.appTextPalette.muted,
                _ => null,
              },
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color?>(
                overlay
                    ? context.appTextPalette.onMedia
                    : context.appTextPalette.muted,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: _topBarActionSlotWidth,
      child: AppIconButton(
        key: const Key('topbar-refresh-button'),
        tooltip: l10n.commonRefresh,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(
          Icons.refresh_rounded,
          size: iconSize,
          color: overlay ? context.appTextPalette.onMedia : null,
        ),
      ),
    );
  }
}
