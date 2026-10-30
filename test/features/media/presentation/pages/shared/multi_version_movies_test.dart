import 'dart:async';
import 'dart:convert';

import 'package:sakuramedia/app/app_platform.dart';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/presentation/pages/shared/media_management_content.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import '../../../../../support/test_api_bundle.dart';

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      'versions ${mobile ? "mobile" : "desktop"}: lazy loading, details, delete failure and retry',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = mobile
            ? const Size(360, 760)
            : const Size(1100, 760);
        addTearDown(tester.view.reset);
        final session = SessionStore.inMemory();
        await session.saveBaseUrl('https://api.example.com');
        await session.saveTokens(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: DateTime(2030),
        );
        final bundle = await createTestApiBundle(session);
        addTearDown(() {
          bundle.dispose();
          session.dispose();
        });
        bundle.adapter.setFallbackJson(
          method: 'GET',
          path: '/media',
          body: _page([]),
        );
        bundle.adapter.setFallbackJson(
          method: 'GET',
          path: '/media-libraries',
          body: [
            {
              'id': 1,
              'name': '本地影视库',
              'provider_key': 'local',
              'provider_config': {},
            },
          ],
        );
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/media/multi-version-movies',
          body: _page([_group()]),
        );
        String? opened;
        await tester.pumpWidget(
          ProviderScope(
            overrides: bundle.riverpodOverrides(),
            child: MaterialApp(
              theme: mobile ? sakuraMobileThemeData : sakuraThemeData,
              locale: const Locale('zh'),
              localizationsDelegates: <LocalizationsDelegate<dynamic>>[
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
              builder: (_, child) => AppPlatformScope(
                platform: mobile ? AppPlatform.mobile : AppPlatform.desktop,
                child: child!,
              ),
              home: OKToast(
                child: Scaffold(
                  body: MediaManagementContent(
                    keyPrefix: 'test',
                    rootKey: const Key('page'),
                    mobile: mobile,
                    onOpenMovieDetail: (_, number) => opened = number,
                    onOpenVideoCollectionDetail: (_, __) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          bundle.adapter.hitCount('GET', '/media/multi-version-movies'),
          0,
        );
        await tester.tap(find.byKey(const Key('test-tab-versions')));
        await tester.pumpAndSettle();
        expect(find.text('2 个版本'), findsOneWidget);
        expect(find.textContaining('8.0 GB'), findsOneWidget);
        expect(find.textContaining('· 2160p'), findsOneWidget);
        expect(find.text('失效'), findsOneWidget);
        expect(find.textContaining('本地影视库'), findsNWidgets(2));
        final firstRow = tester.getSize(
          find.byKey(const Key('test-version-row-1')),
        );
        final secondRow = tester.getSize(
          find.byKey(const Key('test-version-row-2')),
        );
        expect(firstRow.height, secondRow.height);
        expect(firstRow.height, lessThan(120));
        final firstTags = find.byKey(const Key('test-version-media-tags-1'));
        final secondTags = find.byKey(const Key('test-version-media-tags-2'));
        expect(firstTags, findsOneWidget);
        expect(secondTags, findsOneWidget);
        expect(
          tester.widget<SingleChildScrollView>(firstTags).scrollDirection,
          Axis.horizontal,
        );
        expect(
          tester.widget<SingleChildScrollView>(secondTags).scrollDirection,
          Axis.horizontal,
        );
        for (final label in [
          '手工',
          '4K',
          '中文字幕',
          '60fps',
          '10bit',
          'DDP5.1',
          'LongTag6',
        ]) {
          expect(
            find.descendant(of: firstTags, matching: find.text(label)),
            findsOneWidget,
          );
        }
        for (final label in ['1080p', '无码']) {
          expect(
            find.descendant(of: secondTags, matching: find.text(label)),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(of: secondTags, matching: find.text('手工')),
          findsNothing,
        );
        final filenameTooltip = tester.widget<Tooltip>(
          find
              .ancestor(
                of: find.byKey(const Key('test-version-file-1')),
                matching: find.byType(Tooltip),
              )
              .first,
        );
        expect(
          filenameTooltip.message,
          'DEMO-001.uncensored.2160p.HEVC.60fps.10bit.DDP5.1.ReleaseGroup.LongName.mp4',
        );
        for (var round = 0; round < 2; round++) {
          await tester.tap(find.byKey(const Key('test-tab-list')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('test-tab-versions')));
          await tester.pumpAndSettle();
        }
        expect(
          bundle.adapter.hitCount('GET', '/media/multi-version-movies'),
          1,
        );
        expect(find.textContaining('8.0 GB'), findsOneWidget);
        expect(find.text('2 个版本'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('test-version-movie-DEMO-001')));
        expect(opened, 'DEMO-001');
        await tester.tap(find.byKey(const Key('test-version-delete-1')));
        await tester.pumpAndSettle();
        expect(find.textContaining('对应文件'), findsOneWidget);
        expect(find.textContaining('保留 1 个版本'), findsOneWidget);
        await tester.tap(find.byKey(const Key('test-version-delete-cancel-1')));
        await tester.pumpAndSettle();
        expect(bundle.adapter.hitCount('DELETE', '/media/1'), 0);
        bundle.adapter.enqueueJson(
          method: 'DELETE',
          path: '/media/1',
          statusCode: 503,
          body: {
            'error': {'code': 'provider_unavailable', 'message': '存储暂不可用'},
          },
        );
        await tester.tap(find.byKey(const Key('test-version-delete-1')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('test-version-delete-confirm-1')),
        );
        await tester.pumpAndSettle();
        expect(find.text('存储暂不可用'), findsOneWidget);
        expect(
          find.byKey(const Key('test-version-group-DEMO-001')),
          findsOneWidget,
        );
        bundle.adapter.enqueueJson(
          method: 'DELETE',
          path: '/media/1',
          statusCode: 204,
        );
        final pendingDeleteRefresh = Completer<ResponseBody>();
        bundle.adapter.enqueueResponder(
          method: 'GET',
          path: '/media/multi-version-movies',
          responder: (_, __) => pendingDeleteRefresh.future,
        );
        await tester.tap(
          find.byKey(const Key('test-version-delete-confirm-1')),
        );
        final deletedGroup = find.byKey(
          const Key('test-version-group-DEMO-001'),
        );
        for (
          var attempt = 0;
          attempt < 20 && deletedGroup.evaluate().isNotEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(deletedGroup, findsNothing);
        expect(find.byType(AppSkeletonizer), findsNothing);
        expect(find.text('暂无多版本影片'), findsOneWidget);
        expect(find.text('共 0 部'), findsOneWidget);
        pendingDeleteRefresh.complete(_responseBody(_page([])));
        await tester.pumpAndSettle();
        expect(bundle.adapter.hitCount('DELETE', '/media/2'), 0);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  testWidgets(
    'initial failure retries and fixed header remains while versions scroll',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final session = SessionStore.inMemory();
      await session.saveBaseUrl('https://api.example.com');
      await session.saveTokens(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime(2030),
      );
      final bundle = await createTestApiBundle(session);
      addTearDown(() {
        bundle.dispose();
        session.dispose();
      });
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/media',
        body: _page([]),
      );
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/media-libraries',
        body: [],
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        statusCode: 503,
        body: {
          'error': {'message': 'Unavailable'},
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: bundle.riverpodOverrides(),
          child: MaterialApp(
            theme: sakuraMobileThemeData,
            locale: const Locale('zh'),
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
            builder: (_, child) =>
                AppPlatformScope(platform: AppPlatform.mobile, child: child!),
            home: OKToast(
              child: Scaffold(
                body: MediaManagementContent(
                  keyPrefix: 'test',
                  rootKey: const Key('page'),
                  mobile: true,
                  onOpenMovieDetail: (_, __) {},
                  onOpenVideoCollectionDetail: (_, __) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test-tab-versions')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('test-versions-retry')), findsOneWidget);
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: _page([_group(count: 6)]),
      );
      await tester.tap(find.byKey(const Key('test-versions-retry')));
      await tester.pumpAndSettle();
      final header = find.byKey(const Key('test-versions-total'));
      final top = tester.getTopLeft(header);
      final scroll = find.byKey(const Key('test-versions-scroll'));
      await tester.drag(scroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(header), top);
      for (var i = 0; i < 5; i++) {
        await tester.drag(scroll, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      expect(tester.getTopLeft(header), top);
      expect(
        find.byKey(const Key('test-version-delete-6')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final mobile in [false, true]) {
    testWidgets(
      'processed groups ${mobile ? "mobile" : "desktop"}: mark, filter and restore',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = mobile
            ? const Size(360, 760)
            : const Size(1100, 760);
        addTearDown(tester.view.reset);
        final session = SessionStore.inMemory();
        await session.saveBaseUrl('https://api.example.com');
        await session.saveTokens(
          accessToken: 'token',
          refreshToken: 'refresh',
          expiresAt: DateTime(2030),
        );
        final bundle = await createTestApiBundle(session);
        addTearDown(() {
          bundle.dispose();
          session.dispose();
        });
        bundle.adapter.setFallbackJson(
          method: 'GET',
          path: '/media',
          body: _page([]),
        );
        bundle.adapter.setFallbackJson(
          method: 'GET',
          path: '/media-libraries',
          body: [],
        );
        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/media/multi-version-movies',
          body: _page([_group()]),
        );
        await _pumpProcessingPage(tester, bundle, mobile: mobile);

        await tester.tap(find.byKey(const Key('processed-versions-select')));
        await tester.pumpAndSettle();
        final selectFirst = find.byKey(const Key('processed-version-row-1'));
        await tester.ensureVisible(selectFirst);
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getRect(selectFirst).centerRight - const Offset(4, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('已选 1 个'), findsOneWidget);
        expect(
          find.byKey(const Key('processed-version-delete-1')),
          findsNothing,
        );
        final processedButton = find.byKey(
          const Key('processed-version-processed-DEMO-001'),
        );
        expect(processedButton, findsOneWidget);
        await tester.ensureVisible(processedButton);
        await tester.pumpAndSettle();

        bundle.adapter.enqueueJson(
          method: 'PUT',
          path: '/media/multi-version-movies/DEMO-001/processed',
          statusCode: 204,
          body: null,
        );
        await tester.tap(processedButton);
        final groupCard = find.byKey(
          const Key('processed-version-group-DEMO-001'),
        );
        for (
          var attempt = 0;
          attempt < 20 && groupCard.evaluate().isNotEmpty;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(
          bundle.adapter.requests
              .firstWhere((request) => request.method == 'PUT')
              .body,
          {
            'media_ids': [1, 2],
          },
        );
        expect(groupCard, findsNothing);
        expect(find.byType(AppSkeletonizer), findsNothing);
        expect(find.text('已选 0 个'), findsOneWidget);
        expect(find.text('暂无多版本影片'), findsOneWidget);
        expect(
          bundle.adapter.hitCount('GET', '/media/multi-version-movies'),
          1,
        );
        await tester.tap(
          find.byKey(const Key('processed-versions-exit-selection')),
        );
        await tester.pumpAndSettle();
        expect(find.text('共 0 部'), findsOneWidget);

        bundle.adapter.enqueueJson(
          method: 'GET',
          path: '/media/multi-version-movies',
          body: _page([_group(isProcessed: true)]),
        );
        await tester.tap(find.byKey(const Key('processed-versions-filter')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('processed-versions-include-processed')),
        );
        await tester.pumpAndSettle();
        expect(find.text('已处理'), findsOneWidget);
        expect(find.text('恢复待处理'), findsOneWidget);
        if (mobile) {
          Navigator.of(tester.element(find.text('重置'))).pop();
        } else {
          await tester.tapAt(const Offset(1000, 700));
        }
        await tester.pumpAndSettle();
        final request = bundle.adapter.requests
            .where(
              (request) =>
                  request.path == '/media/multi-version-movies' &&
                  request.uri.queryParameters['include_processed'] == 'true',
            )
            .single;
        expect(request.uri.queryParameters['page'], '1');

        await tester.tap(find.byKey(const Key('processed-versions-select')));
        await tester.pumpAndSettle();
        final selectProcessed = find.byKey(
          const Key('processed-version-row-1'),
        );
        await tester.ensureVisible(selectProcessed);
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getRect(selectProcessed).centerRight - const Offset(4, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('已选 1 个'), findsOneWidget);
        expect(
          find.byKey(const Key('processed-version-delete-1')),
          findsNothing,
        );
        final pendingButton = find.byKey(
          const Key('processed-version-processed-DEMO-001'),
        );
        expect(pendingButton, findsOneWidget);
        await tester.ensureVisible(pendingButton);
        await tester.pumpAndSettle();

        bundle.adapter.enqueueJson(
          method: 'DELETE',
          path: '/media/multi-version-movies/DEMO-001/processed',
          statusCode: 204,
          body: null,
        );
        final getCount = bundle.adapter.hitCount(
          'GET',
          '/media/multi-version-movies',
        );
        await tester.tap(pendingButton);
        await tester.pumpAndSettle();
        expect(find.text('已处理'), findsNothing);
        expect(find.text('标记已处理'), findsOneWidget);
        expect(find.text('已选 1 个'), findsOneWidget);
        expect(
          bundle.adapter.hitCount('GET', '/media/multi-version-movies'),
          getCount,
        );
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 3));
      },
    );
  }

  for (final mobile in [false, true]) {
    testWidgets('mark keeps scroll offset ${mobile ? "mobile" : "desktop"}', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = mobile
          ? const Size(360, 760)
          : const Size(1100, 760);
      addTearDown(tester.view.reset);
      final session = SessionStore.inMemory();
      await session.saveBaseUrl('https://api.example.com');
      await session.saveTokens(
        accessToken: 'token',
        refreshToken: 'refresh',
        expiresAt: DateTime(2030),
      );
      final bundle = await createTestApiBundle(session);
      addTearDown(() {
        bundle.dispose();
        session.dispose();
      });
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/media',
        body: _page([]),
      );
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/media-libraries',
        body: [],
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/multi-version-movies',
        body: _page([
          for (var index = 1; index <= 6; index++)
            _group(
              movieNumber: 'DEMO-00$index',
              firstMediaId: (index - 1) * 2 + 1,
            ),
        ]),
      );
      await _pumpProcessingPage(tester, bundle, mobile: mobile);

      final scroll = find.byKey(const Key('processed-versions-scroll'));
      final controller = tester.widget<CustomScrollView>(scroll).controller!;
      expect(controller.position.maxScrollExtent, greaterThan(0));
      controller.jumpTo(controller.position.maxScrollExtent * 0.4);
      await tester.pumpAndSettle();
      final targetGroup = find.byKey(
        const Key('processed-version-group-DEMO-003'),
      );
      expect(targetGroup, findsOneWidget);
      await tester.ensureVisible(targetGroup);
      await tester.pumpAndSettle();
      final markButton = find.byKey(
        const Key('processed-version-processed-DEMO-003'),
      );
      await tester.ensureVisible(markButton);
      await tester.pumpAndSettle();
      final offsetBefore = controller.offset;
      expect(offsetBefore, greaterThan(0));

      bundle.adapter.enqueueJson(
        method: 'PUT',
        path: '/media/multi-version-movies/DEMO-003/processed',
        statusCode: 204,
        body: null,
      );
      await tester.tap(markButton);
      await tester.pumpAndSettle();

      expect(controller.offset, closeTo(offsetBefore, 0.1));
      expect(targetGroup, findsNothing);
      expect(bundle.adapter.hitCount('GET', '/media/multi-version-movies'), 1);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('stale processed mark refreshes and shows the conflict message', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 760);
    addTearDown(tester.view.reset);
    final session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    await session.saveTokens(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime(2030),
    );
    final bundle = await createTestApiBundle(session);
    addTearDown(() {
      bundle.dispose();
      session.dispose();
    });
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/media',
      body: _page([]),
    );
    bundle.adapter.setFallbackJson(
      method: 'GET',
      path: '/media-libraries',
      body: [],
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/multi-version-movies',
      body: _page([_group()]),
    );
    await _pumpProcessingPage(tester, bundle, mobile: false);
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/media/multi-version-movies/DEMO-001/processed',
      statusCode: 409,
      body: {
        'error': {'code': 'multi_version_changed', 'message': '影片版本已变化，请刷新后重试'},
      },
    );
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/media/multi-version-movies',
      body: _page([_group(count: 3)]),
    );
    await tester.tap(
      find.byKey(const Key('processed-version-processed-DEMO-001')),
    );
    await tester.pumpAndSettle();
    expect(find.text('影片版本已变化，请刷新后重试'), findsOneWidget);
    expect(bundle.adapter.hitCount('GET', '/media/multi-version-movies'), 2);
    expect(find.text('3 个版本'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpProcessingPage(
  WidgetTester tester,
  TestApiBundle bundle, {
  required bool mobile,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: bundle.riverpodOverrides(),
      child: MaterialApp(
        theme: mobile ? sakuraMobileThemeData : sakuraThemeData,
        locale: const Locale('zh'),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
        builder: (_, child) => AppPlatformScope(
          platform: mobile ? AppPlatform.mobile : AppPlatform.desktop,
          child: child!,
        ),
        home: OKToast(
          child: Scaffold(
            body: MediaManagementContent(
              keyPrefix: 'processed',
              rootKey: const Key('processed-page'),
              mobile: mobile,
              onOpenMovieDetail: (_, __) {},
              onOpenVideoCollectionDetail: (_, __) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('processed-tab-versions')));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _page(List<dynamic> items) => {
  'items': items,
  'total': items.length,
  'page': 1,
  'page_size': 20,
};
Map<String, dynamic> _group({
  int count = 2,
  bool isProcessed = false,
  String movieNumber = 'DEMO-001',
  int firstMediaId = 1,
}) => {
  'movie_number': movieNumber,
  'media_count': count,
  'is_processed': isProcessed,
  'media_items': List.generate(
    count,
    (i) => {
      'id': firstMediaId + i,
      'kind': 'jav',
      'movie_number': movieNumber,
      'title': '用于展示的影片名称',
      'library_id': 1,
      'file_name': i == 0
          ? '$movieNumber.uncensored.2160p.HEVC.60fps.10bit.DDP5.1.ReleaseGroup.LongName.mp4'
          : '$movieNumber.2.1080p.mp4',
      'file_size_bytes': i == 0 ? 8589934592 : 3221225472,
      'duration_seconds': 7200,
      'resolution': i == 0 ? '2160p' : '1080p',
      'valid': i != 1,
      'tags': i == 0
          ? [
              {'id': 11, 'name': '4K'},
              {'id': 12, 'name': '中文字幕'},
              {'id': 13, 'name': '60fps'},
              {'id': 14, 'name': '10bit'},
              {'id': 15, 'name': 'DDP5.1'},
              {'id': 16, 'name': 'LongTag6'},
            ]
          : [
              {'id': 21, 'name': '1080p'},
              {'id': 22, 'name': '无码'},
            ],
      'is_media_tags_manually_managed': i == 0,
    },
  ),
};

ResponseBody _responseBody(Map<String, dynamic> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
