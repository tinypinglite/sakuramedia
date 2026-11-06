import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_provider.dart';
import 'package:sakuramedia/features/configuration/presentation/providers/configuration_tab_request_provider.dart';
import 'package:sakuramedia/features/auth/presentation/actions/auth_actions.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';
import 'package:sakuramedia/widgets/shell/app_sidebar_account_card.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar_item.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar_nav_scroll_area.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_chrome_policy.dart';
import 'package:sakuramedia/widgets/shell/window/app_window_drag_area.dart';

export 'app_sidebar_item.dart';

class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.currentPath,
    required this.navItems,
  });

  final String currentPath;
  final List<AppNavItem> navItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompact = ref.watch(appShellSidebarCollapsedProvider);
    final sidebarTokens = context.appSidebarTokens;
    final appColors = context.appColors;
    final chrome = DesktopChromePolicy.of(context);
    final useDesktopSidebarGlass = chrome.usesGlassSidebar;
    // Windows 的系统模糊比 macOS 更透明，tint 需要更实。
    final glassTint = chrome.usesWindowsCaption
        ? appColors.windowsSidebarGlassTint
        : appColors.desktopSidebarGlassTint;
    if (useDesktopSidebarGlass) {
      return AnimatedContainer(
        key: const Key('desktop-shell-sidebar'),
        duration: const Duration(milliseconds: 180),
        width: isCompact
            ? sidebarTokens.collapsedWidth
            : sidebarTokens.expandedFootprintWidth,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(color: Colors.transparent),
        child: Offstage(
          offstage: isCompact,
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: sidebarTokens.expandedFootprintWidth,
            maxWidth: sidebarTokens.expandedFootprintWidth,
            child: Padding(
              padding: EdgeInsets.all(sidebarTokens.outerInset),
              child: AppGlassSurface(
                key: const Key('desktop-sidebar-glass'),
                tone: AppGlassTone.sidebar,
                width: sidebarTokens.expandedWidth,
                borderRadius: BorderRadius.circular(sidebarTokens.panelRadius),
                padding: EdgeInsets.zero,
                child: _buildSidebarColumn(
                  context,
                  ref,
                  fadeColor: glassTint,
                  isCompact: isCompact,
                  usesGlassSidebar: useDesktopSidebarGlass,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      key: const Key('desktop-shell-sidebar'),
      duration: const Duration(milliseconds: 180),
      width: isCompact
          ? sidebarTokens.collapsedWidth
          : sidebarTokens.expandedWidth,
      clipBehavior: Clip.hardEdge,
      // 收起态宽度为 0：装饰渐隐为透明、内容整体卸载，避免残留边线
      // 和不可见的可点击区域。
      decoration: isCompact
          ? const BoxDecoration(color: Colors.transparent)
          : BoxDecoration(
              color: appColors.sidebarBackground,
              border: Border(right: BorderSide(color: appColors.borderSubtle)),
              boxShadow: context.appShadows.panel,
            ),
      // 展开动画期间容器比侧栏窄，内容按固定展开宽度布局、由容器裁剪
      // 滑入，避免窄约束下溢出；完全收起后内容 offstage（不绘制、不可
      // 点、不参与命中与语义），状态保留以便展开时原位恢复。
      child: Offstage(
        offstage: isCompact,
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: sidebarTokens.expandedWidth,
          maxWidth: sidebarTokens.expandedWidth,
          child: _buildSidebarColumn(
            context,
            ref,
            fadeColor: appColors.sidebarBackground,
            isCompact: isCompact,
            usesGlassSidebar: useDesktopSidebarGlass,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarColumn(
    BuildContext context,
    WidgetRef ref, {
    required Color fadeColor,
    required bool isCompact,
    required bool usesGlassSidebar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: const Key('sidebar-header'),
          height: context.appComponentTokens.desktopTitleBarHeight,
          // macOS / Windows 下这是窗口拖拽区；红绿灯垂直居中于 header，
          // 收起/展开按钮由壳层固定渲染在红绿灯右侧，不在侧栏内部。
          // Linux 保留原生标题栏，不在这里叠加拖拽区。
          child: usesGlassSidebar
              ? const AppWindowDragArea(
                  child: ColoredBox(color: Colors.transparent),
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: SidebarNavScrollArea(
            horizontalPadding: context.appSpacing.sm,
            fadeColor: fadeColor,
            isCompact: isCompact,
            children: _buildNavChildren(context),
          ),
        ),
        // 收起态不构建账户卡：它订阅插件、版本更新等全局 Provider，
        // 隐藏侧栏时没有必要继续监听。导航滚动区仍保留在 Offstage 内，
        // 以便展开时恢复滚动位置。
        if (!isCompact)
          Padding(
            padding: EdgeInsets.all(context.appSpacing.sm),
            child: AppSidebarAccountCard(
              onLogout: () {
                context.logOut();
              },
              onOpenPluginUpdates: () {
                ref
                    .read(configurationTabRequestProvider.notifier)
                    .request('configuration-tab-plugins');
                context.goPrimary(AppRouteId.desktopConfiguration);
              },
            ),
          ),
      ],
    );
  }

  List<Widget> _buildNavChildren(BuildContext context) {
    final children = <Widget>[];
    String? previousSection;
    for (final item in navItems) {
      final section = item.sectionLabel;
      if (section != null && section != previousSection) {
        children.add(_SidebarSectionHeader(label: section));
      }
      previousSection = section;
      children.add(
        Padding(
          padding: EdgeInsets.only(bottom: context.appSpacing.xs),
          child: _AppSidebarDestination(item: item, currentPath: currentPath),
        ),
      );
    }
    return children;
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('sidebar-section-$label'),
      padding: EdgeInsets.only(
        top: context.appSpacing.md,
        bottom: context.appSpacing.xs,
        left: context.appSpacing.md,
        right: context.appSpacing.md,
      ),
      child: Text(
        label,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s10,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ).copyWith(letterSpacing: 1.2),
      ),
    );
  }
}

class _AppSidebarDestination extends ConsumerWidget {
  const _AppSidebarDestination({required this.item, required this.currentPath});

  final AppNavItem item;
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppSidebarItem buildItem(int? badgeCount) {
      return AppSidebarItem(
        key: Key('nav-group-${item.name}'),
        icon: item.icon,
        label: item.label,
        selected: _isPrimaryPathSelected(currentPath, item.path),
        badgeCount: badgeCount,
        onTap: () => context.goPrimary(item.routeId),
      );
    }

    // 仅「通知」目的地订阅全局未读数，其它目的地不监听、避免无谓重建。
    if (item.routeId != AppRouteId.desktopNotifications) {
      return buildItem(null);
    }
    final unreadCount = ref.watch(
      notificationCenterProvider.select((value) => value.unreadCount),
    );
    return buildItem(unreadCount);
  }
}

bool _isPrimaryPathSelected(String currentPath, String primaryPath) {
  return currentPath == primaryPath || currentPath.startsWith('$primaryPath/');
}
