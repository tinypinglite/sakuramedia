import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderObserver, ProviderScope;
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/routes/app_router.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/media/images/app_image_fullscreen.dart';

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
    this.observers,
  });

  final AppPlatform? platformOverride;
  final SessionStore? sessionStore;

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
        oldWidget.sessionStore == widget.sessionStore) {
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
    // `sessionStoreProvider` 是唯一组合根 override：会话是应用输入（main 传入
    // 持久化实例、测试传 inMemory），用 value override 接进容器。
    //
    // key 绑定会话实例：`didUpdateWidget` 换 sessionStore 时整个容器随之
    // 重建，等价于旧 MultiProvider 时代的全量重挂。
    return ProviderScope(
      key: ObjectKey(_activeSessionStore),
      overrides: [sessionStoreProvider.overrideWithValue(_activeSessionStore)],
      observers: widget.observers,
      child: AppPlatformScope(
        platform: _platform,
        child: OKToast(
          textStyle: kAppToastTextStyle,
          backgroundColor: kAppToastBackgroundColor,
          child: MaterialApp.router(
            title: 'SakuraMedia',
            debugShowCheckedModeBanner: false,
            theme: _platform == AppPlatform.mobile
                ? sakuraMobileThemeData
                : sakuraDesktopThemeData,
            routerConfig: _router,
            builder: (context, child) {
              return AppImageFullscreenHost(
                child: ScrollConfiguration(
                  behavior: const MaterialScrollBehavior().copyWith(
                    dragDevices: kAppScrollDragDevices,
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
