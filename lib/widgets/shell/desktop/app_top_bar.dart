import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/features/search/presentation/widgets/top_bar_search_actions.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_back_guard.dart';
import 'package:sakuramedia/widgets/base/navigation/app_back_button.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_chrome_policy.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar_toggle_button.dart';
import 'package:sakuramedia/widgets/shell/desktop/top_bar_refresh_button.dart';
import 'package:sakuramedia/widgets/shell/window/app_window_drag_area.dart';
import 'package:sakuramedia/widgets/shell/window/app_windows_caption.dart';

/// 桌面壳顶栏。
///
/// 刷新按钮是**受控组件**：[onRefresh] 只是「按下的动作」（fire-and-forget），
/// [isRefreshing] 由外部（[AppDesktopShell]）持有，用来切换按钮 / spinner。
/// 这样点击按钮和 Cmd/Ctrl+R 快捷键可以共用同一份 in-flight 闸门与错误 toast。
///
/// 侧边栏收起/展开按钮由壳层固定在窗口左上角（macOS 红绿灯右侧），
/// 不在这里渲染；收起态顶栏前导留白让出按钮占位，保证标题/返回按钮
/// 排在按钮右侧。
///
/// 搜索框固定显示在刷新按钮左侧，不再提供折叠按钮。只有概览的透明顶栏
/// 使用玻璃搜索框，其它仍为实色背景的页面继续使用标准搜索框。
class AppTopBar extends ConsumerWidget {
  const AppTopBar({
    super.key,
    required this.currentPath,
    required this.config,
    this.shellNavigatorKey,
    this.onRefresh,
    this.isRefreshing = false,
    this.overlay = false,
    this.translucent = false,
    this.contentLeadingInset = AppPageInsets.desktop,
    this.hideActions = false,
  });

  final String currentPath;
  final DesktopTopBarConfig config;
  final GlobalKey<NavigatorState>? shellNavigatorKey;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  /// 悬浮在沉浸内容之上：透明底 + 顶部压暗保证可读，无分隔线。
  final bool overlay;

  /// 桌面玻璃壳层：标准顶栏不再铺实色，直接露出环境背景。
  final bool translucent;

  /// 标准顶栏内容的左侧起始内边距；玻璃壳层下与页面内容共用紧凑 gutter。
  final double contentLeadingInset;

  /// 隐藏搜索/刷新动作（详情页用不到，快捷键刷新不受影响）。
  final bool hideActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSidebarCollapsed = ref.watch(appShellSidebarCollapsedProvider);
    // 收起态前导留白让出壳层固定的收起/展开按钮占位；与侧栏宽度
    // 用同款 180ms 线性动画，标题随之平滑滑动而不是跳变。
    final collapsedLeading =
        sidebarToggleButtonLeft(context) +
        sidebarToggleButtonSize +
        context.appSpacing.sm;

    return Container(
      key: const Key('desktop-shell-topbar'),
      decoration: overlay
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  context.appColors.mediaOverlayStrong.withValues(alpha: 0.55),
                  context.appColors.mediaOverlayStrong.withValues(alpha: 0),
                ],
              ),
            )
          : BoxDecoration(
              color: translucent
                  ? Colors.transparent
                  : context.appColors.surfaceElevated,
            ),
      child: Column(
        children: [
          SizedBox(
            key: const Key('topbar-header'),
            height: context.appComponentTokens.desktopTitleBarHeight,
            child: overlay
                ? _buildOverlayHeader(
                    context,
                    isSidebarCollapsed: isSidebarCollapsed,
                    collapsedLeading: collapsedLeading,
                  )
                : _buildStandardHeader(
                    context,
                    isSidebarCollapsed: isSidebarCollapsed,
                    collapsedLeading: collapsedLeading,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardHeader(
    BuildContext context, {
    required bool isSidebarCollapsed,
    required double collapsedLeading,
  }) {
    final spacing = context.appSpacing;
    final leftInset = contentLeadingInset;
    const rightInset = AppPageInsets.desktop;
    final backButtonSlotWidth = config.isBackEnabled ? 40.0 : 0.0;
    final titleLeadingGap = config.isBackEnabled ? spacing.sm : 0.0;

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: isSidebarCollapsed ? collapsedLeading : leftInset,
        ),
        if (config.isBackEnabled)
          SizedBox(
            width: backButtonSlotWidth,
            child: Center(
              child: AppBackButton(
                key: const Key('topbar-back-button'),
                variant: AppBackButtonVariant.glass,
                onPressed: () => _handleBack(context),
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
        ..._buildActions(context, glass: translucent),
        SizedBox(width: rightInset),
        if (DesktopChromePolicy.of(context).usesWindowsCaption)
          AppWindowsCaption(),
      ],
    );
  }

  /// 沉浸页顶栏：只留一颗返回键，页面标题由内容区自己承载。
  /// 搜索/刷新在沉浸页通常隐藏；若调用方仍开启，则按普通图标放在右侧。
  Widget _buildOverlayHeader(
    BuildContext context, {
    required bool isSidebarCollapsed,
    required double collapsedLeading,
  }) {
    const leftInset = AppPageInsets.desktop;
    const rightInset = AppPageInsets.desktop;

    return Row(
      children: [
        SizedBox(width: isSidebarCollapsed ? collapsedLeading : leftInset),
        if (config.isBackEnabled)
          SizedBox(
            width: 40.0,
            child: Center(
              child: AppBackButton(
                key: const Key('topbar-back-button'),
                variant: AppBackButtonVariant.glass,
                onPressed: () => _handleBack(context),
              ),
            ),
          ),
        Expanded(child: AppWindowDragArea(child: const SizedBox.expand())),
        ..._buildActions(context, glass: false, overlay: true),
        SizedBox(width: rightInset),
        if (DesktopChromePolicy.of(context).usesWindowsCaption)
          AppWindowsCaption(overlay: true),
      ],
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    final guard = AppBackGuardScope.maybeOf(context);
    if (guard != null && !await guard.canLeave()) {
      return;
    }
    if (!context.mounted) {
      return;
    }
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

  List<Widget> _buildActions(
    BuildContext context, {
    required bool glass,
    bool overlay = false,
  }) {
    if (hideActions) {
      return const <Widget>[];
    }
    return <Widget>[
      TopBarSearchActions(currentPath: currentPath, glass: glass),
      if (onRefresh case final refresh?) ...[
        SizedBox(width: context.appSpacing.xs),
        TopBarRefreshButton(
          onPressed: refresh,
          isRefreshing: isRefreshing,
          glass: glass,
          overlay: overlay,
        ),
      ],
    ];
  }
}
