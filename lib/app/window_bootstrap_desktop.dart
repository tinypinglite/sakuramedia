import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/appearance_store.dart';
import 'package:sakuramedia/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

const Size _defaultWindowSize = Size(1280, 720);
const Size _minimumWindowSize = Size(1280, 720);

const String _prefsWidthKey = 'desktop_window:width';
const String _prefsHeightKey = 'desktop_window:height';
const String _prefsMaximizedKey = 'desktop_window:maximized';

const MethodChannel _windowAppearanceChannel = MethodChannel(
  'sakuramedia/window_appearance',
);

Future<void> bootstrapDesktopWindow() async {
  await windowManager.ensureInitialized();
  final isMacOS = defaultTargetPlatform == TargetPlatform.macOS;

  final restored = await _readPersistedWindowState();
  final appearance = await _readPersistedAppearance();
  final effective = effectiveBrightness(
    appearance,
    WidgetsBinding.instance.platformDispatcher.platformBrightness,
  );
  final initialColors = AppColors.of(
    themeColor: appearance.themeColor,
    brightness: effective,
  );

  final windowOptions = WindowOptions(
    size: restored.size,
    minimumSize: _minimumWindowSize,
    center: true,
    // macOS 默认走系统毛玻璃（透明窗口），可在外观设置关闭；其它桌面是
    // 不透明窗口：内容铺满整窗，窗口底色只在重绘间隙露出来，取内容面色。
    backgroundColor: isMacOS
        ? Colors.transparent
        : initialColors.surfaceElevated,
    skipTaskbar: false,
    // macOS 藏原生标题栏（自绘红绿灯）；Windows 用 normal 让 window_manager
    // 透传 WM_NCCALCSIZE，runner（win32_window.cpp）接管无边框：可见框画没，
    // WS_THICKFRAME 保留，原生 resize/阴影/Snap/动画都在。
    titleBarStyle: isMacOS ? TitleBarStyle.hidden : TitleBarStyle.normal,
    // macOS 红绿灯改为 Flutter 自绘（AppMacTrafficLights），隐藏系统按钮，
    // 避免与自绘圆点重复；其他平台保持原样。
    windowButtonVisibility: !isMacOS,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Windows 无边框由 runner 原生实现（见 win32_window.cpp），这里不调
    // setAsFrameless，也不补 Dart 边缘热区。
    if (isMacOS) {
      // window_manager 会先按透明窗口应用标题栏选项；这里在 show 前覆盖成
      // 用户保存的窗口毛玻璃偏好，避免启动时先闪一帧透明窗口。
      await _applyMacWindowAppearance(
        brightness: effective,
        windowVibrancy: appearance.windowVibrancy,
      );
    }
    if (restored.maximized) {
      await windowManager.maximize();
    }
    await windowManager.show();
    await windowManager.focus();
  });

  windowManager.addListener(_DesktopWindowStatePersistor());
}

/// 切换明暗或窗口毛玻璃时同步桌面窗口外观。
Future<void> applyDesktopWindowAppearance({
  required Brightness brightness,
  required bool windowVibrancy,
}) async {
  if (resolveAppPlatform() != AppPlatform.desktop) {
    return;
  }
  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
        await _applyMacWindowAppearance(
          brightness: brightness,
          windowVibrancy: windowVibrancy,
        );
      case _:
        await windowManager.setBackgroundColor(
          AppColors.of(
            themeColor: AppThemeColor.burgundy,
            brightness: brightness,
          ).surfaceElevated,
        );
    }
  } catch (_) {
    // 原生外观更新失败不影响应用内主题切换。
  }
}

Future<void> _applyMacWindowAppearance({
  required Brightness brightness,
  required bool windowVibrancy,
}) async {
  try {
    final backgroundColor = AppColors.of(
      themeColor: AppThemeColor.burgundy,
      brightness: brightness,
    ).surfacePage;
    await _windowAppearanceChannel
        .invokeMethod<void>('setAppearance', <String, Object?>{
          'dark': brightness == Brightness.dark,
          'windowVibrancy': windowVibrancy,
          'backgroundColor': backgroundColor.toARGB32(),
        });
  } catch (_) {
    // 旧版本原生侧没有该通道时保持系统外观。
  }
}

class _PersistedWindowState {
  const _PersistedWindowState({required this.size, required this.maximized});
  final Size size;
  final bool maximized;
}

Future<AppearanceSettings> _readPersistedAppearance() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    return SharedPreferencesAppearanceStore(preferences).read();
  } catch (_) {
    return AppearanceSettings.defaults;
  }
}

Future<_PersistedWindowState> _readPersistedWindowState() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble(_prefsWidthKey);
    final height = prefs.getDouble(_prefsHeightKey);
    final maximized = prefs.getBool(_prefsMaximizedKey) ?? false;
    if (width == null || height == null) {
      return _PersistedWindowState(
        size: _defaultWindowSize,
        maximized: maximized,
      );
    }
    return _PersistedWindowState(
      size: Size(
        width.clamp(_minimumWindowSize.width, 10000),
        height.clamp(_minimumWindowSize.height, 10000),
      ),
      maximized: maximized,
    );
  } catch (_) {
    return const _PersistedWindowState(
      size: _defaultWindowSize,
      maximized: false,
    );
  }
}

class _DesktopWindowStatePersistor extends WindowListener {
  @override
  Future<void> onWindowResized() async {
    // 原生全屏/最大化时的尺寸不是用户想要的窗口尺寸：不写 prefs。
    if (await windowManager.isMaximized()) return;
    if (await windowManager.isFullScreen()) return;
    final size = await windowManager.getSize();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsWidthKey, size.width);
      await prefs.setDouble(_prefsHeightKey, size.height);
    } catch (_) {
      // 持久化失败不影响窗口运行,忽略
    }
  }

  @override
  Future<void> onWindowMaximize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsMaximizedKey, true);
    } catch (_) {
      // 忽略
    }
  }

  @override
  Future<void> onWindowUnmaximize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsMaximizedKey, false);
    } catch (_) {
      // 忽略
    }
  }
}
