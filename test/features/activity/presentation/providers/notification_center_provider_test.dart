import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/language/app_language.dart';
import 'package:sakuramedia/app/language/providers/language_providers.dart';
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

  test(
    'switching the language keeps the loaded notification snapshot',
    () async {
      _enqueueBootstrap(bundle, notificationId: 5, unreadCount: 2);

      await container.read(notificationCenterProvider.notifier).reloadAll();
      expect(container.read(notificationCenterProvider).initialized, isTrue);
      expect(
        container.read(notificationCenterProvider).notifications,
        hasLength(1),
      );
      final bootstrapCalls = bundle.adapter.requests
          .where((request) => request.path.contains('/system/activity/bootstrap'))
          .length;

      await container
          .read(appLanguageControllerProvider.notifier)
          .setLanguage(AppLanguage.en);

      // 通知标题/正文是写入时快照，不随界面语言重拉：provider 不重建、
      // 不再发请求，已读列表保持原样。
      expect(container.read(notificationCenterProvider).initialized, isTrue);
      expect(
        container.read(notificationCenterProvider).notifications,
        hasLength(1),
      );
      expect(
        bundle.adapter.requests
            .where((request) => request.path.contains('/system/activity/bootstrap'))
            .length,
        bootstrapCalls,
      );
    },
  );

  test('markAllRead uses notification mutation endpoint', () async {
    _enqueueBootstrap(bundle, notificationId: 5, unreadCount: 1);
    await container.read(notificationCenterProvider.notifier).reloadAll();
    bundle.adapter.enqueueJson(
      method: 'PATCH',
      path: '/system/notifications',
      body: <String, dynamic>{'updated_count': 1, 'unread_count': 0},
    );

    await container.read(notificationCenterProvider.notifier).markAllRead();

    expect(container.read(notificationCenterProvider).unreadCount, 0);
    expect(bundle.adapter.requests.last.path, '/system/notifications');
  });

  test('已读回执失败后抑制自动重试，主动刷新恢复', () {
    fakeAsync((async) {
      void settle() {
        async.elapse(Duration.zero);
        async.flushMicrotasks();
      }

      final controller = container.read(notificationCenterProvider.notifier);
      _enqueueBootstrap(bundle, notificationId: 5, unreadCount: 1);
      controller.reloadAll();
      settle();

      // 已读回执失败：本地回滚为未读。
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/system/notifications',
        statusCode: 500,
        body: <String, dynamic>{'error': 'server_error'},
      );
      controller.onNotificationDisplayed(5);
      async.elapse(const Duration(milliseconds: 500));
      settle();
      expect(bundle.adapter.hitCount('PATCH', '/system/notifications'), 1);
      expect(
        container.read(notificationCenterProvider).notifications.single.isRead,
        isFalse,
      );

      // 行重建再次触发上报：失败已被抑制，不再形成无退避重试。
      controller.onNotificationDisplayed(5);
      async.elapse(const Duration(milliseconds: 500));
      settle();
      expect(bundle.adapter.hitCount('PATCH', '/system/notifications'), 1);

      // 用户主动刷新后清除抑制，重新给一次机会。
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/notifications',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[_notificationJson(id: 5)],
          'page': 1,
          'page_size': 20,
          'total': 1,
        },
      );
      controller.refreshNotifications();
      settle();
      bundle.adapter.enqueueJson(
        method: 'PATCH',
        path: '/system/notifications',
        body: <String, dynamic>{'updated_count': 1, 'unread_count': 0},
      );
      controller.onNotificationDisplayed(5);
      async.elapse(const Duration(milliseconds: 500));
      settle();
      expect(bundle.adapter.hitCount('PATCH', '/system/notifications'), 2);
      expect(
        container.read(notificationCenterProvider).notifications.single.isRead,
        isTrue,
      );
    });
  });

  test('poll keeps loaded pages and patches notifications in place', () {
    fakeAsync((async) {
      void settle() {
        async.elapse(Duration.zero);
        async.flushMicrotasks();
      }

      final controller = container.read(notificationCenterProvider.notifier);
      final firstPage = <Map<String, dynamic>>[
        for (var id = 1; id <= 20; id++) _notificationJson(id: id),
      ];
      final secondPage = <Map<String, dynamic>>[
        for (var id = 21; id <= 40; id++) _notificationJson(id: id),
      ];

      _enqueueBootstrapItems(bundle, items: firstPage, total: 40);
      controller.reloadAll();
      settle();
      expect(
        container.read(notificationCenterProvider).notifications,
        hasLength(20),
      );

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/notifications',
        body: <String, dynamic>{
          'items': secondPage,
          'page': 2,
          'page_size': 20,
          'total': 40,
        },
      );
      controller.loadMoreNotifications();
      settle();
      var state = container.read(notificationCenterProvider);
      expect(state.notifications, hasLength(40));
      expect(state.hasMore, isFalse);

      // 轮询首页快照（id 1 标题变化）+ 未读数查询。
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/notifications',
        body: <String, dynamic>{
          'items': <Map<String, dynamic>>[
            for (var id = 1; id <= 20; id++)
              _notificationJson(id: id, title: id == 1 ? '更新' : '通知'),
          ],
          'page': 1,
          'page_size': 20,
          'total': 40,
        },
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/system/notifications',
        body: <String, dynamic>{
          'items': const <dynamic>[],
          'page': 1,
          'page_size': 1,
          'total': 0,
        },
      );

      async.elapse(const Duration(seconds: 31));
      settle();

      state = container.read(notificationCenterProvider);
      expect(state.notifications, hasLength(40));
      expect(
        state.notifications.map((item) => item.id).toSet(),
        <int>{for (var id = 1; id <= 40; id++) id},
      );
      expect(state.hasMore, isFalse);
      expect(
        state.notifications.firstWhere((item) => item.id == 1).title,
        '更新',
      );
    });
  });
}

Map<String, dynamic> _notificationJson({required int id, String title = '通知'}) =>
    <String, dynamic>{
      'id': id,
      'category': 'reminder',
      'title': title,
      'content': '内容',
      'is_read': false,
      'created_at': '2026-03-26T09:10:00Z',
      'updated_at': '2026-03-26T09:10:00Z',
    };

void _enqueueBootstrapItems(
  TestApiBundle bundle, {
  required List<Map<String, dynamic>> items,
  required int total,
}) {
  bundle.adapter.enqueueJson(
    method: 'GET',
    path: '/system/activity/bootstrap',
    body: <String, dynamic>{
      'notifications': <String, dynamic>{
        'items': items,
        'page': 1,
        'page_size': 20,
        'total': total,
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
