import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/pages/desktop/notifications_page.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/test_api_bundle.dart';

void main() {
  testWidgets('renders notification snapshot without event stream', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionStore = await _sessionStore();
    final bundle = await createTestApiBundle(sessionStore);
    addTearDown(bundle.dispose);
    addTearDown(sessionStore.dispose);
    _enqueueBootstrap(bundle);

    await tester.pumpWidget(
      ProviderScope(
        overrides: bundle.riverpodOverrides(),
        child: MaterialApp(
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopNotificationsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('desktop-notifications-page')), findsOneWidget);
    expect(find.byKey(const Key('activity-notification-101')), findsOneWidget);
    expect(find.text('提醒通知'), findsOneWidget);
    expect(
      bundle.adapter.requests.where(
        (request) => request.path.contains('/system/events/'),
      ),
      isEmpty,
    );
  });
}

Future<SessionStore> _sessionStore() async {
  final store = SessionStore.inMemory();
  await store.saveBaseUrl('https://api.example.com');
  await store.saveTokens(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
  );
  return store;
}

void _enqueueBootstrap(TestApiBundle bundle) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: <String, dynamic>{
      'notifications': <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 101,
            'category': 'reminder',
            'title': '提醒通知',
            'content': '内容',
            'is_read': true,
            'created_at': '2026-08-10T09:00:00Z',
            'updated_at': '2026-08-10T09:00:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
      'unread_count': 0,
      'active_task_runs': const <dynamic>[],
      'task_runs': <String, dynamic>{
        'items': const <dynamic>[],
        'page': 1,
        'page_size': 20,
        'total': 0,
      },
    },
  );
}
