import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugins_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/widgets/plugin_restart_notice_dialog.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/logged_in_session_store.dart';
import '../../../../support/pump_with_providers.dart';
import '../../../../support/test_api_bundle.dart';

void main() {
  testWidgets('desktop restart notice closes from later or barrier', (
    tester,
  ) async {
    final bundle = await _createBundle();

    await _openRestartNotice(tester, bundle: bundle);
    await _tapLater(tester);
    expect(bundle.adapter.hitCount('POST', '/system/plugins/apply'), 0);

    await tester.tap(find.byKey(const Key('open-plugin-restart-notice')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plugin-restart-notice-dialog')), findsNothing);
    expect(bundle.adapter.hitCount('POST', '/system/plugins/apply'), 0);
  });

  testWidgets('mobile restart notice closes from later or barrier', (
    tester,
  ) async {
    final bundle = await _createBundle();

    await _openRestartNotice(tester, bundle: bundle, mobile: true);
    await _tapLater(tester);
    expect(bundle.adapter.hitCount('POST', '/system/plugins/apply'), 0);

    await tester.tap(find.byKey(const Key('open-plugin-restart-notice')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('plugin-restart-notice-dialog')), findsNothing);
  });

  testWidgets('restart now applies, waits for recovery, and refreshes', (
    tester,
  ) async {
    final bundle = await _createBundle();
    for (var i = 0; i < 2; i++) {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/plugins',
        body: <Map<String, dynamic>>[],
      );
    }
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/apply',
      statusCode: 202,
      body: <String, dynamic>{
        'status': 'restarting',
        'processes': <String>['api', 'aps'],
      },
    );
    // 第一次探活必须失败，证明旧进程已经下线。
    bundle.adapter.enqueueResponder(
      method: 'GET',
      path: '/healthz',
      responder: (options, _) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      },
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/healthz',
      body: <String, dynamic>{'status': 'ok'},
    );

    await _openRestartNotice(tester, bundle: bundle, watchPlugins: true);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('plugin-restart-notice-restart-button')),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('plugin-restart-notice-busy-button')),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(
      find.byKey(const Key('plugin-restart-notice-dialog')),
      findsOneWidget,
    );

    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('plugin-restart-notice-dialog'))
          .evaluate()
          .isEmpty,
      step: const Duration(seconds: 1),
      maxPumps: 60,
    );
    await tester.pump();

    expect(bundle.adapter.hitCount('POST', '/system/plugins/apply'), 1);
    expect(bundle.adapter.hitCount('GET', '/healthz'), greaterThanOrEqualTo(3));
    expect(bundle.adapter.hitCount('GET', '/system/plugins'), 2);
    expect(find.text('后端已重启，变更已生效'), findsOneWidget);
    await _drainToastTimers(tester);
  });

  testWidgets('boot id change confirms a fast restart without a down probe', (
    tester,
  ) async {
    final bundle = await _createBundle();
    for (var i = 0; i < 2; i++) {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/plugins',
        body: <Map<String, dynamic>>[],
      );
    }
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/apply',
      statusCode: 202,
      body: <String, dynamic>{
        'status': 'restarting',
        'processes': <String>['api', 'aps'],
        'boot_id': 'boot-old',
      },
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/healthz',
      body: <String, dynamic>{'status': 'ok', 'boot_id': 'boot-new'},
    );

    await _openRestartNotice(tester, bundle: bundle, watchPlugins: true);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('plugin-restart-notice-restart-button')),
    );
    await tester.pump();

    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('plugin-restart-notice-dialog'))
          .evaluate()
          .isEmpty,
      step: const Duration(seconds: 1),
      maxPumps: 60,
    );
    await tester.pump();

    expect(bundle.adapter.hitCount('POST', '/system/plugins/apply'), 1);
    expect(bundle.adapter.hitCount('GET', '/healthz'), greaterThanOrEqualTo(1));
    expect(bundle.adapter.hitCount('GET', '/system/plugins'), 2);
    expect(find.text('后端已重启，变更已生效'), findsOneWidget);
    await _drainToastTimers(tester);
  });

  testWidgets('apply failure keeps the dialog open and retryable', (
    tester,
  ) async {
    final bundle = await _createBundle();
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/apply',
      statusCode: 422,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'plugin_dependency_sync_failed',
          'message': '插件依赖同步失败，未触发重启',
          'details': <String, dynamic>{
            'failures': <String, dynamic>{'demo_plugin': 'pip install failed'},
          },
        },
      },
    );

    await _openRestartNotice(tester, bundle: bundle);
    await tester.tap(
      find.byKey(const Key('plugin-restart-notice-restart-button')),
    );
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('plugin-restart-notice-error'))
          .evaluate()
          .isNotEmpty,
    );

    expect(
      find.byKey(const Key('plugin-restart-notice-dialog')),
      findsOneWidget,
    );
    expect(find.text('插件依赖同步失败，未触发重启'), findsOneWidget);
    expect(bundle.adapter.hitCount('GET', '/healthz'), 0);
    expect(
      find.byKey(const Key('plugin-restart-notice-confirm-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('plugin-restart-notice-restart-button')),
      findsOneWidget,
    );

    await _tapLater(tester);
  });

  testWidgets('continuous healthy responses without a down probe time out', (
    tester,
  ) async {
    final bundle = await _createBundle();
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/plugins/apply',
      statusCode: 202,
      body: <String, dynamic>{
        'status': 'restarting',
        'processes': <String>['api', 'aps'],
      },
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/healthz',
      body: <String, dynamic>{'status': 'ok'},
    );

    await _openRestartNotice(tester, bundle: bundle);
    await tester.tap(
      find.byKey(const Key('plugin-restart-notice-restart-button')),
    );
    await _pumpUntil(
      tester,
      () => find.text('等待后端重启超时，请稍后重试').evaluate().isNotEmpty,
      step: const Duration(seconds: 1),
      maxPumps: 45,
    );

    expect(
      find.byKey(const Key('plugin-restart-notice-dialog')),
      findsOneWidget,
    );
    expect(find.text('后端已重启，变更已生效'), findsNothing);
    expect(
      find.byKey(const Key('plugin-restart-notice-restart-button')),
      findsOneWidget,
    );

    await _tapLater(tester);
  });
}

Future<TestApiBundle> _createBundle() async {
  final sessionStore = await buildLoggedInSessionStore();
  final bundle = await createTestApiBundle(sessionStore);
  addTearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });
  return bundle;
}

Future<void> _openRestartNotice(
  WidgetTester tester, {
  required TestApiBundle bundle,
  bool mobile = false,
  bool watchPlugins = false,
}) async {
  await pumpWithProviders(
    tester,
    bundle: bundle,
    theme: mobile
        ? buildSakuraMobileThemeData()
        : buildSakuraDesktopThemeData(),
    physicalSize: mobile ? const Size(390, 844) : const Size(1100, 800),
    wrap: mobile
        ? (child) =>
              AppPlatformScope(platform: AppPlatform.mobile, child: child)
        : null,
    home: _RestartNoticeHost(watchPlugins: watchPlugins),
  );
  await tester.tap(find.byKey(const Key('open-plugin-restart-notice')));
  await tester.pumpAndSettle();
}

Future<void> _tapLater(WidgetTester tester) async {
  await tester.tap(
    find.byKey(const Key('plugin-restart-notice-confirm-button')),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('plugin-restart-notice-dialog')), findsNothing);
}

Future<void> _drainToastTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

class _RestartNoticeHost extends ConsumerWidget {
  const _RestartNoticeHost({required this.watchPlugins});

  final bool watchPlugins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (watchPlugins) {
      ref.watch(pluginsProvider);
    }
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const Key('open-plugin-restart-notice'),
          onPressed: () => showPluginRestartNoticeDialog(
            context,
            action: PluginRestartNoticeAction.upgraded,
            pluginName: '115 provider',
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration step = const Duration(milliseconds: 20),
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (condition()) {
      return;
    }
    await tester.pump(step);
  }
  expect(
    condition(),
    isTrue,
    reason: 'condition not met after $maxPumps pumps',
  );
}
