import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/routes/app_route_paths.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar_toggle_button.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_top_bar.dart';
import 'package:sakuramedia/widgets/shell/desktop/desktop_ambient_backdrop.dart';
import 'package:sakuramedia/widgets/shell/window/app_mac_traffic_lights.dart';
import 'package:sakuramedia/widgets/shell/window/app_window_drag_area.dart';
import 'package:sakuramedia/widgets/shell/window/app_windows_caption.dart';

class AppDesktopShell extends ConsumerStatefulWidget {
  const AppDesktopShell({
    super.key,
    required this.currentPath,
    required this.layout,
    required this.topBarConfig,
    required this.shellNavigatorKey,
    required this.navGroups,
    required this.child,
    this.showTopBar = true,
  });

  final String currentPath;
  final AppShellLayout layout;
  final DesktopTopBarConfig topBarConfig;
  final GlobalKey<NavigatorState> shellNavigatorKey;
  final List<AppNavGroup> navGroups;
  final Widget child;

  /// 是否渲染内容区顶栏。标签页传 false，只隐藏顶栏内容；
  /// 顶部仍保留标题栏高度的留白，并保留侧栏、macOS 红绿灯和
  /// Windows 窗口按钮。
  final bool showTopBar;

  @override
  ConsumerState<AppDesktopShell> createState() => _AppDesktopShellState();
}

class _AppDesktopShellState extends ConsumerState<AppDesktopShell> {
  final List<AppPageRefreshCallback> _stack = <AppPageRefreshCallback>[];
  late final AppPageRefreshRegistrar _registrar = AppPageRefreshRegistrar(
    register: _register,
    unregister: _unregister,
  );

  /// 单例 in-flight 闸门：按钮点击和 Cmd/Ctrl+R 快捷键共用同一份状态，
  /// 避免其中一条路径绕过对方的 debounce。
  bool _isRefreshing = false;

  AppPageRefreshCallback? get _current => _stack.isEmpty ? null : _stack.last;

  void _register(AppPageRefreshCallback callback) {
    _stack.add(callback);
    _scheduleRebuild();
  }

  void _unregister(AppPageRefreshCallback callback) {
    if (!_stack.remove(callback)) return;
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    // 页面在 build 阶段通过 didChangeDependencies 注册回调时，
    // 不能立即 setState（会触发 build-during-build）。延迟到下一帧。
    // 注意：runApp 首次 attach 是在 microtask 里跑 buildScope，
    // 此时 schedulerPhase 仍是 idle，光看 phase 会漏掉这种情况——
    // 所以再叠一层 buildOwner.debugBuilding 判定。
    final building = WidgetsBinding.instance.buildOwner?.debugBuilding ?? false;
    if (!building &&
        (phase == SchedulerPhase.idle ||
            phase == SchedulerPhase.postFrameCallbacks)) {
      setState(() {});
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
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
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _triggerCurrentRefresh() {
    final callback = _current;
    if (callback == null) return;
    // 快捷键路径也走 _runRefresh，与按钮共享 in-flight 闸门与 toast 兜底。
    _runRefresh(callback);
  }

  @override
  Widget build(BuildContext context) {
    final useDesktopSidebarGlass =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows);

    final current = _current;
    final immersive = widget.layout == AppShellLayout.immersive;
    // 内容区在 standard / fullscreen / immersive 三态共用**同一棵树**：只改内边距
    // 数值与顶栏的悬浮开关。navigator 因此不换父级——换父级会让整条路由栈
    // （含背后已缓存的列表页）在切布局那一帧被重新激活并重排，进详情页会明显变慢。
    final titleBarHeight = context.appComponentTokens.desktopTitleBarHeight;
    final showTopBar = widget.showTopBar;
    final sidebarCollapsed = ref.watch(appShellSidebarCollapsedProvider);
    final glassSidebarExpanded = useDesktopSidebarGlass && !sidebarCollapsed;
    final EdgeInsets contentPadding;
    if (immersive) {
      // 顶栏透明悬浮在内容之上，内容全幅铺底。
      contentPadding = EdgeInsets.zero;
    } else if (widget.layout == AppShellLayout.standard) {
      // 顶栏在流内占位：内容整体下移一个顶栏高度，四周保留桌面标准内边距。
      // 隐藏顶栏时同样保留这段高度，避免内容贴住窗口顶部和窗口按钮。
      contentPadding = EdgeInsets.only(
        top: titleBarHeight,
        left: glassSidebarExpanded
            ? context.appSpacing.lg
            : AppPageInsets.desktop,
        right: AppPageInsets.desktop,
        bottom: AppPageInsets.desktop,
      );
    } else {
      // fullscreen：顶栏在流内占位，内容不再额外留白。
      contentPadding = EdgeInsets.only(top: titleBarHeight);
    }
    return AppPageRefreshRegistrarScope(
      registrar: _registrar,
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
              _triggerCurrentRefresh,
          const SingleActivator(LogicalKeyboardKey.keyR, control: true):
              _triggerCurrentRefresh,
        },
        child: Scaffold(
          backgroundColor: useDesktopSidebarGlass
              ? Colors.transparent
              : context.appColors.surfacePage,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: DesktopAmbientBackdrop(
                      enabled: useDesktopSidebarGlass,
                    ),
                  ),
                ),
                Row(
                  children: [
                    AppSidebar(
                      currentPath: widget.currentPath,
                      navGroups: widget.navGroups,
                    ),
                    Expanded(
                      child: Container(
                        key: const Key('desktop-shell-content-surface'),
                        color:
                            useDesktopSidebarGlass &&
                                widget.currentPath == desktopOverviewPath
                            ? Colors.transparent
                            : context.appColors.surfaceElevated,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: AnimatedPadding(
                                duration: immersive
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
                                child: AppTopBar(
                                  currentPath: widget.currentPath,
                                  config: widget.topBarConfig,
                                  shellNavigatorKey: widget.shellNavigatorKey,
                                  onRefresh: current == null
                                      ? null
                                      : () => _runRefresh(current),
                                  isRefreshing:
                                      current != null && _isRefreshing,
                                  overlay: immersive,
                                  translucent:
                                      useDesktopSidebarGlass &&
                                      widget.currentPath == desktopOverviewPath,
                                  contentLeadingInset: useDesktopSidebarGlass
                                      ? context.appSpacing.lg
                                      : AppPageInsets.desktop,
                                  hideActions: immersive,
                                ),
                              )
                            else if (usesAppWindowsCaption) ...[
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
                // macOS 红绿灯自绘（系统按钮已隐藏），与收起/展开按钮
                // 一样固定在窗口坐标系，不随侧栏宽度动画移动。
                if (defaultTargetPlatform == TargetPlatform.macOS)
                  Positioned(
                    left: appMacTrafficLightsLeft,
                    top:
                        (context.appComponentTokens.desktopTitleBarHeight -
                            appMacTrafficLightButtonSize) /
                        2,
                    child: const AppMacTrafficLights(),
                  ),
                // 收起/展开按钮固定在窗口左上角（macOS 红绿灯右侧），
                // 不随侧栏宽度动画和顶栏布局切换移动。
                Positioned(
                  left: sidebarToggleButtonLeft(context),
                  top:
                      (context.appComponentTokens.desktopTitleBarHeight -
                          sidebarToggleButtonSize) /
                      2,
                  child: const AppSidebarToggleButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
