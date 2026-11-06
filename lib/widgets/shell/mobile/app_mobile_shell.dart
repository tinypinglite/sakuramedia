import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/core/platform/haptic_feedback.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/shell/mobile/mobile_system_overlay.dart';

class AppMobileShell extends StatefulWidget {
  const AppMobileShell({
    super.key,
    required this.currentPath,
    required this.navGroups,
    this.currentIndex,
    this.onDestinationSelected = _noopDestinationSelected,
    this.drawer,
    this.drawerEnableOpenDragGesture = false,
    this.background,
    required this.child,
  });

  final String currentPath;
  final List<AppNavGroup> navGroups;
  final int? currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? drawer;
  final bool drawerEnableOpenDragGesture;

  /// 页面内容安全区之外的整屏底色/环境光；为空时使用卡片底色。
  ///
  /// 该层铺到状态栏下方，让透明顶栏与页面背景连成一片；仍不覆盖底部导航。
  final Widget? background;
  final Widget child;

  static void _noopDestinationSelected(int _) {}

  @override
  State<AppMobileShell> createState() => _AppMobileShellState();
}

class _AppMobileShellState extends State<AppMobileShell> {
  @override
  Widget build(BuildContext context) {
    final navItems = widget.navGroups
        .expand((group) => group.items)
        .toList(growable: false);
    final resolvedCurrentIndex =
        widget.currentIndex ??
        _resolveCurrentIndex(widget.currentPath, navItems);
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final useGlassNavigation = !highContrast;

    final shell = AnnotatedRegion<SystemUiOverlayStyle>(
      value: widget.background == null
          ? resolveMobileSystemOverlayStyle(context)
          : resolveMobileSystemOverlayStyle(
              context,
            ).copyWith(statusBarColor: Colors.transparent),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.background != null)
            widget.background!
          else
            ColoredBox(color: context.appColors.surfaceCard),
          Scaffold(
            backgroundColor: Colors.transparent,
            // 玻璃底栏需要真实的内容层作为折射/模糊来源。让 body 铺到屏幕底边，
            // Scaffold 会把底栏高度写进 body 的 MediaQuery.padding.bottom，滚动页
            // 通过现有 bottomSafeAreaSliver 留出末尾空间；实色兜底栏不穿底。
            extendBody: useGlassNavigation,
            drawer: widget.drawer,
            drawerEnableOpenDragGesture:
                widget.drawer != null && widget.drawerEnableOpenDragGesture,
            drawerEdgeDragWidth: _resolveDrawerEdgeDragWidth(context),
            body: SafeArea(
              key: const Key('mobile-shell-body-safe-area'),
              bottom: false,
              child: Padding(
                key: const Key('mobile-shell-body-padding'),
                padding: AppPageInsets.compactStandard,
                child: widget.child,
              ),
            ),
            bottomNavigationBar: useGlassNavigation
                ? _buildGlassNavigation(context, navItems, resolvedCurrentIndex)
                : _buildSolidNavigation(
                    context,
                    navItems,
                    resolvedCurrentIndex,
                  ),
          ),
        ],
      ),
    );

    return shell;
  }

  Widget _buildGlassNavigation(
    BuildContext context,
    List<AppNavItem> navItems,
    int currentIndex,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final labelStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s10,
      weight: AppTextWeight.medium,
      tone: AppTextTone.secondary,
    ).copyWith(fontFamily: resolveAppFontFamily(context));
    return SafeArea(
      key: const Key('mobile-shell-bottom-safe-area'),
      top: false,
      minimum: EdgeInsets.only(
        left: context.appSpacing.md,
        right: context.appSpacing.md,
        bottom: context.appSpacing.xs,
      ),
      child: GlassTabBar.bottom(
        key: const Key('mobile-bottom-navigation'),
        tabs: navItems
            .map(
              (item) => GlassTab(
                icon: Icon(item.icon),
                activeIcon: Icon(item.activeIcon ?? item.icon),
                label: item.label,
                semanticLabel: item.label,
              ),
            )
            .toList(growable: false),
        selectedIndex: currentIndex,
        onTabSelected: (index) =>
            _handleDestinationTap(context, navItems, currentIndex, index),
        barHeight: context.appComponentTokens.mobileBottomNavHeight,
        verticalPadding: 4,
        horizontalPadding: 4,
        barBorderRadius: 28,
        iconSize: context.appComponentTokens.iconSizeXl,
        labelFontSize: 10,
        selectedIconColor: primary,
        unselectedIconColor: context.appTextPalette.secondary,
        selectedLabelColor: primary,
        unselectedLabelColor: context.appTextPalette.secondary,
        selectedLabelStyle: labelStyle.copyWith(
          color: primary,
          fontWeight: context.appTextWeights.semibold,
        ),
        unselectedLabelStyle: labelStyle,
        // 使用库的底栏专用材质；顶栏的 ios27 磨砂在大块选中态下会发白发糊。
        // 选中胶囊按压时会切到玻璃透镜态；压低 Fresnel / 环境边缘光，
        // 避免切换时出现明显的白色边光，同时保留玻璃块的折射厚度。
        indicatorSettings: const LiquidGlassSettings(
          lightIntensity: 0,
          ambientRim: 0.02,
          fresnelStrength: 0,
          glowIntensity: 0,
        ),
        quality: GlassQuality.premium,
      ),
    );
  }

  Widget _buildSolidNavigation(
    BuildContext context,
    List<AppNavItem> navItems,
    int currentIndex,
  ) {
    return SafeArea(
      key: const Key('mobile-shell-bottom-safe-area'),
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.appColors.divider)),
        ),
        child: CupertinoTabBar(
          key: const Key('mobile-bottom-navigation'),
          height: context.appComponentTokens.mobileBottomNavHeight,
          iconSize: context.appComponentTokens.iconSizeXl,
          backgroundColor: context.appColors.surfaceCard,
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: context.appTextPalette.secondary,
          currentIndex: currentIndex,
          items: navItems
              .map(
                (item) => BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  activeIcon: Icon(item.activeIcon ?? item.icon),
                  label: item.label,
                ),
              )
              .toList(growable: false),
          onTap: (index) =>
              _handleDestinationTap(context, navItems, currentIndex, index),
        ),
      ),
    );
  }

  /// 左边缘拖拽区宽度。
  ///
  /// Flutter 默认是 `20 + padding.left`,而 Android 手势导航的返回手势区就压在
  /// 最外侧同一条带子上、且系统优先消费,默认值等于整条被吃掉。系统手势区宽度
  /// 因设备/ROM 而异(只在 Android Q+ 非零),运行时从 MediaQuery 读,再往内侧
  /// 补一段 app 独占的可用带——外侧归系统返回,内侧归抽屉。
  double? _resolveDrawerEdgeDragWidth(BuildContext context) {
    if (widget.drawer == null || !widget.drawerEnableOpenDragGesture) {
      return null;
    }
    return MediaQuery.systemGestureInsetsOf(context).left +
        context.appSpacing.xl;
  }

  void _handleDestinationTap(
    BuildContext context,
    List<AppNavItem> navItems,
    int currentIndex,
    int index,
  ) {
    // 只在真正切换 tab 时给触感，重复点当前 tab 不震。
    if (index != currentIndex) {
      triggerSelectionHaptic();
    }
    if (widget.onDestinationSelected !=
        AppMobileShell._noopDestinationSelected) {
      widget.onDestinationSelected(index);
      return;
    }
    // 在未接入 StatefulShellRoute 的场景下，回退到传统的 go 导航。
    final router = GoRouter.maybeOf(context);
    if (router == null || index < 0 || index >= navItems.length) {
      return;
    }
    router.go(navItems[index].path);
  }

  int _resolveCurrentIndex(String path, List<AppNavItem> navItems) {
    for (var index = 0; index < navItems.length; index += 1) {
      final item = navItems[index];
      if (path == item.path || path.startsWith('${item.path}/')) {
        return index;
      }
    }
    return 0;
  }
}
