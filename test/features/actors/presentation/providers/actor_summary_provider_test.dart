import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/data/api/actors_api.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_mutation_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_scope.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';

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
            sortDirection: ActorSortDirection.asc,
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

  test('演员资料变更会就地更新缓存条目的显示名和头像', () async {
    const scope = ActorSummaryScope.desktop();
    await prime(scope, <Map<String, dynamic>>[_actor(1)]);

    final updated = ActorListItemDto.fromJson(<String, dynamic>{
      ..._actor(1),
      'display_name': '新的显示名',
      'profile_image': <String, dynamic>{
        'id': 10,
        'origin': 'origin.jpg',
        'small': 'small.jpg',
        'medium': 'medium.jpg',
        'large': 'large.jpg',
      },
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
    expect(actor.profileImage?.bestAvailableUrl, 'large.jpg');
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
    'javdb_id': 'javdb-$id',
    'name': '演员$id',
    'alias_name': '',
    'profile_image': null,
    'is_subscribed': isSubscribed,
  };
}
