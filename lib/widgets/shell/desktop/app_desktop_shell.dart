import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_controller.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/navigation/app_back_guard.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_top_bar.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_chrome_policy.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_ambient_backdrop.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_window_controls.dart';
import 'package:sakuramedia/widgets/shell/window/app_window_drag_area.dart';
import 'package:sakuramedia/widgets/shell/window/app_windows_caption.dart';

class AppDesktopShell extends ConsumerStatefulWidget {
  const AppDesktopShell({
    super.key,
    required this.currentPath,
    required this.layout,
    required this.topBarConfig,
    required this.shellNavigatorKey,
    required this.navItems,
    required this.child,
    this.showTopBar = true,
  });

  final String currentPath;
  final AppShellLayout layout;
  final DesktopTopBarConfig topBarConfig;
  final GlobalKey<NavigatorState> shellNavigatorKey;
  final List<AppNavItem> navItems;
  final Widget child;

  /// 是否渲染内容区顶栏。标签页传 false，只隐藏顶栏内容；
  /// 顶部仍保留标题栏高度的留白，并保留侧栏、macOS 红绿灯和
  /// Windows 窗口按钮。
  final bool showTopBar;

  @override
  ConsumerState<AppDesktopShell> createState() => _AppDesktopShellState();
}

class _AppDesktopShellState extends ConsumerState<AppDesktopShell> {
  late final AppPageRefreshController _refreshController =
      AppPageRefreshController();
  final AppBackGuardController _backGuard = AppBackGuardController();

  /// 单例 in-flight 闸门：按钮点击和 Cmd/Ctrl+R 快捷键共用同一份状态，
  /// 避免其中一条路径绕过对方的 debounce。
  bool _isRefreshing = false;

  /// 路由切换 [AppShellLayout] 时，内容边距必须和页面一起瞬时切换；
  /// 只有侧栏折叠造成的边距变化才需要过渡。
  bool _isLayoutTransitioning = false;

  @override
  void didUpdateWidget(covariant AppDesktopShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout == widget.layout) {
      return;
    }
    _isLayoutTransitioning = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _isLayoutTransitioning = false;
      }
    });
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  /// 顶栏刷新按钮与 Cmd/Ctrl+R 共用的入口：
  /// - 已有刷新在跑 → 直接吞掉，避免并发 refresh。
  /// - 回调抛异常 → toast 兜底，不让顶层未捕获。控制器约定不同（有的自己 toast、
  ///   有的静默保留旧数据），这里只保底最坏情况「异常冒到 shell」，避免用户在
  ///   顶栏按下按钮什么反应都没有。
  Future<void> _runRefresh(AppPageRefreshCallback callback) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    final l10n = appL10n(context);
    try {
      await callback();
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(error, fallback: l10n.shellRefreshFailed, l10n: l10n),
        tone: AppToastTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _triggerCurrentRefresh() {
    final callback = _refreshController.current;
    if (callback == null) return;
    // 快捷键路径也走 _runRefresh，与按钮共享 in-flight 闸门与 toast 兜底。
    _runRefresh(callback);
  }

  Widget _buildTopBar(
    BuildContext context, {
    required AppPageRefreshCallback? current,
    required bool immersive,
    required bool ambientSurface,
    required bool sidebarCollapsed,
  }) {
    return AppTopBar(
      currentPath: widget.currentPath,
      config: widget.topBarConfig,
      shellNavigatorKey: widget.shellNavigatorKey,
      onRefresh: current == null ? null : () => _runRefresh(current),
      isRefreshing: current != null && _isRefreshing,
      overlay: immersive,
      translucent: ambientSurface,
      contentLeadingInset: ambientSurface && !sidebarCollapsed
          ? context.appSpacing.lg
          : AppPageInsets.desktop,
      hideActions: immersive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chrome = DesktopChromePolicy.of(context);

    final immersive = widget.layout == AppShellLayout.immersive;
    final ambientSurface = chrome.usesGlassSidebar && !immersive;
    final titleBarHeight = context.appComponentTokens.desktopTitleBarHeight;
    final showTopBar = widget.showTopBar;
    // 内容区在 standard / fullscreen / immersive 三态共用**同一棵树**：只改内边距
    // 数值与顶栏的悬浮开关。navigator 因此不换父级——换父级会让整条路由栈
    // （含背后已缓存的列表页）在切布局那一帧被重新激活并重排，进详情页会明显变慢。
    final sidebarCollapsed = ref.watch(appShellSidebarCollapsedProvider);
    final glassSidebarExpanded = chrome.usesGlassSidebar && !sidebarCollapsed;
    final EdgeInsets contentPadding;
    if (immersive) {
      // 顶栏透明悬浮在内容之上，内容全幅铺底。
      contentPadding = EdgeInsets.zero;
    } else if (widget.layout == AppShellLayout.standard) {
      // 顶栏在流内占位：内容整体下移一个顶栏高度，四周保留桌面标准内边距。
      // 隐藏顶栏时同样保留这段高度，避免内容贴住窗口顶部和窗口按钮。
      final horizontalInset = glassSidebarExpanded
          ? context.appSpacing.lg
          : AppPageInsets.desktop;
      contentPadding = EdgeInsets.only(
        top: titleBarHeight,
        left: horizontalInset,
        right: AppPageInsets.desktop,
        bottom: AppPageInsets.desktop,
      );
    } else {
      // fullscreen：顶栏在流内占位，内容不再额外留白。
      contentPadding = EdgeInsets.only(top: titleBarHeight);
    }
    return AppBackGuardScope(
      controller: _backGuard,
      child: AppPageRefreshRegistrarScope(
        registrar: _refreshController.registrar,
        child: CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
                _triggerCurrentRefresh,
            const SingleActivator(LogicalKeyboardKey.keyR, control: true):
                _triggerCurrentRefresh,
          },
          child: Scaffold(
            backgroundColor: chrome.usesGlassSidebar
                ? Colors.transparent
                : context.appColors.surfacePage,
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DesktopAmbientBackdrop(
                        enabled: chrome.usesGlassSidebar,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      AppSidebar(
                        currentPath: widget.currentPath,
                        navItems: widget.navItems,
                      ),
                      Expanded(
                        child: Container(
                          key: const Key('desktop-shell-content-surface'),
                          color: ambientSurface
                              ? Colors.transparent
                              : context.appColors.surfaceElevated,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: AnimatedPadding(
                                  duration: immersive || _isLayoutTransitioning
                                      ? Duration.zero
                                      : const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  padding: contentPadding,
                                  child: widget.child,
                                ),
                              ),
                              if (showTopBar)
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: 0,
                                  child:
                                      ValueListenableBuilder<
                                        AppPageRefreshCallback?
                                      >(
                                        valueListenable:
                                            _refreshController.listenable,
                                        builder: (context, current, _) =>
                                            _buildTopBar(
                                              context,
                                              current: current,
                                              immersive: immersive,
                                              ambientSurface: ambientSurface,
                                              sidebarCollapsed:
                                                  sidebarCollapsed,
                                            ),
                                      ),
                                )
                              else if (chrome.usesWindowsCaption) ...[
                                // Windows 的窗口按钮由顶栏承载；隐藏顶栏时
                                // 只保留按钮和拖拽区，避免丢失窗口操作。
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: AppWindowsCaption(),
                                ),
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  right: titleBarHeight * 3,
                                  height: titleBarHeight,
                                  child: AppWindowDragArea(
                                    child: SizedBox.expand(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 红绿灯和收起/展开按钮固定在窗口坐标系，
                  // 不随侧栏宽度动画和顶栏布局切换移动。
                  Positioned.fill(child: DesktopWindowControls(policy: chrome)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
