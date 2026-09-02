import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sakuramedia/app/app.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';

/// 真实组合根下逐条 `go` 过去的移动路由。
///
/// 目的**不是**验证页面内容，而是验证「provider 接线」——页面第一次 build 会把
/// 它依赖的 provider 全部实例化一遍，任何漏接（provider body 还抛
/// `UnimplementedError` 等着组合根 override、或 override 写错域）都会在这里炸。
/// 这类 bug 逃过 1600+ 单测正是因为单测把 provider 全量 override 掉了，body
/// 从来没被执行到（见 `ff9bbbb`：批次 8 漏改 videos 域,打开 Pornbox 才炸）。
///
/// 刻意不含通知/任务中心:它们进页面就开 SSE 与重连退避 timer，widget test 会以
/// 「Pending timers」失败。那两页的行为由各自的 provider 测试覆盖。
const List<String> _mobileSmokeRoutes = <String>[
  mobileMoviesPath,
  mobileActorsPath,
  mobileTagsPath,
  mobilePornboxPath,
  mobileVideoCollectionsPath,
  mobileClipCollectionsPath,
  mobileRankingsPath,
  mobileSearchPath,
  mobileSystemOverviewPath,
  mobileSettingsMediaLibrariesPath,
  mobileSettingsDownloadersPath,
  mobileSettingsIndexersPath,
  mobileSettingsPluginsPath,
  mobileSettingsSystemMaintenancePath,
  mobileSettingsExternalPlayerPath,
];

/// 同上，桌面侧。桌面是一等公民，覆盖面比移动宽。
const List<String> _desktopSmokeRoutes = <String>[
  desktopMoviesPath,
  desktopActorsPath,
  desktopTagsPath,
  desktopVideosPath,
  desktopVideoCollectionsPath,
  desktopClipsPath,
  desktopClipCollectionsPath,
  desktopRankingsPath,
  desktopPlaylistsPath,
  desktopMomentsPath,
  desktopDiscoverMoviesPath,
  desktopFollowPath,
  desktopSearchPath,
  desktopMediaPath,
  desktopMovieSubscriptionsPath,
  desktopConfigurationPath,
  desktopSystemDiagnosticsPath,
];

void main() {
  testWidgets('MyApp preserves router instance across parent rebuilds', (
    WidgetTester tester,
  ) async {
    final sessionStore = SessionStore.inMemory();
    addTearDown(sessionStore.dispose);
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.utc(2026, 1, 1),
    );

    final rebuildNotifier = ValueNotifier<int>(0);
    addTearDown(rebuildNotifier.dispose);

    await tester.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: rebuildNotifier,
        builder: (context, value, child) {
          return MyApp(
            platformOverride: AppPlatform.mobile,
            sessionStore: sessionStore,
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final initialRouter = _routerFrom(tester);
    expect(
      initialRouter.routeInformationProvider.value.uri.path,
      mobileOverviewPath,
    );

    initialRouter.go(mobileActorsPath);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const Key('mobile-actors-page')), findsOneWidget);

    rebuildNotifier.value += 1;
    await tester.pumpAndSettle();

    final rebuiltRouter = _routerFrom(tester);
    expect(identical(rebuiltRouter, initialRouter), isTrue);
    expect(
      rebuiltRouter.routeInformationProvider.value.uri.path,
      mobileActorsPath,
    );
    expect(find.byKey(const Key('mobile-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const Key('mobile-actors-page')), findsOneWidget);
  });

  testWidgets('MyApp uses platform-specific theme mapping', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp(platformOverride: AppPlatform.mobile));
    await tester.pumpAndSettle();

    var materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      materialApp.theme?.appTextScale.s14,
      sakuraMobileThemeData.appTextScale.s14,
    );

    await tester.pumpWidget(const MyApp(platformOverride: AppPlatform.desktop));
    await tester.pumpAndSettle();

    materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(
      materialApp.theme?.appTextScale.s14,
      sakuraDesktopThemeData.appTextScale.s14,
    );
  });

  testWidgets('移动主要路由在真实组合根下都能建起来（provider 接线冒烟）', (WidgetTester tester) async {
    final recorder = _WiringFailureRecorder();
    final router = await _pumpApp(
      tester,
      platform: AppPlatform.mobile,
      viewport: const Size(430, 932),
      recorder: recorder,
    );
    await _walkRoutes(tester, router, _mobileSmokeRoutes);
    expect(recorder.failures, isEmpty, reason: _wiringFailureReason);
  });

  testWidgets('桌面主要路由在真实组合根下都能建起来（provider 接线冒烟）', (WidgetTester tester) async {
    final recorder = _WiringFailureRecorder();
    final router = await _pumpApp(
      tester,
      platform: AppPlatform.desktop,
      viewport: const Size(1600, 1000),
      recorder: recorder,
    );
    await _walkRoutes(tester, router, _desktopSmokeRoutes);
    expect(recorder.failures, isEmpty, reason: _wiringFailureReason);
  });
}

const String _wiringFailureReason =
    '有 provider 抛了 UnimplementedError——它的 body 还在等组合根 override，'
    '但组合根只 override sessionStoreProvider。参照同域其它 provider 改成原生装配'
    '（ref.watch(apiClientProvider) 之类）。';

/// 记录组合根里「provider 自己抛出来」的失败。
///
/// 冒烟跑的时候没有后端，所有拉数据的 provider 都会以 `DioException` 失败——那是
/// 预期的，页面渲染成错误态即可。真正要抓的是**接线**错误：provider body 抛
/// `UnimplementedError`（等着组合根 override 却没人 override）。这类异常会被
/// Riverpod 收进 `AsyncError`、由页面画成和「后端连不上」一模一样的错误卡片，
/// 从 widget 树上分辨不出来——只能在 `providerDidFail` 这一层拦。
final class _WiringFailureRecorder extends ProviderObserver {
  _WiringFailureRecorder();

  final List<String> failures = <String>[];

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    if (error is UnimplementedError) {
      failures.add('${context.provider}: $error');
    }
  }
}

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  required AppPlatform platform,
  required Size viewport,
  _WiringFailureRecorder? recorder,
}) async {
  final sessionStore = SessionStore.inMemory();
  addTearDown(sessionStore.dispose);
  // 不设 baseUrl:各页拉数据会立刻以 DioException 失败落到错误态,不会真发网络。
  // 冒烟关心的是「页面能不能建起来」,不是数据。
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.utc(2026, 12, 31),
  );

  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MyApp(
      platformOverride: platform,
      sessionStore: sessionStore,
      observers: recorder == null ? null : <ProviderObserver>[recorder],
    ),
  );
  await tester.pump();
  return _routerFrom(tester);
}

/// 逐条走过 [routes],每条只断言「没抛异常 + 出得来页面骨架」。
///
/// 用多次 `pump` 而不是 `pumpAndSettle`:这些页面都停在骨架屏/错误态,骨架的
/// shimmer 是无限动画,`pumpAndSettle` 会一直等到超时。帧数要够跑完一次路由
/// 转场——跨 shell 分支(如 library → pornbox)时若上一次转场还没结束就发起
/// 下一次,新旧两个 `StatefulNavigationShell` 会同时在树上、撞同一个 GlobalKey。
Future<void> _walkRoutes(
  WidgetTester tester,
  GoRouter router,
  List<String> routes,
) async {
  for (final path in routes) {
    router.go(path);
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      tester.takeException(),
      isNull,
      reason: '$path 在真实组合根下渲染抛异常——通常是 provider 漏接线',
    );
    expect(find.byType(Scaffold), findsWidgets, reason: '$path 没渲染出页面骨架');
  }
}

GoRouter _routerFrom(WidgetTester tester) {
  final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
  return materialApp.routerConfig! as GoRouter;
}
