import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/shell/window/app_window_drag_area.dart';

/// 桌面壳顶栏。
///
/// 刷新按钮是**受控组件**：[onRefresh] 只是「按下的动作」（fire-and-forget），
/// [isRefreshing] 由外部（[AppDesktopShell]）持有，用来切换按钮 / spinner。
/// 这样点击按钮和 Cmd/Ctrl+R 快捷键可以共用同一份 in-flight 闸门与错误 toast。
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.currentPath,
    required this.config,
    this.shellNavigatorKey,
    this.onRefresh,
    this.isRefreshing = false,
  });

  final String currentPath;
  final DesktopTopBarConfig config;
  final GlobalKey<NavigatorState>? shellNavigatorKey;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    const leftInset = AppPageInsets.desktop;
    const rightInset = AppPageInsets.desktop;
    final backButtonSlotWidth = config.isBackEnabled ? 40.0 : 0.0;
    final titleLeadingGap = config.isBackEnabled ? spacing.sm : 0.0;

    return Container(
      key: const Key('desktop-shell-topbar'),
      decoration: BoxDecoration(color: context.appColors.surfaceElevated),
      child: Column(
        children: [
          SizedBox(
            key: const Key('topbar-header'),
            height: context.appComponentTokens.desktopTitleBarHeight,
            child: Row(
              children: [
                SizedBox(width: leftInset),
                if (config.isBackEnabled)
                  SizedBox(
                    width: backButtonSlotWidth,
                    child: AppIconButton(
                      key: const Key('topbar-back-button'),
                      tooltip: '返回',
                      onPressed: () => _handleBack(context),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: context.appComponentTokens.iconSizeXs,
                      ),
                    ),
                  ),
                if (titleLeadingGap > 0) SizedBox(width: titleLeadingGap),
                Expanded(
                  child: AppWindowDragArea(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        config.title,
                        key: const Key('app-topbar-title'),
                        style: resolveAppTextStyle(
                          context,
                          size: AppTextSize.s14,
                          weight: AppTextWeight.semibold,
                          tone: AppTextTone.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                if (onRefresh != null)
                  _TopBarRefreshButton(
                    onPressed: onRefresh!,
                    isRefreshing: isRefreshing,
                  ),
                SizedBox(width: rightInset),
              ],
            ),
          ),
          Divider(
            key: const Key('topbar-header-divider'),
            height: 1,
            color: context.appColors.borderSubtle,
          ),
        ],
      ),
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    final shellNavigator = shellNavigatorKey?.currentState;
    if (shellNavigator != null && shellNavigator.canPop()) {
      shellNavigator.pop();
      return;
    }

    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
    }

    final fallbackPath = config.fallbackPath;
    if (fallbackPath != null && fallbackPath != currentPath) {
      router.go(fallbackPath);
    }
  }
}

class _TopBarRefreshButton extends StatelessWidget {
  const _TopBarRefreshButton({
    required this.onPressed,
    required this.isRefreshing,
  });

  final VoidCallback onPressed;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appComponentTokens;
    final iconSize = tokens.iconSizeXs;

    if (isRefreshing) {
      return SizedBox(
        key: const Key('topbar-refresh-button-loading'),
        width: 40,
        child: Center(
          child: SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.appTextPalette.muted,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 40,
      child: AppIconButton(
        key: const Key('topbar-refresh-button'),
        tooltip: '刷新',
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(Icons.refresh_rounded, size: iconSize),
      ),
    );
  }
}
