import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/app/appearance_store.dart';
import 'package:sakuramedia/app/language/language_store.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
import 'package:sakuramedia/app/providers/appearance_providers.dart';
import 'package:sakuramedia/app/window_bootstrap_desktop.dart'
    show applyDesktopWindowBrightness;
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_fullscreen.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';

/// 允许发起拖拽滚动的指针类型集合(应用全局 [ScrollConfiguration] 使用)。
///
/// 必须为 [PointerDeviceKind] 全集 —— 尤其不能漏掉 [PointerDeviceKind.unknown]:
/// 无障碍服务 / 远程控制工具(如 Android VoiceAccess、RustDesk 经
/// `AccessibilityService.dispatchGesture` 注入的滑动手势)上报的 pointer kind
/// 即为 unknown,缺它会导致这类来源只能点击、无法滚动(Flutter 框架默认集合
/// `_kTouchLikeDeviceTypes` 同样包含 unknown,原因一致)。
const Set<PointerDeviceKind> kAppScrollDragDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
  PointerDeviceKind.unknown,
};

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.platformOverride,
    this.sessionStore,
    this.appearanceStore,
    this.languageStore,
    this.observers,
  });

  final AppPlatform? platformOverride;
  final SessionStore? sessionStore;

  /// 外观偏好存储；生产传 SharedPreferences 实现，测试/预览默认内存实现。
  final AppearanceStore? appearanceStore;

  /// 界面语言存储；生产传 SharedPreferences 实现，测试/预览默认内存实现。
  final AppLanguageStore? languageStore;

  /// 挂到组合根 [ProviderScope] 上的观察者。
  ///
  /// 生产不传。给 `test/app_test.dart` 的路由冒烟用：provider 在 build 里抛的
  /// 异常会被 Riverpod 收进 `AsyncError`、由页面渲染成普通错误态，从外面看不出
  /// 是「接线错了」还是「后端没连上」；挂 `providerDidFail` 才分得清。
  final List<ProviderObserver>? observers;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppPlatform _platform;
  late SessionStore _activeSessionStore;
  late AppearanceStore _activeAppearanceStore;
  late AppLanguageStore _activeLanguageStore;
  late GoRouter _router;
  late bool _ownsSessionStore;

  @override
  void initState() {
    super.initState();
    _initializeAppState();
  }

  @override
  void didUpdateWidget(covariant MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.platformOverride == widget.platformOverride &&
        oldWidget.sessionStore == widget.sessionStore &&
        oldWidget.languageStore == widget.languageStore) {
      return;
    }

    _disposeAppState();
    _initializeAppState();
  }

  @override
  void dispose() {
    _disposeAppState();
    super.dispose();
  }

  void _initializeAppState() {
    _platform = resolveAppPlatform(override: widget.platformOverride);
    _ownsSessionStore = widget.sessionStore == null;
    _activeSessionStore = widget.sessionStore ?? SessionStore.inMemory();
    _activeAppearanceStore =
        widget.appearanceStore ?? InMemoryAppearanceStore();
    _activeLanguageStore = widget.languageStore ?? InMemoryLanguageStore();
    _router = buildAppRouter(_platform, _activeSessionStore);
  }

  void _disposeAppState() {
    _router.dispose();
    if (_ownsSessionStore) {
      _activeSessionStore.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 组合根（Riverpod 原生装配）。
    //
    // 各 API / Store / 广播源都在各自 provider 里原生构造（见
    // `presentation/providers/` 与 `core/*/providers/`），这里只注入
    // `sessionStoreProvider` 与 `appearanceStoreProvider` 两个组合根 override：
    // 会话与外观偏好是应用输入（main 传入持久化实例、测试传 inMemory），
    // 用 value override 接进容器。
    //
    // key 绑定会话实例：`didUpdateWidget` 换 sessionStore 时整个容器随之
    // 重建，等价于旧 MultiProvider 时代的全量重挂。
    return AppSurfaceRuntime.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: ProviderScope(
        key: ObjectKey(_activeSessionStore),
        overrides: [
          sessionStoreProvider.overrideWithValue(_activeSessionStore),
          appearanceStoreProvider.overrideWithValue(_activeAppearanceStore),
          appLanguageStoreProvider.overrideWithValue(_activeLanguageStore),
        ],
        observers: widget.observers,
        child: AppPlatformScope(
          platform: _platform,
          child: _SakuraApp(platform: _platform, router: _router),
        ),
      ),
    );
  }
}

/// 主题装配层：读外观偏好，构建明暗主题并同步平台窗口外观。
class _SakuraApp extends ConsumerStatefulWidget {
  const _SakuraApp({required this.platform, required this.router});

  final AppPlatform platform;
  final GoRouter router;

  @override
  ConsumerState<_SakuraApp> createState() => _SakuraAppState();
}

class _SakuraAppState extends ConsumerState<_SakuraApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Brightness get _platformBrightness =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void didChangePlatformBrightness() {
    // 只有跟随系统才需要响应：同步 toast 样式与原生窗口外观；
    // 固定明/暗模式不随系统切换变化。
    if (ref.read(appearanceProvider).themeMode != ThemeMode.system) {
      return;
    }
    unawaited(applyDesktopWindowBrightness(_platformBrightness));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    final language = ref.watch(appLanguageControllerProvider);

    ref.listen(appearanceProvider, (previous, next) {
      if (previous == null) {
        return;
      }
      final previousBrightness = effectiveBrightness(
        previous,
        _platformBrightness,
      );
      final nextBrightness = effectiveBrightness(next, _platformBrightness);
      if (previousBrightness != nextBrightness) {
        unawaited(applyDesktopWindowBrightness(nextBrightness));
      }
    });

    final themeColor = appearance.themeColor;
    final lightTheme = widget.platform == AppPlatform.mobile
        ? buildSakuraMobileThemeData(themeColor: themeColor)
        : buildSakuraDesktopThemeData(themeColor: themeColor);
    final darkTheme = widget.platform == AppPlatform.mobile
        ? buildSakuraMobileThemeData(
            themeColor: themeColor,
            brightness: Brightness.dark,
          )
        : buildSakuraDesktopThemeData(
            themeColor: themeColor,
            brightness: Brightness.dark,
          );

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: language.locale,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: appearance.themeMode,
      routerConfig: widget.router,
      builder: (context, child) {
        final content = AppImageFullscreenHost(
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior().copyWith(
              dragDevices: kAppScrollDragDevices,
              scrollbars: false,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
        // Windows 无边框由 runner 原生实现，不需要 Dart 边缘热区。
        // ignore: deprecated_member_use
        return OKToast(child: MaterialUiCompatibilityBridge(child: content));
      },
    );
  }
}
