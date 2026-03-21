import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/network/api_exception.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_period.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_reviews_api.dart';

import '../../../support/fake_http_client_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionStore sessionStore;
  late ApiClient apiClient;
  late HotReviewsApi hotReviewsApi;
  late FakeHttpClientAdapter adapter;

  setUp(() async {
    sessionStore = SessionStore.inMemory();
    await sessionStore.saveBaseUrl('https://api.example.com');
    await sessionStore.saveTokens(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      expiresAt: DateTime.parse('2026-03-08T10:00:00Z'),
    );
    apiClient = ApiClient(sessionStore: sessionStore);
    hotReviewsApi = HotReviewsApi(apiClient: apiClient);
    adapter = FakeHttpClientAdapter();
    apiClient.rawDio.httpClientAdapter = adapter;
    apiClient.rawRefreshDio.httpClientAdapter = adapter;
  });

  tearDown(() {
    apiClient.dispose();
  });

  test('getHotReviews sends period and pagination query', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      statusCode: 200,
      body: <String, dynamic>{
        'items': [
          <String, dynamic>{
            'rank': 1,
            'review_id': 101,
            'score': 5,
            'content': '值得反复看',
            'created_at': '2026-03-21T01:00:00Z',
            'username': 'demo-user',
            'like_count': 11,
            'watch_count': 21,
            'movie': <String, dynamic>{
              'javdb_id': 'javdb-abp001',
              'movie_number': 'ABP-001',
              'title': 'Movie A',
              'cover_image': null,
              'release_date': null,
              'duration_minutes': 0,
              'is_subscribed': false,
              'can_play': false,
            },
          },
        ],
        'page': 2,
        'page_size': 10,
        'total': 30,
      },
    );

    final page = await hotReviewsApi.getHotReviews(
      period: HotReviewPeriod.monthly,
      page: 2,
      pageSize: 10,
    );

    final request = adapter.requests.single;
    expect(request.path, '/hot-reviews');
    expect(request.uri.queryParameters['period'], 'monthly');
    expect(request.uri.queryParameters['page'], '2');
    expect(request.uri.queryParameters['page_size'], '10');
    expect(page.items, hasLength(1));
    expect(page.items.single.reviewId, 101);
    expect(page.items.single.movie.movieNumber, 'ABP-001');
    expect(page.page, 2);
    expect(page.total, 30);
  });

  test('hot reviews api preserves backend ApiException payload', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/hot-reviews',
      statusCode: 422,
      body: <String, dynamic>{
        'error': <String, dynamic>{
          'code': 'invalid_hot_review_period',
          'message': 'period 不受支持',
        },
      },
    );

    expect(
      () => hotReviewsApi.getHotReviews(period: HotReviewPeriod.all),
      throwsA(
        isA<ApiException>().having(
          (ApiException error) => error.error?.code,
          'error.code',
          'invalid_hot_review_period',
        ),
      ),
    );
  });
}
