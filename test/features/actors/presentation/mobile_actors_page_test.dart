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
import 'package:sakuramedia/features/actors/presentation/mobile_actors_page.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
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
    'mobile actors page shows loading skeletons before data resolves',
    (WidgetTester tester) async {
      final completer = Completer<void>();
      addTearDown(() {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });

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

  testWidgets('mobile actors page renders total count and grid', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(total: 2),
    );

    await _pumpActorsPage(tester, sessionStore: sessionStore, bundle: bundle);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mobile-actors-page-total')), findsOneWidget);
    expect(find.text('2 位'), findsOneWidget);
    expect(find.byType(ActorSummaryCard), findsNWidgets(2));
    expect(find.text('三上悠亚 / 鬼头桃菜'), findsOneWidget);
  });

  testWidgets('mobile actors page applies filters and sends expected params', (
    WidgetTester tester,
  ) async {
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

    await tester.tap(find.byIcon(Icons.filter_alt_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('未订阅'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('河北彩花'), findsOneWidget);
    expect(_queryValue(bundle, 1, 'subscription_status'), 'unsubscribed');
    expect(_queryValue(bundle, 1, 'gender'), 'female');
  });

  testWidgets(
    'mobile actors page loads next page on scroll and retries failed load more',
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

  testWidgets('mobile actors page card tap navigates to actor detail', (
    WidgetTester tester,
  ) async {
    bundle.adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _actorsJson(total: 2),
    );

    Object? actorDetailExtra;
    final router = GoRouter(
      routes: <RouteBase>[
        GoRoute(
          path: mobileActorsPath,
          builder: (_, __) => const MobileActorsPage(),
        ),
        GoRoute(
          path: '$mobileActorsPath/:actorId',
          builder: (_, state) {
            actorDetailExtra = state.extra;
            return Text(
              'actor:${state.pathParameters['actorId']}',
              textDirection: TextDirection.ltr,
            );
          },
        ),
      ],
      initialLocation: mobileActorsPath,
    );
    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
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

    expect(find.text('actor:1'), findsOneWidget);
    expect(actorDetailExtra, isNull);
  });
}

Future<void> _pumpActorsPage(
  WidgetTester tester, {
  required SessionStore sessionStore,
  required TestApiBundle bundle,
}) {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
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
        home: OKToast(child: const Scaffold(body: MobileActorsPage())),
      ),
    ),
  );
}

String? _queryValue(TestApiBundle bundle, int requestIndex, String key) {
  final request = bundle.adapter.requests[requestIndex];
  return request.uri.queryParameters[key];
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
