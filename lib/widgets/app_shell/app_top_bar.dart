import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_window_drag_area.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, required this.currentPath, required this.config});

  final String currentPath;
  final DesktopTopBarConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
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
