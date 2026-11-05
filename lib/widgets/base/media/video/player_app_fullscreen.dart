import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:sakuramedia/app/app_window_fullscreen.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 带右侧缩略图面板的播放页共用的「应用内全屏」状态。
///
/// 背景：media_kit 的全屏会 push 一个只含 [Video] 的独立路由，右侧缩略图
/// 面板不在该路由内。想要全屏保留面板，就不能走它的全屏，只能在当前路由内
/// 切换布局（铺满页面）+ 桌面端叠加系统窗口全屏。
/// 窗口那一半见 `app_window_fullscreen.dart`（macOS/Windows 都走原生全屏）。
///
/// 用法：各播放页 `State` 持有一份全屏标记，用 [PlayerAppFullscreenScope]
/// 把状态暴露给底栏按钮；页面布局按 `isAppFullscreen` 切换。Player /
/// VideoController 实例全程不重建，只换祖先布局。
class PlayerAppFullscreenScope extends InheritedWidget {
  const PlayerAppFullscreenScope({
    super.key,
    required this.isFullscreen,
    required this.onToggle,
    required super.child,
  });

  final bool isFullscreen;
  final VoidCallback onToggle;

  static PlayerAppFullscreenScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PlayerAppFullscreenScope>();
  }

  @override
  bool updateShouldNotify(PlayerAppFullscreenScope oldWidget) {
    return isFullscreen != oldWidget.isFullscreen;
  }
}

/// 桌面系统窗口全屏的开关（应用内布局切换之外的另一半）。
///
/// 平台差异见 `app_window_fullscreen.dart`；这里保留播放页侧的调用点，
/// 调用方只关心布局态。
Future<void> applyPlayerAppFullscreenWindow(bool enabled) async {
  await applyDesktopWindowFullscreen(enabled);
}

/// 桌面底栏全屏按钮：有 [PlayerAppFullscreenScope] 时切换应用内全屏
/// （保留右侧面板），无 scope（如快播弹窗等无面板场景）时回退到
/// media_kit 原生全屏，保持既有行为不变。
class PlayerAppFullscreenButton extends StatelessWidget {
  const PlayerAppFullscreenButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = PlayerAppFullscreenScope.maybeOf(context);
    if (scope == null) {
      return const MaterialFullscreenButton();
    }
    final icon = Icon(
      scope.isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
    );
    final l10n = appL10n(context);
    final tooltip = scope.isFullscreen
        ? l10n.baseExitFullscreen
        : l10n.baseEnterFullscreen;
    return MaterialDesktopCustomButton(
      onPressed: scope.onToggle,
      icon: Tooltip(message: tooltip, child: icon),
    );
  }
}

/// 桌面端视频区双击切应用内全屏的包装。
///
/// 触摸控件下双击是快进手势（seekOnDoubleTap），此时禁用，避免手势打架；
/// 桌面端 media_kit 的双击全屏已由主题关闭（见 `toggleFullscreenOnDoublePress`），
/// 这里只响应外层双击切应用内全屏。只包左侧播放画面，不包右侧面板。
class PlayerAppFullscreenDoubleTap extends StatelessWidget {
  const PlayerAppFullscreenDoubleTap({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    final scope = PlayerAppFullscreenScope.maybeOf(context);
    if (scope == null) {
      return child;
    }
    return GestureDetector(onDoubleTap: scope.onToggle, child: child);
  }
}

/// 各播放页复用的全屏状态机：持标记 + 窗口全屏 + Esc 退出。
///
/// Esc 用 [HardwareKeyboard] 全局 handler 而不用 [CallbackShortcuts]：
/// media_kit 桌面控件内部已绑定 Esc→退出原生全屏并消费按键，
/// 外层 Shortcuts 收不到，顶层 handler 才能可靠拦截。
/// 回调里只做布局态切换，不劫持页面返回（返回键行为不变）。
///
/// 注意：mixin 的 `dispose` 会被类的 `dispose` 覆盖而失效，
/// 因此退出清理放在 [disposePlayerAppFullscreen]，各页在自身
/// `dispose` 首行显式调用它。
mixin PlayerAppFullscreenStateMixin<T extends StatefulWidget> on State<T> {
  bool isAppFullscreen = false;
  bool _appFullscreenKeyHandlerRegistered = false;

  /// 是否叠加系统窗口全屏：桌面页传 `true`，移动页传 `false`
  /// （移动页进入时已锁横屏+沉浸，无需再调窗口）。
  bool get applySystemFullscreenForAppFullscreen => true;

  void toggleAppFullscreen() {
    if (isAppFullscreen) {
      exitAppFullscreen();
    } else {
      enterAppFullscreen();
    }
  }

  void enterAppFullscreen() {
    if (isAppFullscreen) {
      return;
    }
    setState(() => isAppFullscreen = true);
    if (applySystemFullscreenForAppFullscreen) {
      unawaited(applyPlayerAppFullscreenWindow(true));
    }
    if (!_appFullscreenKeyHandlerRegistered) {
      _appFullscreenKeyHandlerRegistered = true;
      HardwareKeyboard.instance.addHandler(_handleAppFullscreenKey);
    }
  }

  void exitAppFullscreen() {
    if (!isAppFullscreen) {
      return;
    }
    setState(() => isAppFullscreen = false);
    if (applySystemFullscreenForAppFullscreen) {
      unawaited(applyPlayerAppFullscreenWindow(false));
    }
    _unregisterAppFullscreenKeyHandler();
  }

  bool _handleAppFullscreenKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        isAppFullscreen) {
      exitAppFullscreen();
      return true;
    }
    return false;
  }

  void _unregisterAppFullscreenKeyHandler() {
    if (_appFullscreenKeyHandlerRegistered) {
      _appFullscreenKeyHandlerRegistered = false;
      HardwareKeyboard.instance.removeHandler(_handleAppFullscreenKey);
    }
  }

  /// 各页在自身 `dispose` 首行调用（mixin 的 `dispose` 会被类的同名
  /// 方法覆盖而失效，必须走这个显式入口）。
  void disposePlayerAppFullscreen() {
    _unregisterAppFullscreenKeyHandler();
    // 退出时尽力恢复窗口态，不阻塞 dispose。
    if (isAppFullscreen && applySystemFullscreenForAppFullscreen) {
      unawaited(applyPlayerAppFullscreenWindow(false));
    }
  }
}
