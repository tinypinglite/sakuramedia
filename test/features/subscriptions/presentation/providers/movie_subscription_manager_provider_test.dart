import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/providers/session_store_provider.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/movies/data/api/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movies_api_provider.dart';
import 'package:sakuramedia/features/subscriptions/data/api/movie_subscriptions_api.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscriptions_api_provider.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late ProviderContainer container;

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
    container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(sessionStore),
        movieSubscriptionsApiProvider.overrideWithValue(
          MovieSubscriptionsApi(apiClient: apiClient),
        ),
        moviesApiProvider.overrideWithValue(MoviesApi(apiClient: apiClient)),
      ],
      retry: (_, _) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('default filter loads missing subscriptions', () async {
    _enqueuePage(adapter, [_item('A-1', 'missing')]);

    final state = await container.read(movieSubscriptionManagerProvider.future);

    expect(state.filter.status, MovieSubscriptionStatus.missing);
    expect(state.paged.items.single.movieNumber, 'A-1');
    expect(adapter.requests.first.uri.queryParameters['status'], 'missing');
  });

  test('resetSearch posts movie id and reloads the list', () async {
    _enqueuePage(adapter, [_item('A-1', 'missing')]);
    await container.read(movieSubscriptionManagerProvider.future);
    adapter.enqueueJson(
      method: 'POST',
      path: '/movie-subscriptions/search-resets',
      body: <String, dynamic>{'reset_count': 1},
    );
    _enqueuePage(adapter, [_item('A-1', 'pending')]);

    final result = await container
        .read(movieSubscriptionManagerProvider.notifier)
        .resetSearch('A-1');

    expect(result.affectedCount, 1);
    expect(result.hasError, isFalse);
    expect(
      container
          .read(movieSubscriptionManagerProvider)
          .requireValue
          .paged
          .items
          .single
          .status,
      MovieSubscriptionStatus.pending,
    );
    final request = adapter.requests.firstWhere(
      (item) => item.path == '/movie-subscriptions/search-resets',
    );
    expect(request.body, <String, dynamic>{'movie_ids': <int>[1]});
  });

  test('resetAllExhausted uses the reset endpoint without legacy actions', () async {
    _enqueuePage(adapter, [_item('A-1', 'exhausted')]);
    await container.read(movieSubscriptionManagerProvider.future);
    adapter.enqueueJson(
      method: 'POST',
      path: '/movie-subscriptions/search-resets',
      body: <String, dynamic>{'reset_count': 1},
    );
    _enqueuePage(adapter, const <Map<String, dynamic>>[]);

    final result = await container
        .read(movieSubscriptionManagerProvider.notifier)
        .resetAllExhausted();

    expect(result.affectedCount, 1);
    expect(
      adapter.requests.where((request) => request.method == 'POST').length,
      1,
    );
  });
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

Map<String, dynamic> _item(String number, String status) => <String, dynamic>{
  'movie_id': int.parse(number.split('-').last),
  'movie_number': number,
  'title': 'Title $number',
  'status': status,
  'is_fresh': false,
  'attempt_count': 0,
  'attempt_limit': 3,
  'dead_download_task_count': 0,
  'media_count': 0,
};
