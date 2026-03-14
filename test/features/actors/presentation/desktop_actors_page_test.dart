import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:oktoast/oktoast.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/desktop_actors_page.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actors/actor_summary_card.dart';

import '../../../support/test_api_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late TestApiBundle bundle;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-10T12:00:00Z'),
    );
    bundle = await createTestApiBundle(sessionStore);
  });

  tearDown(() {
    bundle.dispose();
  });

  testWidgets(
    'desktop actors page shows loading skeletons before data resolves',
    (WidgetTester tester) async {
      final completer = Completer<void>();
      bundle.adapter.enqueueResponder(
        method: 'GET',
        path: '/actors',
        responder: (options, body) async {
          await completer.future;
          return ResponseBody.fromString(
            jsonEncode(_actorsJson(total: 2)),
            200,
            headers: const <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        },
      );

      await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pump();

      expect(find.byKey(const Key('actor-summary-grid')), findsOneWidget);
      expect(
        find.byKey(const Key('actor-summary-card-skeleton-0')),
        findsOneWidget,
      );

      completer.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('desktop actors page renders list and total count', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(total: 2),
    );

    await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('actors-page-total')), findsOneWidget);
    expect(find.text('2 位'), findsOneWidget);
    expect(find.byType(ActorSummaryCard), findsNWidgets(2));
    expect(find.text('三上悠亚 / 鬼头桃菜'), findsOneWidget);
    expect(
      find.byKey(const Key('actor-summary-card-subscription-1')),
      findsOneWidget,
    );
  });

  testWidgets('desktop actors page shows empty state', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(total: 0, items: const <Map<String, dynamic>>[]),
    );

    await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('暂无女优数据'), findsOneWidget);
  });

  testWidgets('desktop actors page shows error state', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      statusCode: 500,
      body: <String, dynamic>{
        'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
      },
    );

    await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.text('女优列表加载失败，请稍后重试'), findsOneWidget);
  });

  testWidgets(
    'desktop actors page updates filter label and reloads first page',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors',
        body: _actorsJson(total: 2),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors',
        body: _actorsJson(
          total: 1,
          items: <Map<String, dynamic>>[
            _actorItem(id: 3, name: '河北彩花', aliasName: ''),
          ],
        ),
      );

      await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('actors-filter-trigger-label')),
        findsOneWidget,
      );
      expect(_triggerLabelText(tester), '已订阅');

      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('actors-filter-panel')), findsOneWidget);
      await tester.tap(find.text('未订阅'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('河北彩花'), findsOneWidget);
      expect(find.text('1 位'), findsOneWidget);
      expect(find.byKey(const Key('actors-filter-panel')), findsOneWidget);
      expect(
        find.byKey(const Key('actors-filter-trigger-label')),
        findsOneWidget,
      );
      expect(_triggerLabelText(tester), '未订阅');
      expect(_queryValue(bundle, 1, 'subscription_status'), 'unsubscribed');
      expect(_queryValue(bundle, 1, 'gender'), 'female');
    },
  );

  testWidgets(
    'desktop actors page keeps subscription label when gender changes',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors',
        body: _actorsJson(total: 2),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors',
        body: _actorsJson(total: 1),
      );

      await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('男优'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_triggerLabelText(tester), '已订阅');
      expect(_queryValue(bundle, 1, 'subscription_status'), 'subscribed');
      expect(_queryValue(bundle, 1, 'gender'), 'male');
    },
  );

  testWidgets('desktop actors page filter panel closes when tapping outside', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(total: 2),
    );

    await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('actors-filter-panel')), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('actors-filter-panel')), findsNothing);
  });

  testWidgets('desktop actors page uses smaller buttons inside filter panel', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(total: 2),
    );

    await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    final triggerHeight = _buttonHeightForLabel(tester, '已订阅');

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();

    expect(_buttonHeightForLabel(tester, '未订阅'), lessThan(triggerHeight));
  });

  testWidgets(
    'desktop actors page loads next page on scroll and retries failed load more',
    (WidgetTester tester) async {
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors',
        body: _actorsJson(
          total: 30,
          items: List<Map<String, dynamic>>.generate(
            24,
            (index) => _actorItem(
              id: index + 1,
              name: 'Actor ${index + 1}',
              aliasName: '',
            ),
          ),
        ),
      );
      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors',
        statusCode: 500,
        body: <String, dynamic>{
          'error': <String, dynamic>{'code': 'server_error', 'message': 'boom'},
        },
      );

      await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2800),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ActorSummaryCard), findsNWidgets(24));
      expect(find.text('加载更多失败，请点击重试'), findsOneWidget);

      bundle.adapter.enqueueJson(
        method: 'GET',
        path: '/actors',
        body: _actorsJson(
          page: 2,
          total: 30,
          items: List<Map<String, dynamic>>.generate(
            6,
            (index) => _actorItem(
              id: index + 25,
              name: 'Actor ${index + 25}',
              aliasName: '',
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.widgetWithText(TextButton, '重试'));
      await tester.tap(find.widgetWithText(TextButton, '重试'));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(bundle.adapter.hitCount('GET', '/actors'), 3);
      expect(find.byType(ActorSummaryCard), findsNWidgets(30));
      expect(find.byKey(const Key('actor-summary-card-25')), findsOneWidget);
    },
  );

  testWidgets('desktop actors page navigates to actor detail on card tap', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(total: 2),
    );

    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const DesktopActorsPage(),
          routes: <RouteBase>[
            GoRoute(
              path: 'desktop/library/actors/:actorId',
              name: 'desktop-actor-detail',
              builder:
                  (context, state) =>
                      Text('actor:${state.pathParameters['actorId']}'),
            ),
          ],
        ),
      ],
    );

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
          Provider<ActorsApi>.value(value: bundle.actorsApi),
        ],
        child: MaterialApp.router(theme: sakuraThemeData, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('actor-summary-card-1')));
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/desktop/library/actors/1',
    );
    expect(find.text('actor:1'), findsOneWidget);
  });

  testWidgets('desktop actors page toggles actor subscription in place', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(
        total: 1,
        items: <Map<String, dynamic>>[
          _actorItem(
            id: 1,
            name: '三上悠亚',
            aliasName: '三上悠亚 / 鬼头桃菜',
            isSubscribed: true,
          ),
        ],
      ),
    );
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/actors/1/subscription',
      statusCode: 204,
    );

    await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('actor-summary-card-subscription-1')),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(bundle.adapter.hitCount('DELETE', '/actors/1/subscription'), 1);
    expect(find.text('已取消订阅女优'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}

Future<void> _pumpActorsPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionStore>.value(value: sessionStore),
        Provider<ActorsApi>.value(value: bundle.actorsApi),
      ],
      child: MaterialApp(
        theme: sakuraThemeData,
        home: OKToast(child: const Scaffold(body: DesktopActorsPage())),
      ),
    ),
  );
}

String? _queryValue(TestApiBundle bundle, int requestIndex, String key) {
  final request = bundle.adapter.requests[requestIndex];
  return request.uri.queryParameters[key];
}

String _triggerLabelText(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const Key('actors-filter-trigger-label')))
      .data!;
}

double _buttonHeightForLabel(WidgetTester tester, String label) {
  final containerFinder = find.ancestor(
    of: find.text(label).first,
    matching: find.byType(AnimatedContainer),
  );

  return tester.getSize(containerFinder.first).height;
}

Map<String, dynamic> _actorsJson({
  int page = 1,
  int total = 2,
  List<Map<String, dynamic>>? items,
}) {
  return <String, dynamic>{
    'items':
        items ??
        <Map<String, dynamic>>[
          _actorItem(
            id: 1,
            name: '三上悠亚',
            aliasName: '三上悠亚 / 鬼头桃菜',
            isSubscribed: true,
          ),
          _actorItem(id: 2, name: '桥本有菜', aliasName: ''),
        ],
    'page': page,
    'page_size': 24,
    'total': total,
  };
}

Map<String, dynamic> _actorItem({
  required int id,
  required String name,
  required String aliasName,
  bool isSubscribed = false,
}) {
  return <String, dynamic>{
    'id': id,
    'javdb_id': 'Actor$id',
    'name': name,
    'alias_name': aliasName,
    'profile_image':
        id == 1
            ? <String, dynamic>{
              'id': 10,
              'origin': '/files/images/actors/Actor$id.jpg',
              'small': '/files/images/actors/Actor$id-small.jpg',
              'medium': '/files/images/actors/Actor$id-medium.jpg',
              'large': '/files/images/actors/Actor$id-large.jpg',
            }
            : null,
    'is_subscribed': isSubscribed,
  };
}
