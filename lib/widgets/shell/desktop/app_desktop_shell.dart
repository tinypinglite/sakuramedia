import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/routes/app_route_spec.dart';
import 'package:sakuramedia/routes/desktop_top_bar_config.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_sidebar.dart';
import 'package:sakuramedia/widgets/shell/desktop/app_top_bar.dart';

class AppDesktopShell extends StatefulWidget {
  const AppDesktopShell({
    super.key,
    required this.currentPath,
    required this.layout,
    required this.topBarConfig,
    required this.shellNavigatorKey,
    required this.navGroups,
    required this.child,
  });

  final String currentPath;
  final AppShellLayout layout;
  final DesktopTopBarConfig topBarConfig;
  final GlobalKey<NavigatorState> shellNavigatorKey;
  final List<AppNavGroup> navGroups;
  final Widget child;

  @override
  State<AppDesktopShell> createState() => _AppDesktopShellState();
}

class _AppDesktopShellState extends State<AppDesktopShell> {
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
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
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
    try {
      await callback();
    } catch (error) {
      showToast(apiErrorMessage(error, fallback: '刷新失败'));
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
    final useMacSidebarGlass =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

    final current = _current;
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
          backgroundColor:
              useMacSidebarGlass
                  ? Colors.transparent
                  : context.appColors.surfacePage,
          body: SafeArea(
            child: Row(
              children: [
                AppSidebar(
                  currentPath: widget.currentPath,
                  navGroups: widget.navGroups,
                ),
                Expanded(
                  child: Container(
                    key: const Key('desktop-shell-content-surface'),
                    color: context.appColors.surfaceElevated,
                    child: Column(
                      children: [
                        AppTopBar(
                          currentPath: widget.currentPath,
                          config: widget.topBarConfig,
                          shellNavigatorKey: widget.shellNavigatorKey,
                          onRefresh: current == null
                              ? null
                              : () => _runRefresh(current),
                          isRefreshing: current != null && _isRefreshing,
                        ),
                        Expanded(
                          child: _DesktopShellBody(
                            layout: widget.layout,
                            child: widget.child,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopShellBody extends StatelessWidget {
  const _DesktopShellBody({required this.layout, required this.child});

  final AppShellLayout layout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      AppShellLayout.standard => Padding(
        padding: AppPageInsets.desktopStandard,
        child: child,
      ),
      AppShellLayout.fullscreen => child,
    };
  }
}
