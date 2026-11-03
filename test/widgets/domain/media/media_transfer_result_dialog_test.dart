import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/media/media_transfer_result_dialog.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  testWidgets(
    'desktop dialog lists unsuccessful files before successful ones',
    (tester) async {
      final bundle = await _createBundle();
      addTearDown(bundle.dispose);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media-transfers/7/files',
        body: <Map<String, dynamic>>[
          _fileJson(
            mediaId: 11,
            fileName: 'ABC-001.mp4',
            status: 'transferred',
            targetCommitted: true,
          ),
          _fileJson(
            mediaId: 12,
            fileName: 'ABC-002.mp4',
            status: 'failed',
            reasonCode: 'media_busy',
          ),
          _fileJson(
            mediaId: 13,
            fileName: 'ABC-003.mp4',
            status: 'cleanup_incomplete',
            reasonCode: 'cleanup_unconfirmed',
            targetCommitted: true,
          ),
        ],
      );

      await tester.pumpWidget(_buildApp(bundle, AppPlatform.desktop));
      await tester.tap(find.text('打开结果'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('media-transfer-result-modal')),
        findsOneWidget,
      );
      expect(find.text('迁移结果'), findsOneWidget);
      expect(find.text('媒体存储迁移 · 成功 1 · 未成功 2'), findsOneWidget);
      expect(find.text('未成功（2）'), findsOneWidget);
      expect(find.text('迁移成功（1）'), findsOneWidget);
      expect(find.text('ABC-002.mp4'), findsOneWidget);
      expect(find.text('ABC-003.mp4'), findsOneWidget);
      expect(find.text('ABC-001.mp4'), findsOneWidget);
      expect(find.text('失败'), findsOneWidget);
      expect(find.text('源文件待确认'), findsOneWidget);
      expect(find.text('已迁移'), findsOneWidget);
      expect(find.textContaining('媒体被其他任务占用'), findsOneWidget);
      expect(find.textContaining('源文件清理结果未确认'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('未成功（2）')).dy,
        lessThan(tester.getTopLeft(find.text('迁移成功（1）')).dy),
      );

      final request = bundle.adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/media-transfers/7/files');
    },
  );

  testWidgets('shows empty state when no file details were saved', (
    tester,
  ) async {
    final bundle = await _createBundle();
    addTearDown(bundle.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-transfers/7/files',
      body: const <Map<String, dynamic>>[],
    );

    await tester.pumpWidget(_buildApp(bundle, AppPlatform.desktop));
    await tester.tap(find.text('打开结果'));
    await tester.pumpAndSettle();

    expect(find.text('该任务没有可展示的文件明细'), findsOneWidget);
  });

  testWidgets('retries after a load failure and then shows files', (
    tester,
  ) async {
    final bundle = await _createBundle();
    addTearDown(bundle.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-transfers/7/files',
      statusCode: 502,
      body: <String, dynamic>{
        'error': {'code': 'media_transfer_files_failed', 'message': 'boom'},
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-transfers/7/files',
      body: <Map<String, dynamic>>[
        _fileJson(
          mediaId: 11,
          fileName: 'ABC-001.mp4',
          status: 'transferred',
          targetCommitted: true,
        ),
      ],
    );

    await tester.pumpWidget(_buildApp(bundle, AppPlatform.desktop));
    await tester.tap(find.text('打开结果'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-transfer-result-retry')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('media-transfer-result-retry')));
    await tester.pumpAndSettle();

    expect(find.text('ABC-001.mp4'), findsOneWidget);
    expect(bundle.adapter.requests, hasLength(2));
  });

  testWidgets('opens as a mobile drawer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bundle = await _createBundle();
    addTearDown(bundle.dispose);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-transfers/7/files',
      body: <Map<String, dynamic>>[
        _fileJson(
          mediaId: 11,
          fileName: 'ABC-001.mp4',
          status: 'transferred',
          targetCommitted: true,
        ),
        _fileJson(
          mediaId: 12,
          fileName: 'ABC-002.mp4',
          status: 'cleanup_incomplete',
          reasonCode: 'cleanup_unconfirmed',
          targetCommitted: true,
        ),
      ],
    );

    await tester.pumpWidget(_buildApp(bundle, AppPlatform.mobile));
    await tester.tap(find.text('打开结果'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('media-transfer-result-modal')),
      findsOneWidget,
    );
    expect(find.text('ABC-001.mp4'), findsOneWidget);
    expect(find.text('ABC-002.mp4'), findsOneWidget);
    expect(find.text('源文件待确认'), findsOneWidget);
  });
}

Map<String, dynamic> _fileJson({
  required int mediaId,
  required String fileName,
  required String status,
  String? reasonCode,
  bool targetCommitted = false,
}) {
  return <String, dynamic>{
    'media_id': mediaId,
    'file_name': fileName,
    'movie_number': fileName.replaceAll('.mp4', ''),
    'size_bytes': 2048,
    'status': status,
    'reason_code': reasonCode,
    'target_committed': targetCommitted,
  };
}

Widget _buildApp(TestApiBundle bundle, AppPlatform platform) {
  return ProviderScope(
    overrides: bundle.riverpodOverrides(),
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
      theme: platform == AppPlatform.mobile
          ? sakuraMobileThemeData
          : sakuraDesktopThemeData,
      home: AppPlatformScope(
        platform: platform,
        child: const _DialogLauncher(),
      ),
    ),
  );
}

class _DialogLauncher extends StatelessWidget {
  const _DialogLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => unawaited(
            showMediaTransferResultDialog(
              context: context,
              taskRunId: 7,
              taskName: '媒体存储迁移',
            ),
          ),
          child: const Text('打开结果'),
        ),
      ),
    );
  }
}

Future<TestApiBundle> _createBundle() async {
  final sessionStore = SessionStore.inMemory();
  await sessionStore.saveBaseUrl('https://api.example.com');
  await sessionStore.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
  );
  return createTestApiBundle(sessionStore);
}
