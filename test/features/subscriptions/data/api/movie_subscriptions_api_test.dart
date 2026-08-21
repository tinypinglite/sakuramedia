import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/subscriptions/data/api/movie_subscriptions_api.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';

import '../../../../support/fake_http_client_adapter.dart';

void main() {
  late SessionStore sessionStore;
  late ApiClient apiClient;
  late FakeHttpClientAdapter adapter;
  late MovieSubscriptionsApi api;

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
    api = MovieSubscriptionsApi(apiClient: apiClient);
  });

  tearDown(() {
    apiClient.dispose();
    sessionStore.dispose();
  });

  test('getSubscriptions 只在有值时下发 status / sort / search', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(items: const <Map<String, dynamic>>[]),
    );

    await api.getSubscriptions();

    final query = adapter.requests.single.uri.queryParameters;
    expect(query['page'], '1');
    expect(query['page_size'], '20');
    expect(query.containsKey('status'), isFalse);
    expect(query.containsKey('sort'), isFalse);
    expect(query.containsKey('search'), isFalse);
  });

  test('getSubscriptions 把 status / sort 翻译成后端线上值，search 先 trim', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(items: const <Map<String, dynamic>>[]),
    );

    await api.getSubscriptions(
      page: 2,
      pageSize: 50,
      status: MovieSubscriptionStatus.exhausted,
      sort: MovieSubscriptionSort.attemptCountDesc,
      search: '  ABP-123  ',
    );

    final query = adapter.requests.single.uri.queryParameters;
    expect(query['page'], '2');
    expect(query['page_size'], '50');
    expect(query['status'], 'exhausted');
    expect(query['sort'], 'attempt_count:desc');
    expect(query['search'], 'ABP-123');
  });

  test('search 只有空白时不下发（避免把「全部」搜成空结果）', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(items: const <Map<String, dynamic>>[]),
    );

    await api.getSubscriptions(search: '   ');

    expect(
      adapter.requests.single.uri.queryParameters.containsKey('search'),
      isFalse,
    );
  });

  test('getSubscriptions 解析列表项全字段', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(
        items: <Map<String, dynamic>>[
          <String, dynamic>{
            'movie_id': 321,
            'movie_number': 'ABP-123',
            'title': 'Original Title',
            'cover_image': <String, dynamic>{
              'id': 7,
              'origin': '/covers/7-origin.jpg',
              'small': '/covers/7-small.jpg',
              'medium': '/covers/7-medium.jpg',
              'large': '/covers/7-large.jpg',
            },
            'release_date': '2019-05-01',
            'subscribed_at': '2026-01-02T03:04:05',
            'status': 'missing',
            'is_fresh': false,
            'attempt_count': 2,
            'attempt_limit': 3,
            'last_searched_at': '2026-07-20T02:30:00',
            'last_error': null,
            'dead_download_task_count': 1,
            'media_count': 0,
          },
        ],
        total: 1,
      ),
    );

    final response = await api.getSubscriptions();

    final item = response.items.single;
    expect(item.movieId, 321);
    expect(item.movieNumber, 'ABP-123');
    expect(item.displayTitle, 'Original Title');
    expect(item.coverImage?.bestAvailableUrl, '/covers/7-large.jpg');
    expect(item.releaseDate, '2019-05-01');
    expect(item.status, MovieSubscriptionStatus.missing);
    expect(item.isFresh, isFalse);
    expect(item.attemptCount, 2);
    expect(item.attemptLimit, 3);
    expect(item.lastSearchedAt, DateTime.parse('2026-07-20T02:30:00'));
    expect(item.lastError, isNull);
    expect(item.deadDownloadTaskCount, 1);
    expect(item.mediaCount, 0);
    expect(item.canResetSearch, isTrue);
    expect(response.total, 1);
  });

  test('未知 status 归 unknown，缺失字段走默认值而不抛', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(
        items: <Map<String, dynamic>>[
          <String, dynamic>{'movie_number': 'STARS-001', 'status': '未来新状态'},
        ],
        total: 1,
      ),
    );

    final item = (await api.getSubscriptions()).items.single;

    expect(item.status, MovieSubscriptionStatus.unknown);
    // 老响应缺 movie_id 时容错为 0（调用方按 >0 判可用）。
    expect(item.movieId, 0);
    expect(item.title, '');
    // 标题全空时回落番号，列表不会出现空白行。
    expect(item.displayTitle, 'STARS-001');
    expect(item.coverImage, isNull);
    expect(item.releaseDate, isNull);
    expect(item.subscribedAt, isNull);
    expect(item.attemptCount, 0);
    expect(item.deadDownloadTaskCount, 0);
  });

  test('仅缺资源 / 已放弃 / 查询出错允许重置查询', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions',
      body: _page(
        items: <Map<String, dynamic>>[
          <String, dynamic>{'movie_number': 'A-1', 'status': 'imported'},
          <String, dynamic>{'movie_number': 'A-2', 'status': 'downloading'},
          // 文件已在盘上，重新找种子只会白下一遍。
          <String, dynamic>{'movie_number': 'A-3', 'status': 'import_failed'},
          <String, dynamic>{'movie_number': 'A-4', 'status': 'exhausted'},
          // 待查的投影是 pending，统一 action 会按 state_not_actionable 跳过，
          // 前端不给按钮。
          <String, dynamic>{'movie_number': 'A-5', 'status': 'pending'},
          <String, dynamic>{'movie_number': 'A-6', 'status': 'missing'},
          <String, dynamic>{'movie_number': 'A-7', 'status': 'failed'},
        ],
        total: 7,
      ),
    );

    final items = (await api.getSubscriptions()).items;

    expect(items[0].canResetSearch, isFalse);
    expect(items[1].canResetSearch, isFalse);
    expect(items[2].status, MovieSubscriptionStatus.importFailed);
    expect(items[2].canResetSearch, isFalse);
    expect(items[3].canResetSearch, isTrue);
    expect(items[4].canResetSearch, isFalse);
    expect(items[5].canResetSearch, isTrue);
    expect(items[6].canResetSearch, isTrue);
  });

  test('import_failed 与 failed 是两个不同状态，文案不能混', () {
    expect(MovieSubscriptionStatus.importFailed.apiValue, 'import_failed');
    expect(MovieSubscriptionStatus.importFailed.label, '导入失败');
    expect(MovieSubscriptionStatus.failed.apiValue, 'failed');
    expect(MovieSubscriptionStatus.failed.label, '查询出错');
  });

  test('getStatusCounts 解析各状态计数并按状态取值', () async {
    adapter.enqueueJson(
      method: 'GET',
      path: '/movie-subscriptions/status-counts',
      body: <String, dynamic>{
        'total': 1200,
        'imported': 1050,
        'import_failed': 3,
        'downloading': 9,
        'pending': 30,
        'missing': 95,
        'exhausted': 12,
        'failed': 1,
      },
    );

    final counts = await api.getStatusCounts();

    expect(counts.total, 1200);
    expect(counts.countOf(null), 1200);
    expect(counts.countOf(MovieSubscriptionStatus.missing), 95);
    expect(counts.countOf(MovieSubscriptionStatus.exhausted), 12);
    expect(counts.countOf(MovieSubscriptionStatus.importFailed), 3);
    expect(counts.countOf(MovieSubscriptionStatus.unknown), 0);
    // 七项之和恒等于 total，是后端 CASE 互斥性的镜像断言。
    final sum =
        counts.imported +
        counts.importFailed +
        counts.downloading +
        counts.pending +
        counts.missing +
        counts.exhausted +
        counts.failed;
    expect(sum, counts.total);
  });

  test('resetSearches posts optional movie ids to the reset endpoint', () async {
    adapter.enqueueJson(
      method: 'POST',
      path: '/movie-subscriptions/search-resets',
      body: <String, dynamic>{'reset_count': 2},
    );

    final result = await api.resetSearches(movieIds: <int>[11, 12]);

    expect(result.resetCount, 2);
    expect(adapter.requests.single.body, <String, dynamic>{
      'movie_ids': <int>[11, 12],
    });
  });
}

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> items,
  int total = 0,
  int page = 1,
}) {
  return <String, dynamic>{
    'items': items,
    'page': page,
    'page_size': 20,
    'total': total,
  };
}
