import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_provider.dart';
import 'package:sakuramedia/features/activity/presentation/providers/notification_center_state.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore sessionStore;
  late TestApiBundle bundle;
  late ProviderContainer container;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    bundle = await createTestApiBundle(sessionStore);
    container = ProviderContainer(
      overrides: bundle.riverpodOverrides(),
      retry: (_, _) => null,
    );
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
    sessionStore.dispose();
  });

  test('reloadAll loads notifications and uses polling state', () async {
    _enqueueBootstrap(bundle, notificationId: 5, unreadCount: 2);

    await container.read(notificationCenterProvider.notifier).reloadAll();

    final state = container.read(notificationCenterProvider);
    expect(state.initialized, isTrue);
    expect(state.connectionState, NotificationConnectionState.polling);
    expect(state.notifications.single.id, 5);
    expect(state.unreadCount, 2);
    expect(
      bundle.adapter.requests.where(
        (request) => request.path.contains('/system/events/'),
      ),
      isEmpty,
    );
  });

  test('markAllRead uses notification mutation endpoint', () async {
    _enqueueBootstrap(bundle, notificationId: 5, unreadCount: 1);
    await container.read(notificationCenterProvider.notifier).reloadAll();
    bundle.adapter.enqueueJson(
      method: 'POST',
      path: '/system/notifications/read-all',
      body: <String, dynamic>{'updated_count': 1, 'unread_count': 0},
    );

    await container.read(notificationCenterProvider.notifier).markAllRead();

    expect(container.read(notificationCenterProvider).unreadCount, 0);
    expect(bundle.adapter.requests.last.path, '/system/notifications/read-all');
  });
}

void _enqueueBootstrap(
  TestApiBundle bundle, {
  required int notificationId,
  required int unreadCount,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: <String, dynamic>{
      'notifications': <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': notificationId,
            'category': 'reminder',
            'title': '通知',
            'content': '内容',
            'is_read': false,
            'created_at': '2026-03-26T09:10:00Z',
            'updated_at': '2026-03-26T09:10:00Z',
          },
        ],
        'page': 1,
        'page_size': 20,
        'total': 1,
      },
      'unread_count': unreadCount,
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
