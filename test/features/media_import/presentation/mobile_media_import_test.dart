import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media_import/presentation/pages/shared/media_import_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_desktop_dialog.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(320, 568)]) {
    testWidgets('mobile JAV import browses and submits at $size', (
      tester,
    ) async {
      final bundle = await _pumpPage(tester, size: size);
      _enqueueLibrary(bundle);
      _browse(bundle, [_entry('folder', '待导入影片目录', 'directory')]);
      _browse(bundle, []);
      final accepted = Completer<ResponseBody>();
      bundle.adapter.enqueueResponder(
        method: 'POST',
        path: '/imports',
        responder: (_, __) => accepted.future,
      );

      await _tap(tester, 'media-import-create-button');
      expect(find.byType(AppBottomDrawerSurface), findsOneWidget);
      expect(find.byType(AppDesktopDialog), findsNothing);
      expect(
        _button(tester, 'media-import-picker-submit-button').onPressed,
        isNull,
      );
      await _tap(tester, 'media-import-entry-0');
      await _tap(tester, 'media-import-picker-select-current-directory-button');
      final submit = find.byKey(const Key('media-import-picker-submit-button'));
      expect(submit.hitTestable(), findsOneWidget);
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_button(tester, 'media-import-create-button').onPressed, isNull);
      expect(bundle.adapter.hitCount('POST', '/imports'), 1);
      expect(bundle.adapter.requests.last.body, {
        'media_kind': 'jav',
        'library_id': 1,
        'source_ref': {'id': 'folder'},
        'source_disposition': 'keep',
      });
      accepted.complete(
        ResponseBody.fromString(
          jsonEncode({'task_run_id': 42, 'state': 'pending'}),
          202,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('导入任务 #42 已提交'), findsOneWidget);
      expect(
        _button(tester, 'media-import-create-button').onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
    });
  }

  testWidgets(
    'mobile video imports a file with a collection and source disposition',
    (tester) async {
      final bundle = await _pumpPage(tester);
      _enqueueLibrary(bundle);
      _browse(bundle, [_entry('file', '旅行记录与家庭影像的长文件名称.mp4', 'file')]);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/video-collections',
        body: [
          {'id': 7, 'name': '旅行记录'},
        ],
      );
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/imports',
        statusCode: 202,
        body: {'task_run_id': 43, 'state': 'pending'},
      );
      await _tap(tester, 'media-import-tab-video');
      await _tap(tester, 'media-import-create-button');
      expect(find.byType(AppBottomDrawerSurface), findsOneWidget);
      expect(_button(tester, 'video-import-submit-button').onPressed, isNull);
      await _tap(tester, 'media-import-entry-0');
      await tester.ensureVisible(
        find.byKey(const Key('media-import-picker-source-disposition-select')),
      );
      await _tap(tester, 'media-import-picker-source-disposition-select');
      await tester.tap(find.text('导入成功后删除源文件').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('media-import-source-disposition-warning')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('不加入合集'));
      await tester.tap(find.text('不加入合集'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('旅行记录').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('video-import-submit-button')).hitTestable(),
        findsOneWidget,
      );
      await _tap(tester, 'video-import-submit-button');
      expect(bundle.adapter.requests.last.body, {
        'media_kind': 'video',
        'library_id': 1,
        'source_ref': {'id': 'file'},
        'source_disposition': 'delete_after_commit',
        'collection_id': 7,
      });
      expect(find.textContaining('视频导入任务 #43 已提交'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
    },
  );

  testWidgets(
    'mobile import retries library and browse errors and can cancel',
    (tester) async {
      final bundle = await _pumpPage(tester);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media-libraries',
        statusCode: 500,
      );
      _enqueueLibrary(bundle);
      bundle.adapter.enqueueJson(
        method: 'POST',
        path: '/import-sources/browse',
        statusCode: 500,
      );
      _browse(bundle, []);
      await _tap(tester, 'media-import-create-button');
      await _tap(tester, 'media-import-library-retry-button');
      await _tap(tester, 'media-import-picker-browse-retry-button');
      expect(find.text('该来源下没有可导入的文件或目录'), findsOneWidget);
      expect(
        _button(tester, 'media-import-picker-submit-button').onPressed,
        isNull,
      );
      await _tap(tester, 'media-import-picker-cancel-button');
      expect(find.byType(AppBottomDrawerSurface), findsNothing);
      expect(bundle.adapter.hitCount('POST', '/imports'), 0);
      expect(
        _button(tester, 'media-import-create-button').onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('failed mobile import shows feedback and allows a new attempt', (
    tester,
  ) async {
    final bundle = await _pumpPage(tester);
    _enqueueLibrary(bundle);
    _browse(bundle, [_entry('folder', '待导入目录', 'directory')]);
    _browse(bundle, []);
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/imports',
      statusCode: 400,
      body: {
        'error': {'code': 'import_failed', 'message': '来源暂不可用，请重试'},
      },
    );
    await _tap(tester, 'media-import-create-button');
    await _tap(tester, 'media-import-entry-0');
    await _tap(tester, 'media-import-picker-select-current-directory-button');
    await _tap(tester, 'media-import-picker-submit-button');
    expect(find.text('来源暂不可用，请重试'), findsOneWidget);
    expect(_button(tester, 'media-import-create-button').onPressed, isNotNull);
    expect(_button(tester, 'media-import-create-button').isLoading, isFalse);
    expect(bundle.adapter.hitCount('POST', '/imports'), 1);
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('mobile video collection creation uses a nested bottom drawer', (
    tester,
  ) async {
    final bundle = await _pumpPage(tester);
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media-libraries',
      body: [],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/video-collections',
      body: [],
    );
    await _tap(tester, 'media-import-tab-video');
    await _tap(tester, 'media-import-create-button');
    await _tap(tester, 'video-import-create-collection-button');
    expect(
      find.byKey(const Key('video-collection-edit-bottom-sheet')),
      findsOneWidget,
    );
    expect(find.byType(AppDesktopDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

AppButton _button(WidgetTester tester, String key) =>
    tester.widget<AppButton>(find.byKey(Key(key)));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<TestApiBundle> _pumpPage(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final session = SessionStore.inMemory();
  await session.saveBaseUrl('https://api.example.com');
  final bundle = await createTestApiBundle(session);
  addTearDown(bundle.dispose);
  addTearDown(session.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: AppPlatformScope(
        platform: AppPlatform.mobile,
        child: OKToast(
          child: MaterialApp(
            theme: sakuraMobileThemeData,
            home: const Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: AppPageInsets.compactStandard,
                  child: MediaImportPage(),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return bundle;
}

void _enqueueLibrary(TestApiBundle bundle) => bundle.adapter.enqueueJson(
  method: 'GET',
  path: '/media-libraries',
  body: [
    {
      'id': 1,
      'name': '主媒体库',
      'provider_key': 'provider-a',
      'provider_config': {},
    },
  ],
);

void _browse(TestApiBundle bundle, List<Map<String, dynamic>> entries) =>
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/import-sources/browse',
      body: {'library_id': 1, 'entries': entries, 'next_cursor': null},
    );

Map<String, dynamic> _entry(String id, String name, String type) => {
  'source_ref': {'id': id},
  'name': name,
  'entry_type': type,
  'is_video': type == 'file',
  'size_bytes': type == 'file' ? 1024 : null,
};
