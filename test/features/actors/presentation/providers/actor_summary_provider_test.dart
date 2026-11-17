import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_mutation_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_removal_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_scope.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';

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
    container = ProviderContainer(
      overrides: [
        actorsApiProvider.overrideWithValue(ActorsApi(apiClient: apiClient)),
      ],
      retry: (_, __) => null,
    );
  });

  tearDown(() {
    container.dispose();
    apiClient.dispose();
    sessionStore.dispose();
  });

  Future<void> prime(
    ActorSummaryScope scope,
    List<Map<String, dynamic>> items, {
    int? total,
  }) {
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(items: items, total: total ?? items.length),
    );
    container.listen(actorSummaryProvider(scope), (_, __) {});
    return container.read(actorSummaryProvider(scope).future);
  }

  test('初始加载使用默认筛选和 24 条分页参数', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1)]);

    final request = adapter.requests.single;
    expect(request.path, '/actors');
    expect(request.uri.queryParameters['page_size'], '24');
    expect(request.uri.queryParameters['subscription_status'], 'subscribed');
    expect(request.uri.queryParameters['gender'], 'all');
    expect(request.uri.queryParameters['sort'], 'subscribed_at:desc');
  });

  test('筛选切换清空旧页并用新参数重拉', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1)]);
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(items: <Map<String, dynamic>>[_actor(2)], total: 1),
    );

    await container
        .read(actorSummaryProvider(scope).notifier)
        .applyFilter(
          const ActorFilterState(
            subscriptionStatus: ActorSubscriptionStatus.unsubscribed,
            gender: ActorGender.female,
            sortField: ActorSortField.name,
            sortDirection: SortDirection.asc,
          ),
        );

    final state = container.read(actorSummaryProvider(scope)).requireValue;
    expect(state.paged.items.single.id, 2);
    expect(state.filter.gender, ActorGender.female);
    final request = adapter.requests.last;
    expect(request.uri.queryParameters['subscription_status'], 'unsubscribed');
    expect(request.uri.queryParameters['gender'], 'female');
    expect(request.uri.queryParameters['sort'], 'name:asc');
  });

  test('资料筛选条件透传到演员列表接口', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1)]);
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(items: <Map<String, dynamic>>[_actor(2)], total: 1),
    );

    await container
        .read(actorSummaryProvider(scope).notifier)
        .applyFilter(
          const ActorFilterState(
            ageMin: 20,
            ageMax: 30,
            heightMin: 155,
            heightMax: 170,
            cups: ['B', 'C'],
          ),
        );

    final query = adapter.requests.last.uri.queryParameters;
    expect(query['age_min'], '20');
    expect(query['age_max'], '30');
    expect(query['height_min'], '155');
    expect(query['height_max'], '170');
    expect(query['cups'], 'B,C');
  });

  test('搜索关键词时透传 query 且默认按相关度省略 sort', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1)]);
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(items: <Map<String, dynamic>>[_actor(2)], total: 1),
    );

    await container
        .read(actorSummaryProvider(scope).notifier)
        .applyFilter(const ActorFilterState(query: '三上'));

    final query = adapter.requests.last.uri.queryParameters;
    expect(query['query'], '三上');
    expect(query.containsKey('sort'), isFalse);
  });

  test('搜索时选择其他排序字段仍按其排序，可播放筛选透传', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1)]);
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(items: <Map<String, dynamic>>[_actor(2)], total: 1),
    );

    await container
        .read(actorSummaryProvider(scope).notifier)
        .applyFilter(
          const ActorFilterState(
            query: '三上',
            hasPlayableMovies: true,
            sortField: ActorSortField.playableMovieCount,
          ),
        );

    final query = adapter.requests.last.uri.queryParameters;
    expect(query['query'], '三上');
    expect(query['has_playable_movies'], 'true');
    expect(query['sort'], 'playable_movie_count:desc');
  });

  test('初始失败可显式重试，缓存 link 不随重试累加', () async {
    const scope = ActorSummaryScope.desktop();
    adapter.enqueueJson(method: 'GET', path: '/actors', statusCode: 500);
    final subscription = container.listen(
      actorSummaryProvider(scope),
      (_, __) {},
    );
    await expectLater(
      container.read(actorSummaryProvider(scope).future),
      throwsA(isA<Object>()),
    );
    final firstLink = container
        .read(actorSummaryProvider(scope).notifier)
        .cacheLink;
    expect(firstLink, isNotNull);

    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(items: <Map<String, dynamic>>[_actor(2)], total: 1),
    );
    await container.read(actorSummaryProvider(scope).notifier).reload();

    expect(
      container
          .read(actorSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .single
          .id,
      2,
    );
    expect(
      identical(
        container.read(actorSummaryProvider(scope).notifier).cacheLink,
        firstLink,
      ),
      isTrue,
    );
    subscription.close();
  });

  test('单条订阅成功后才翻转本地条目并清理 busy', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1, isSubscribed: false)]);
    adapter.enqueueJson(
      method: 'PUT',
      path: '/actors/1/subscription',
      statusCode: 204,
    );

    final result = await container
        .read(actorSummaryProvider(scope).notifier)
        .toggleSubscription(1);

    expect(result.status.name, 'subscribed');
    final state = container.read(actorSummaryProvider(scope)).requireValue;
    expect(state.paged.items.single.isSubscribed, isTrue);
    expect(state.isSubscriptionUpdating(1), isFalse);
  });

  test('订阅失败保留条目原态并清理 busy', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1, isSubscribed: true)]);
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/actors/1/subscription',
      statusCode: 500,
      body: <String, dynamic>{'detail': 'boom'},
    );

    final result = await container
        .read(actorSummaryProvider(scope).notifier)
        .toggleSubscription(1);

    expect(result.status.name, 'failed');
    final state = container.read(actorSummaryProvider(scope)).requireValue;
    expect(state.paged.items.single.isSubscribed, isTrue);
    expect(state.isSubscriptionUpdating(1), isFalse);
  });

  test('单条订阅成功后向订阅事件广播变更', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1)]);
    adapter.enqueueJson(
      method: 'DELETE',
      path: '/actors/1/subscription',
      statusCode: 204,
    );
    final changes = <ActorSubscriptionChange>[];
    final subscription = container.listen(actorSubscriptionEventsProvider, (
      _,
      next,
    ) {
      if (next.hasValue) {
        changes.add(next.requireValue);
      }
    });
    addTearDown(subscription.close);

    final result = await container
        .read(actorSummaryProvider(scope).notifier)
        .toggleSubscription(1);

    expect(result.status.name, 'unsubscribed');
    expect(changes.single.actorId, 1);
    expect(changes.single.isSubscribed, isFalse);
  });

  test('订阅广播在「已订阅」筛选下保留行并就地翻态', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1), _actor(2)], total: 2);

    container
        .read(actorSubscriptionEventsProvider.notifier)
        .reportChange(actorId: 2, isSubscribed: false);
    await _settle();

    // 单条翻转不再即时移除：行保留、心变灰，刷新/重进后自然收敛。
    final state = container.read(actorSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((actor) => actor.id), <int>[1, 2]);
    expect(state.paged.items.last.isSubscribed, isFalse);
    expect(state.paged.total, 2);
  });

  test('订阅广播在「全部」筛选下就地翻转订阅态', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1)]);
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(items: <Map<String, dynamic>>[_actor(1)], total: 1),
    );
    await container
        .read(actorSummaryProvider(scope).notifier)
        .applyFilter(
          const ActorFilterState(
            subscriptionStatus: ActorSubscriptionStatus.all,
          ),
        );

    container
        .read(actorSubscriptionEventsProvider.notifier)
        .reportChange(actorId: 1, isSubscribed: false);
    await _settle();

    final state = container.read(actorSummaryProvider(scope)).requireValue;
    expect(state.paged.items.single.isSubscribed, isFalse);
    expect(state.paged.total, 1);
  });

  test('收藏列表外的新女优时重拉已订阅筛选', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1)], total: 1);
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(
        items: <Map<String, dynamic>>[_actor(9), _actor(1)],
        total: 2,
      ),
    );

    container
        .read(actorSubscriptionEventsProvider.notifier)
        .reportChange(actorId: 9, isSubscribed: true);
    await _waitFor(
      () =>
          container
              .read(actorSummaryProvider(scope))
              .value
              ?.paged
              .items
              .length ==
          2,
    );

    expect(adapter.requests, hasLength(2));
    expect(
      adapter.requests.last.uri.queryParameters['subscription_status'],
      'subscribed',
    );
    final state = container.read(actorSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((actor) => actor.id), <int>[9, 1]);
    expect(state.paged.total, 2);
  });

  test('desktop/mobile family 状态隔离', () async {
    const desktop = ActorSummaryScope.desktop();
    const mobile = ActorSummaryScope.mobile();
    await prime(desktop, <Map<String, dynamic>>[_actor(1)]);
    await prime(mobile, <Map<String, dynamic>>[_actor(2)]);

    expect(
      container
          .read(actorSummaryProvider(desktop))
          .requireValue
          .paged
          .items
          .single
          .id,
      1,
    );
    expect(
      container
          .read(actorSummaryProvider(mobile))
          .requireValue
          .paged
          .items
          .single
          .id,
      2,
    );
  });

  test('演员资料变更会就地更新缓存条目的显示名、头像与资料', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1)]);

    final updated = ActorListItemDto.fromJson(<String, dynamic>{
      ..._actor(1),
      'display_name': '新的显示名',
      'profile_image': <String, dynamic>{'id': 10, 'origin': 'large.jpg'},
      'movie_count': 12,
      'age': 28,
      'birthday': '1998-05-03',
      'height_cm': 165,
      'bust_cm': 86,
      'waist_cm': 58,
      'hips_cm': 88,
      'cup': 'E',
    });
    container.read(actorMutationEventsProvider.notifier).reportUpdated(updated);
    await _settle();

    final actor = container
        .read(actorSummaryProvider(scope))
        .requireValue
        .paged
        .items
        .single;
    expect(actor.displayName, '新的显示名');
    expect(actor.profileImage?.origin, 'large.jpg');
    expect(actor.movieCount, 12);
    expect(actor.age, 28);
    expect(actor.birthday, DateTime(1998, 5, 3));
    expect(actor.heightCm, 165);
    expect(actor.bustCm, 86);
    expect(actor.waistCm, 58);
    expect(actor.hipsCm, 88);
    expect(actor.cup, 'E');
  });

  test('合并移除广播把来源卡片摘掉并同步总数', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1), _actor(2)], total: 2);

    container.read(actorRemovalEventsProvider.notifier).reportRemoved(<int>[2]);
    await _settle();

    final state = container.read(actorSummaryProvider(scope)).requireValue;
    expect(state.paged.items.map((actor) => actor.id), <int>[1]);
    expect(state.paged.total, 1);
  });

  test('页面缓存 link 保活列表，驱逐后下一次读取重建 provider', () async {
    const scope = ActorSummaryScope.desktop();
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(items: <Map<String, dynamic>>[_actor(1)], total: 1),
    );
    final subscription = container.listen(
      actorSummaryProvider(scope),
      (_, __) {},
    );
    await container.read(actorSummaryProvider(scope).future);
    final firstLink = container
        .read(actorSummaryProvider(scope).notifier)
        .cacheLink;
    expect(firstLink, isNotNull);

    final cache = RiverpodPageCache();
    addTearDown(cache.dispose);
    cache.obtain(key: scope.cacheKey, resolveLinks: () => [firstLink!]);
    subscription.close();
    await _settle();
    expect(
      container
          .read(actorSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .single
          .id,
      1,
    );

    cache.remove(scope.cacheKey);
    await _settle();
    adapter.enqueueJson(
      method: 'GET',
      path: '/actors',
      body: _page(items: <Map<String, dynamic>>[_actor(2)], total: 1),
    );
    final rebuiltLink = container
        .read(actorSummaryProvider(scope).notifier)
        .cacheLink;
    expect(rebuiltLink, isNotNull);
    expect(identical(rebuiltLink, firstLink), isFalse);
    await container.read(actorSummaryProvider(scope).future);
    expect(
      container
          .read(actorSummaryProvider(scope))
          .requireValue
          .paged
          .items
          .single
          .id,
      2,
    );
  });
}

Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var index = 0; index < 50; index++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('条件未在预期轮次内满足');
}

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> items,
  required int total,
}) {
  return <String, dynamic>{
    'items': items,
    'page': 1,
    'page_size': 24,
    'total': total,
  };
}

Map<String, dynamic> _actor(int id, {bool isSubscribed = true}) {
  return <String, dynamic>{
    'id': id,
    'name': '演员$id',
    'alias_name': '',
    'profile_image': null,
    'is_subscribed': isSubscribed,
  };
}
