import 'package:sakuramedia/features/downloads/data/downloads_api.dart';
import 'package:sakuramedia/features/downloads/presentation/providers/downloads_api_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/subscriptions/data/api/movie_subscriptions_api.dart';
import 'package:sakuramedia/features/subscriptions/presentation/pages/desktop/movie_subscriptions_page.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscriptions_api_provider.dart';
import 'package:sakuramedia/theme.dart';

import '../../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-08-10T12:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    adapter = FakeHttpClientAdapter();
    adapter.setFallbackJson(method: 'GET', path: '/download-tasks',
      body: {'items': [], 'total': 0, 'page': 1, 'page_size': 100});
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
    adapter.setFallbackJson(
      method: 'GET',
      path: '/movie-subscriptions/status-counts',
      body: <String, dynamic>{'total': 1, 'missing': 1},
    );
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  testWidgets('renders subscription rows without import-operation actions', (
    tester,
  ) async {
    _enqueuePage(adapter, [_item('ABP-123')]);
    await _pumpPage(tester, sessionStore, apiClient);

    expect(
      find.byKey(const Key('desktop-movie-subscriptions-page')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('movie-subscription-row-number-ABP-123')),
      findsOneWidget,
    );
    expect(find.text('缺资源'), findsWidgets);
    expect(
      find.byKey(const Key('movie-subscription-row-downloads')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('movie-subscription-row-open-import-ABP-123')),
      findsNothing,
    );
  });

  testWidgets('shows import hint for an unimported subscription', (tester) async {
    final item = _item('ABP-123')
      ..['status'] = 'import_failed'
      ..['import_status_label'] = '已跳过：没有符合条件的媒体文件';
    _enqueuePage(adapter, [item]);
    await _pumpPage(tester, sessionStore, apiClient);

    expect(
      find.byKey(const Key('movie-subscription-row-import-hint-ABP-123')),
      findsOneWidget,
    );
    expect(find.text('提示：已跳过：没有符合条件的媒体文件'), findsOneWidget);
  });

  testWidgets(
    'tabs retain loaded pages and scroll until explicitly refreshed',
    (tester) async {
      _enqueuePage(
        adapter,
        List.generate(20, (i) => _item('ABP-${100 + i}')),
        total: 41,
      );
      _enqueuePage(
        adapter,
        List.generate(20, (i) => _item('ABP-${120 + i}')),
        page: 2,
        total: 41,
      );
      await _pumpPage(tester, sessionStore, apiClient);
      final scroll = find.byType(CustomScrollView);
      final header = find.byKey(const Key('movie-subscriptions-list-header'));
      final headerPosition = tester.getTopLeft(header);
      for (var i = 0; i < 5; i++) {
        await tester.drag(scroll, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(_listRequests(adapter).map((r) => r.uri.queryParameters['page']), [
        '1',
        '2',
      ]);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)),
          )
          .position;
      final savedOffset = position.pixels;
      expect(savedOffset, greaterThan(0));
      expect(tester.getTopLeft(header), headerPosition);
      _enqueuePage(adapter, [_item('ABP-200')]);
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-exhausted')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABP-200'), findsOneWidget);
      expect(
        _listRequests(adapter).last.uri.queryParameters['status'],
        'exhausted',
      );
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-missing')),
      );
      await tester.pumpAndSettle();
      final restored = tester
          .state<ScrollableState>(
            find.descendant(of: scroll, matching: find.byType(Scrollable)),
          )
          .position;
      expect(restored.pixels, closeTo(savedOffset, 0.01));
      expect(_listRequests(adapter).length, 3);
      _enqueuePage(adapter, [_item('ABP-140')], page: 3, total: 41);
      for (var i = 0; i < 7; i++) {
        await tester.drag(scroll, const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(find.text('ABP-140'), findsOneWidget);
      expect(_listRequests(adapter).last.uri.queryParameters['page'], '3');
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-exhausted')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABP-200'), findsOneWidget);
      expect(_listRequests(adapter).length, 4);
      _enqueuePage(adapter, [_item('ABP-201')]);
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-refresh-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABP-201'), findsOneWidget);
      expect(_listRequests(adapter).length, 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching away from a pending first page keeps its request and result',
    (tester) async {
      _enqueuePage(adapter, [_item('ABP-100')]);
      await _pumpPage(tester, sessionStore, apiClient);
      final response = Completer<ResponseBody>();
      adapter.enqueueResponder(
        method: 'GET',
        path: '/movie-subscriptions',
        responder: (_, __) => response.future,
      );
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-exhausted')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ABP-100'), findsNothing);
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-missing')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABP-100'), findsOneWidget);
      response.complete(
        ResponseBody.fromString(
          jsonEncode({
            'items': [_item('ABP-200')],
            'page': 1,
            'page_size': 20,
            'total': 1,
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABP-100'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-exhausted')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABP-200'), findsOneWidget);
      expect(_listRequests(adapter).length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty and failed tabs are retained and retry loads only the selected tab',
    (tester) async {
      _enqueuePage(adapter, []);
      await _pumpPage(tester, sessionStore, apiClient);
      adapter.enqueueJson(
        method: 'GET',
        path: '/movie-subscriptions',
        statusCode: 500,
      );
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-exhausted')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-subscriptions-initial-retry-button')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-missing')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('movie-subscriptions-empty-state')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-exhausted')),
      );
      await tester.pumpAndSettle();
      expect(_listRequests(adapter).length, 2);
      _enqueuePage(adapter, [_item('ABP-200')]);
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-initial-retry-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABP-200'), findsOneWidget);
      expect(_listRequests(adapter).length, 3);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fail in [false, true]) {
    testWidgets('tab retains pending next page and result with failure=$fail', (
      tester,
    ) async {
      _enqueuePage(
        adapter,
        List.generate(20, (i) => _item('ABP-${100 + i}')),
        total: 21,
      );
      await _pumpPage(tester, sessionStore, apiClient);
      final response = Completer<ResponseBody>();
      adapter.enqueueResponder(
        method: 'GET',
        path: '/movie-subscriptions',
        responder: (_, __) => response.future,
      );
      for (var i = 0; i < 8 && _listRequests(adapter).length == 1; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(_listRequests(adapter).length, 2);
      _enqueuePage(adapter, [_item('ABP-200')]);
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-exhausted')),
      );
      await tester.pumpAndSettle();
      response.complete(
        ResponseBody.fromString(
          jsonEncode({
            'items': [_item('ABP-120')],
            'page': 2,
            'page_size': 20,
            'total': 21,
          }),
          fail ? 500 : 200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABP-200'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('movie-subscriptions-status-tab-missing')),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
      }
      expect(_listRequests(adapter).length, 3);
      if (fail) {
        expect(find.text('重试'), findsOneWidget);
        _enqueuePage(adapter, [_item('ABP-120')], page: 2, total: 21);
        await tester.tap(find.text('重试'));
        await tester.pumpAndSettle();
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(_listRequests(adapter).length, 4);
        expect(_listRequests(adapter).last.uri.queryParameters['page'], '2');
      }
      expect(find.text('ABP-120'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('unsubscribed rows disappear from a previously visited tab', (
    tester,
  ) async {
    _enqueuePage(adapter, [_item('ABP-100')]);
    await _pumpPage(tester, sessionStore, apiClient);
    _enqueuePage(adapter, [_item('ABP-100')]);
    await tester.tap(
      find.byKey(const Key('movie-subscriptions-status-tab-all')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-subscriptions-status-tab-missing')),
    );
    await tester.pumpAndSettle();
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/ABP-100/subscription',
      statusCode: 204,
    );
    await tester.tap(
      find.byKey(const Key('movie-subscription-row-unsubscribe')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('movie-subscriptions-status-tab-all')),
    );
    await tester.pumpAndSettle();
    expect(find.text('ABP-100'), findsNothing);
    expect(
      find.byKey(const Key('movie-subscriptions-empty-state')),
      findsOneWidget,
    );
    expect(_listRequests(adapter).length, 2);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('search during first tab load keeps the selected status', (tester) async {
    _enqueuePage(adapter, [_item('ABP-100')]);
    await _pumpPage(tester, sessionStore, apiClient);
    final response = Completer<ResponseBody>();
    adapter.enqueueResponder(
      method: 'GET', path: '/movie-subscriptions',
      responder: (_, __) => response.future,
    );
    await tester.tap(find.byKey(const Key('movie-subscriptions-status-tab-exhausted')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('movie-subscriptions-filter-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final search = find.byKey(const Key('movie-subscriptions-filter-search-field'));
    await tester.enterText(search, 'ABP');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    response.complete(ResponseBody.fromString(
      '{"items":[],"page":1,"page_size":20,"total":0}', 200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    ));
    _enqueuePage(adapter, [_item('ABP-200')]);
    await tester.pumpAndSettle();
    expect(_listRequests(adapter).last.uri.queryParameters['status'], 'exhausted');
    expect(_listRequests(adapter).last.uri.queryParameters['search'], 'ABP');
    expect(tester.takeException(), isNull);
  });

  testWidgets('unsubscribe removes the row', (tester) async {
    _enqueuePage(adapter, [_item('ABP-123'), _item('ABP-124')]);
    await _pumpPage(tester, sessionStore, apiClient);
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/movies/ABP-123/subscription',
      statusCode: 204,
    );

    await tester.tap(
      find.byKey(const Key('movie-subscription-row-unsubscribe')).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('movie-subscription-row-number-ABP-123')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('movie-subscription-row-number-ABP-124')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
  });
  testWidgets('download delete button uses actual tasks and exact movie match', (tester) async {
    _enqueuePage(adapter, [_item('ABP-123'), _item('ABP-124')]);
    adapter.setFallbackJson(method: 'GET', path: '/download-tasks', body: {
      'items': [
        {'id': 41, 'movie_number': 'ABP-123', 'name': 'ABP-123 task', 'state': 'completed'},
        {'id': 42, 'movie_number': 'ABP-1234', 'name': 'similar number', 'state': 'completed'},
      ], 'total': 2, 'page': 1, 'page_size': 100,
    });
    await _pumpPage(tester, sessionStore, apiClient);
    expect(find.byKey(const Key('movie-subscription-row-delete-downloads')), findsOneWidget);
    await tester.tap(find.byKey(const Key('movie-subscription-row-delete-downloads')));
    await tester.pumpAndSettle();
    expect(find.text('是否删除 1 个下载任务？'), findsOneWidget);
    expect(find.textContaining('ABP-123 task'), findsNothing);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
    expect(adapter.hitCount('GET', '/download-tasks'), 3);
  });

  for (final deleteFiles in [false, true]) {
    testWidgets('delete movie tasks with deleteFiles=$deleteFiles and refresh', (tester) async {
      _enqueuePage(adapter, [_item('ABP-123')]);
      final response = {
        'items': [
          {'id': 41, 'movie_number': 'ABP-123', 'name': 'Resource A', 'state': 'completed'},
          {'id': 42, 'movie_number': 'ABP-123', 'name': 'Resource B', 'state': 'failed'},
        ], 'total': 2, 'page': 1, 'page_size': 100,
      };
      adapter.setFallbackJson(method: 'GET', path: '/download-tasks', body: response);
      await _pumpPage(tester, sessionStore, apiClient);
      await tester.tap(find.byKey(const Key('movie-subscription-row-delete-downloads')));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 个下载任务'), findsOneWidget);
      if (deleteFiles) {
        await tester.tap(find.byKey(const Key('download-task-delete-files-checkbox')));
        await tester.pumpAndSettle();
      }
      for (final id in [41, 42]) {
        adapter.enqueueJson(method: 'DELETE', path: '/download-tasks/$id', statusCode: 204);
      }
      adapter.setFallbackJson(method: 'GET', path: '/download-tasks',
        body: {'items': [], 'total': 0, 'page': 1, 'page_size': 100});
      _enqueuePage(adapter, [_item('ABP-123')]);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      final deleted = adapter.requests.where((r) => r.method == 'DELETE').toList();
      expect(deleted.map((r) => r.path), ['/download-tasks/41', '/download-tasks/42']);
      for (final request in deleted) {
        expect(request.uri.queryParameters['delete_files'], '$deleteFiles');
        expect(request.uri.queryParameters['confirm_delete_files'], deleteFiles ? 'true' : null);
      }
      expect(find.byKey(const Key('download-task-delete-dialog')), findsNothing);
      expect(find.byKey(const Key('movie-subscription-row-delete-downloads')), findsNothing);
      expect(_listRequests(adapter).length, 2);
    });
  }

  testWidgets('movie deletion uses the file option captured at confirmation', (tester) async {
    _enqueuePage(adapter, [_item('ABP-123')]);
    adapter.setFallbackJson(method: 'GET', path: '/download-tasks', body: {
      'items': [
        {'id': 41, 'movie_number': 'ABP-123'},
        {'id': 42, 'movie_number': 'ABP-123'},
      ], 'total': 2, 'page': 1, 'page_size': 100,
    });
    await _pumpPage(tester, sessionStore, apiClient);
    await tester.tap(find.byKey(const Key('movie-subscription-row-delete-downloads')));
    await tester.pumpAndSettle();
    final first = Completer<ResponseBody>();
    adapter.enqueueResponder(method: 'DELETE', path: '/download-tasks/41',
      responder: (_, __) => first.future);
    adapter.enqueueJson(method: 'DELETE', path: '/download-tasks/42', statusCode: 204);
    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('download-task-delete-files-checkbox')));
    await tester.pump();
    adapter.setFallbackJson(method: 'GET', path: '/download-tasks',
      body: {'items': [], 'total': 0, 'page': 1, 'page_size': 100});
    _enqueuePage(adapter, [_item('ABP-123')]);
    first.complete(ResponseBody.fromBytes([], 204));
    await tester.pumpAndSettle();
    final deletes = adapter.requests.where((r) => r.method == 'DELETE').toList();
    expect(deletes, hasLength(2));
    expect(deletes.every((r) => r.uri.queryParameters['delete_files'] == 'false'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('partial deletion preserves dialog and retries only remaining task', (tester) async {
    _enqueuePage(adapter, [_item('ABP-123')]);
    adapter.setFallbackJson(method: 'GET', path: '/download-tasks', body: {
      'items': [
        {'id': 41, 'movie_number': 'ABP-123', 'name': 'Resource A'},
        {'id': 42, 'movie_number': 'ABP-123', 'name': 'Resource B'},
      ], 'total': 2, 'page': 1, 'page_size': 100,
    });
    await _pumpPage(tester, sessionStore, apiClient);
    await tester.tap(find.byKey(const Key('movie-subscription-row-delete-downloads')));
    await tester.pumpAndSettle();
    adapter.enqueueJson(method: 'DELETE', path: '/download-tasks/41', statusCode: 204);
    adapter.enqueueJson(method: 'DELETE', path: '/download-tasks/42', statusCode: 409,
      body: {'error': {'code': 'download_task_import_running', 'message': 'importing'}});
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('download-task-delete-dialog')), findsOneWidget);
    expect(find.text('任务正在导入，无法删除'), findsOneWidget);
    adapter.enqueueJson(method: 'DELETE', path: '/download-tasks/42', statusCode: 204);
    adapter.setFallbackJson(method: 'GET', path: '/download-tasks',
      body: {'items': [], 'total': 0, 'page': 1, 'page_size': 100});
    _enqueuePage(adapter, [_item('ABP-123')]);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(adapter.hitCount('DELETE', '/download-tasks/41'), 1);
    expect(adapter.hitCount('DELETE', '/download-tasks/42'), 2);
    expect(find.byKey(const Key('download-task-delete-dialog')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final deleteFiles in [false, true]) {
    testWidgets('batch download deletion deleteFiles=$deleteFiles skips movies without tasks', (tester) async {
      _enqueuePage(adapter, [_item('ABP-123'), _item('ABP-124'), _item('ABP-125')]);
      adapter.setFallbackJson(method: 'GET', path: '/download-tasks', body: {
        'items': [
          {'id': 41, 'movie_number': 'ABP-123', 'name': 'ABP-123 Resource A'},
          {'id': 42, 'movie_number': 'ABP-123', 'name': 'ABP-123 Resource B'},
          {'id': 43, 'movie_number': 'ABP-124', 'name': 'ABP-124 Resource C'},
          {'id': 99, 'movie_number': 'ABP-1234', 'name': 'Similar number'},
        ], 'total': 4, 'page': 1, 'page_size': 100,
      });
      await _pumpPage(tester, sessionStore, apiClient);
      await tester.tap(find.text('选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-subscriptions-select-all-button')));
      await tester.pumpAndSettle();
      expect(find.text('已选 3 部'), findsOneWidget);
      await tester.tap(find.byKey(const Key('movie-subscriptions-batch-delete-downloads-button')));
      await tester.pumpAndSettle();
      expect(find.textContaining('3 个下载任务'), findsOneWidget);
      expect(find.textContaining('Similar number'), findsNothing);
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
      if (deleteFiles) {
        await tester.tap(find.byKey(const Key('download-task-delete-files-checkbox')));
        await tester.pumpAndSettle();
      }
      for (final id in [41, 42, 43]) {
        adapter.enqueueJson(method: 'DELETE', path: '/download-tasks/$id', statusCode: 204);
      }
      adapter.setFallbackJson(method: 'GET', path: '/download-tasks',
        body: {'items': [], 'total': 0, 'page': 1, 'page_size': 100});
      _enqueuePage(adapter, [_item('ABP-123'), _item('ABP-124'), _item('ABP-125')]);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      final deletes = adapter.requests.where((r) => r.method == 'DELETE').toList();
      expect(deletes.map((r) => r.path), ['/download-tasks/41', '/download-tasks/42', '/download-tasks/43']);
      for (final request in deletes) {
        expect(request.uri.queryParameters['delete_files'], '$deleteFiles');
        expect(request.uri.queryParameters['confirm_delete_files'], deleteFiles ? 'true' : null);
      }
      expect(find.byKey(const Key('download-task-delete-dialog')), findsNothing);
      expect(_listRequests(adapter).length, 2);
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('batch deletion with no download tasks sends no delete request', (tester) async {
    _enqueuePage(adapter, [_item('ABP-123')]);
    await _pumpPage(tester, sessionStore, apiClient);
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-subscriptions-select-all-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-subscriptions-batch-delete-downloads-button')));
    await tester.pumpAndSettle();
    expect(find.text('所选影片没有下载任务'), findsOneWidget);
    expect(find.byKey(const Key('download-task-delete-dialog')), findsNothing);
    expect(adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
    await tester.pump(const Duration(seconds: 3));
  });

  for (final queryFails in [false, true]) {
    testWidgets('batch query shows progress before confirmation failure=$queryFails', (tester) async {
      _enqueuePage(adapter, [_item('ABP-123'), _item('ABP-124')]);
      await _pumpPage(tester, sessionStore, apiClient);
      await tester.tap(find.text('选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('movie-subscriptions-select-all-button')));
      await tester.pumpAndSettle();
      final firstQuery = Completer<ResponseBody>();
      final secondQuery = Completer<ResponseBody>();
      adapter.enqueueResponder(method: 'GET', path: '/download-tasks', responder: (_, _) => firstQuery.future);
      adapter.enqueueResponder(method: 'GET', path: '/download-tasks', responder: (_, _) => secondQuery.future);
      await tester.tap(find.byKey(const Key('movie-subscriptions-batch-delete-downloads-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('正在查询下载任务'), findsOneWidget);
      expect(find.text('处理中 0/2'), findsOneWidget);
      expect(find.byKey(const Key('download-task-delete-dialog')), findsNothing);
      firstQuery.complete(ResponseBody.fromString(
        '{"items":[{"id":41,"movie_number":"ABP-123","name":"Task"}],"total":1,"page":1,"page_size":100}',
        200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('处理中 1/2'), findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, .5);
      secondQuery.complete(ResponseBody.fromString(
        queryFails ? '{"error":{"message":"查询失败"}}' : '{"items":[],"total":0,"page":1,"page_size":100}',
        queryFails ? 400 : 200, headers: {Headers.contentTypeHeader: [Headers.jsonContentType]}));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      if (queryFails) {
        expect(find.text('成功 1 个，失败 1 个'), findsOneWidget);
        await tester.tap(find.byKey(const Key('batch-progress-close-button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('download-task-delete-dialog')), findsNothing);
      } else {
        await tester.pumpAndSettle();
        expect(find.text('是否删除 1 个下载任务？'), findsOneWidget);
        await tester.tap(find.descendant(of: find.byKey(const Key('download-task-delete-dialog')), matching: find.text('取消')));
        await tester.pumpAndSettle();
      }
      expect(adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
    });
  }

  testWidgets('batch delete shows progress and continues after individual failure', (tester) async {
    _enqueuePage(adapter, [_item('ABP-123'), _item('ABP-124'), _item('ABP-125')]);
    adapter.setFallbackJson(method: 'GET', path: '/download-tasks', body: {
      'items': [
        {'id': 41, 'movie_number': 'ABP-123', 'name': 'ABP-123 Resource A'},
        {'id': 42, 'movie_number': 'ABP-124', 'name': 'ABP-124 Resource B'},
        {'id': 43, 'movie_number': 'ABP-124', 'name': 'ABP-124 Resource C'},
      ], 'total': 3, 'page': 1, 'page_size': 100,
    });
    await _pumpPage(tester, sessionStore, apiClient);
    await tester.tap(find.text('选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-subscriptions-select-all-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('movie-subscriptions-batch-delete-downloads-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const Key('download-task-delete-dialog')), matching: find.text('取消')));
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.method == 'DELETE'), isEmpty);
    await tester.tap(find.byKey(const Key('movie-subscriptions-batch-delete-downloads-button')));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
    await tester.tap(find.byKey(const Key('download-task-delete-files-checkbox')));
    await tester.pumpAndSettle();
    final first = Completer<ResponseBody>();
    final last = Completer<ResponseBody>();
    adapter.enqueueResponder(method: 'DELETE', path: '/download-tasks/41', responder: (_, _) => first.future);
    adapter.enqueueJson(method: 'DELETE', path: '/download-tasks/42', statusCode: 409,
      body: {'error': {'code': 'download_task_import_running', 'message': 'importing'}});
    adapter.enqueueResponder(method: 'DELETE', path: '/download-tasks/43', responder: (_, _) => last.future);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('处理中 0/3'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('处理中 0/3'), findsOneWidget);
    first.complete(ResponseBody.fromBytes([], 204));
    await tester.pumpAndSettle();
    expect(find.text('处理中 2/3'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 2 / 3);
    last.complete(ResponseBody.fromBytes([], 204));
    await tester.pumpAndSettle();
    expect(find.text('成功 2 个，失败 1 个'), findsOneWidget);
    adapter.setFallbackJson(method: 'GET', path: '/download-tasks',
      body: {'items': [], 'total': 0, 'page': 1, 'page_size': 100});
    _enqueuePage(adapter, [_item('ABP-123'), _item('ABP-124'), _item('ABP-125')]);
    await tester.tap(find.byKey(const Key('batch-progress-close-button')));
    await tester.pumpAndSettle();
    expect(find.text('正在删除下载任务'), findsNothing);
    final deletes = adapter.requests.where((r) => r.method == 'DELETE').toList();
    expect(deletes.map((r) => r.path), ['/download-tasks/41', '/download-tasks/42', '/download-tasks/43']);
    expect(deletes.every((r) => r.uri.queryParameters['delete_files'] == 'true'), true);
    expect(_listRequests(adapter).length, 2);
    await tester.pump(const Duration(seconds: 3));
  });

}

Future<void> _pumpPage(
  WidgetTester tester,
  SessionStore sessionStore,
  ApiClient apiClient,
) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        downloadsApiProvider.overrideWithValue(DownloadsApi(apiClient: apiClient)),
        sessionStoreProvider.overrideWithValue(sessionStore),
        movieSubscriptionsApiProvider.overrideWithValue(
          MovieSubscriptionsApi(apiClient: apiClient),
        ),
        moviesApiProvider.overrideWithValue(MoviesApi(apiClient: apiClient)),
      ],
      child: OKToast(
        child: MaterialApp(
          theme: sakuraDesktopThemeData,
          home: const Scaffold(body: DesktopMovieSubscriptionsPage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _enqueuePage(
  FakeHttpClientAdapter adapter,
  List<Map<String, dynamic>> items, {
  int page = 1,
  int? total,
}) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/movie-subscriptions',
    body: <String, dynamic>{
      'items': items,
      'page': page,
      'page_size': 20,
      'total': total ?? items.length,
    },
  );
}

Map<String, dynamic> _item(String number) => <String, dynamic>{
  'movie_id': int.parse(number.split('-').last),
  'movie_number': number,
  'title': 'Title $number',
  'status': 'missing',
  'is_fresh': false,
  'attempt_count': 0,
  'attempt_limit': 3,
  'dead_download_task_count': 0,
  'media_count': 0,
};

List<RecordedRequest> _listRequests(FakeHttpClientAdapter adapter) => adapter
    .requests
    .where((request) => request.path == '/movie-subscriptions')
    .toList();
