import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/widgets/task_run_history_sheet.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-12-31T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
    sessionStore.dispose();
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: <LocalizationsDelegate<dynamic>>[
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const <Locale>[Locale('zh'), Locale('en')],
          theme: sakuraDesktopThemeData,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(24),
              child: TaskRunHistorySheet(
                taskKey: 'media_import',
                taskName: '媒体导入',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when the task has no runs', (
    tester,
  ) async {
    _enqueuePage(bundle, page: 1, ids: const <int>[], total: 0);
    await pumpSheet(tester);

    expect(find.byKey(const Key('activity-history-empty')), findsOneWidget);
    expect(find.byKey(const Key('activity-history-list')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the error state and retries', (tester) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/system/task-runs',
      statusCode: 500,
      body: const <String, dynamic>{'detail': 'boom'},
    );
    await pumpSheet(tester);

    expect(find.byKey(const Key('activity-history-error')), findsOneWidget);

    _enqueuePage(bundle, page: 1, ids: const <int>[7], total: 1);
    await tester.tap(find.byKey(const Key('activity-history-retry-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-task-7')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paginates all runs for one task', (tester) async {
    _enqueuePage(
      bundle,
      page: 1,
      ids: <int>[for (var id = 40; id > 20; id--) id],
      total: 21,
    );
    await pumpSheet(tester);

    expect(find.byKey(const Key('activity-history-list')), findsOneWidget);
    expect(find.byKey(const Key('activity-task-40')), findsOneWidget);
    expect(bundle.adapter.requests.last.uri.queryParameters['page'], '1');

    _enqueuePage(bundle, page: 2, ids: const <int>[20], total: 21);
    final list = find.byKey(const Key('activity-history-list'));
    await tester.drag(list, const Offset(0, -4000));
    await tester.pumpAndSettle();

    final pageTwo = bundle.adapter.requests.lastWhere(
      (request) =>
          request.path == '/system/task-runs' &&
          request.uri.queryParameters['page'] == '2',
    );
    expect(pageTwo.uri.queryParameters['task_key'], 'media_import');
    expect(pageTwo.uri.queryParameters['scope'], 'all');

    await tester.scrollUntilVisible(
      find.byKey(const Key('activity-task-20')),
      200,
      scrollable: find.descendant(of: list, matching: find.byType(Scrollable)),
    );
    expect(find.byKey(const Key('activity-task-20')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _enqueuePage(
  TestApiBundle bundle, {
  required int page,
  required List<int> ids,
  required int total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/task-runs',
    body: <String, dynamic>{
      'items': <Map<String, dynamic>>[
        for (final id in ids) _taskRunJson(id: id),
      ],
      'page': page,
      'page_size': 20,
      'total': total,
    },
  );
}

Map<String, dynamic> _taskRunJson({required int id}) => <String, dynamic>{
  'id': id,
  'task_key': 'media_import',
  'task_name': '媒体导入',
  'trigger_type': 'scheduled',
  'state': 'completed',
  'created_at': '2026-03-26T09:10:00Z',
  'updated_at': '2026-03-26T09:11:00Z',
};
