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

    expect(find.byKey(const Key('desktop-movie-subscriptions-page')), findsOneWidget);
    expect(
      find.byKey(const Key('movie-subscription-row-number-ABP-123')),
      findsOneWidget,
    );
    expect(find.text('缺资源'), findsWidgets);
    expect(find.byKey(const Key('movie-subscription-row-open-import-ABP-123')),
        findsNothing);
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
  List<Map<String, dynamic>> items,
) {
  adapter.enqueueJson(
    method: 'GET',
    path: '/movie-subscriptions',
    body: <String, dynamic>{
      'items': items,
      'page': 1,
      'page_size': 20,
      'total': items.length,
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
