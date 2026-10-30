import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/media/presentation/pages/shared/media_management_content.dart';
import 'package:sakuramedia/features/media/presentation/providers/duplicate_media_provider.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import '../../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore session;
  late TestApiBundle bundle;
  setUp(() async {
    session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    await session.saveTokens(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime(2030),
    );
    bundle = await createTestApiBundle(session);
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
      path: '/media/duplicates',
      body: _page([
        _group('A-001', [1, 2, 3]),
        _group('B-001', [4, 5, 6]),
      ]),
    );
  });
  tearDown(() {
    bundle.dispose();
    session.dispose();
  });

  for (final mobile in [false, true]) {
    testWidgets('duplicate filters $mobile: switch, reopen and reset', (
      tester,
    ) async {
      await _pump(tester, bundle, mobile: mobile);
      bundle.adapter.setFallbackJson(
        method: 'GET',
        path: '/media/duplicates',
        body: _page([]),
      );
      Future<void> closeFilter() async {
        if (mobile) {
          Navigator.of(tester.element(find.text('重置'))).pop();
        } else {
          await tester.tapAt(const Offset(1000, 700));
        }
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('batch-duplicates-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('batch-duplicate-kind-video')));
      await tester.pumpAndSettle();
      expect(
        bundle.adapter.requests
            .where((r) => r.path == '/media/duplicates')
            .map((r) => r.uri.queryParameters['kind']),
        ['jav', 'video'],
      );
      expect(
        tester
            .widget<AppTextButton>(
              find.byKey(const Key('batch-duplicate-kind-video')),
            )
            .isSelected,
        isTrue,
      );
      await closeFilter();
      await tester.tap(find.byKey(const Key('batch-duplicates-filter')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppTextButton>(
              find.byKey(const Key('batch-duplicate-kind-video')),
            )
            .isSelected,
        isTrue,
      );
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppTextButton>(
              find.byKey(const Key('batch-duplicate-kind-jav')),
            )
            .isSelected,
        isTrue,
      );
      await closeFilter();
      expect(find.text('共 2 组'), findsOneWidget);
      expect(bundle.adapter.hitCount('DELETE', '/media/1'), 0);
      expect(tester.takeException(), isNull);
    });
    testWidgets('duplicate ${mobile ? "mobile" : "desktop"}: show media tags', (
      tester,
    ) async {
      await _pump(tester, bundle, mobile: mobile);
      final firstTags = find.byKey(const Key('batch-duplicate-media-tags-1'));
      expect(firstTags, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(firstTags).scrollDirection,
        Axis.horizontal,
      );
      for (final label in ['手工', '4K', '中文字幕']) {
        expect(
          find.descendant(of: firstTags, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const Key('batch-duplicate-media-tags-2')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'batch ${mobile ? "mobile" : "desktop"}: keep one and submit backend task',
      (tester) async {
        await _pump(tester, bundle, mobile: mobile);
        await tester.tap(find.byKey(const Key('batch-duplicates-select')));
        await tester.pumpAndSettle();
        expect(find.text('已选 0 个'), findsOneWidget);
        await _select(tester, 1);
        await _select(tester, 2);
        expect(
          tester
              .widget<Checkbox>(
                find.byKey(const Key('batch-duplicate-select-3')),
              )
              .onChanged,
          isNull,
        );
        await tester.tapAt(
          tester.getCenter(find.byKey(const Key('batch-duplicate-row-3'))),
        );
        await tester.pumpAndSettle();
        expect(find.text('已选 2 个'), findsOneWidget);
        await tester.tapAt(
          tester.getCenter(find.byKey(const Key('batch-duplicate-file-1'))),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Checkbox>(
                find.byKey(const Key('batch-duplicate-select-3')),
              )
              .onChanged,
          isNotNull,
        );
        await _select(tester, 1);
        await _select(tester, 4);
        expect(find.text('已选 3 个'), findsOneWidget);
        bundle.adapter.enqueueJson(
          method: 'POST',
          path: '/batch-operations',
          statusCode: 202,
          body: {
            'task_run_id': 7,
            'task_key': 'batch_operation',
            'state': 'pending',
          },
        );
        await tester.tap(
          find.byKey(const Key('batch-duplicates-batch-delete')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('将删除选中的 3 项媒体'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('batch-duplicates-batch-confirm')),
        );
        await tester.pumpAndSettle();

        final submit = bundle.adapter.requests
            .where((request) => request.path == '/batch-operations')
            .toList();
        expect(submit, hasLength(1));
        expect(submit.single.body, {
          'operation': 'media_delete',
          'ids': [1, 2, 4],
          'delete_files': false,
        });
        expect(find.textContaining('已提交批量删除媒体'), findsOneWidget);
        // 提交后前端不再逐条 DELETE；列表由任务完成后手动刷新。
        for (final id in [1, 2, 3, 4, 5, 6]) {
          expect(bundle.adapter.hitCount('DELETE', '/media/$id'), 0);
        }
        expect(bundle.adapter.hitCount('GET', '/media/duplicates'), 1);
        expect(find.text('已选 0 个'), findsNothing);
        expect(
          find.byKey(const Key('batch-duplicates-select')),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 3));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'clear and cancel selection send no batch operation; changed groups abort confirmation',
    (tester) async {
      await _pump(tester, bundle, mobile: false);
      await tester.tap(find.byKey(const Key('batch-duplicates-select')));
      await tester.pumpAndSettle();
      await _select(tester, 1);
      await tester.tap(
        find.byKey(const Key('batch-duplicates-clear-selection')),
      );
      await tester.pumpAndSettle();
      expect(find.text('已选 0 个'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('batch-duplicates-exit-selection')),
      );
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('POST', '/batch-operations'), 0);
      await tester.tap(find.byKey(const Key('batch-duplicates-select')));
      await tester.pumpAndSettle();
      await _select(tester, 1);
      await tester.tap(find.byKey(const Key('batch-duplicates-batch-delete')));
      await tester.pumpAndSettle();
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/media/duplicates',
        body: _page([
          _group('B-001', [4, 5, 6]),
        ]),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MediaManagementContent)),
      );
      final refresh = container
          .read(duplicateMediaProvider(MediaListItemKind.jav).notifier)
          .refresh();
      await tester.pumpAndSettle();
      await refresh;
      await tester.tap(find.byKey(const Key('batch-duplicates-batch-confirm')));
      await tester.pumpAndSettle();
      expect(bundle.adapter.hitCount('POST', '/batch-operations'), 0);
      expect(find.text('重复媒体已变化，请重新选择，至少保留一个副本'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );
}

Future<void> _pump(
  WidgetTester tester,
  TestApiBundle bundle, {
  required bool mobile,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = mobile
      ? const Size(360, 760)
      : const Size(1100, 760);
  addTearDown(tester.view.reset);
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
              keyPrefix: 'batch',
              rootKey: const Key('page'),
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
  await tester.tap(find.byKey(const Key('batch-tab-duplicates')));
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, int id) async {
  final target = find.byKey(Key('batch-duplicate-row-$id'));
  for (var i = 0; i < 15 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(
      find.byKey(const Key('batch-duplicate-scroll-view')),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
  }
  await tester.tapAt(tester.getRect(target).centerRight - const Offset(4, 0));
  await tester.pumpAndSettle();
}

Map<String, dynamic> _page(List<dynamic> items) => {
  'items': items,
  'total': items.length,
  'page': 1,
  'page_size': 20,
};
Map<String, dynamic> _group(String number, List<int> ids) => {
  'kind': 'jav',
  'media_count': ids.length,
  'media_items': ids
      .map(
        (id) => {
          'id': id,
          'kind': 'jav',
          'movie_number': number,
          'title': '影片标题',
          'file_name': '$number.$id.mp4',
          'valid': true,
          'tags': switch (id) {
            1 => [
              {'id': 11, 'name': '4K'},
              {'id': 12, 'name': '中文字幕'},
            ],
            3 => [
              {'id': 13, 'name': '60fps'},
            ],
            _ => [],
          },
          'is_media_tags_manually_managed': id == 1,
        },
      )
      .toList(),
};
