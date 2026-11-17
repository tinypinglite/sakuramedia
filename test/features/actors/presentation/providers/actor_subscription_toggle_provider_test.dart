import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/session/session_store.dart';
import 'package:sakuramedia/features/actors/presentation/actor_subscription_toggle_result.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_toggle_provider.dart';

import '../../../../support/test_api_bundle.dart';

void main() {
  late SessionStore session;
  late TestApiBundle bundle;
  late ProviderContainer container;
  late List<ActorSubscriptionChange> changes;

  setUp(() async {
    session = SessionStore.inMemory();
    await session.saveBaseUrl('https://api.example.com');
    await session.saveTokens(
      accessToken: 'token',
      refreshToken: 'refresh',
      expiresAt: DateTime(2099),
    );
    bundle = await createTestApiBundle(session);
    container = ProviderContainer(overrides: bundle.riverpodOverrides());
    changes = [];
    container.listen(actorSubscriptionEventsProvider, (_, next) {
      if (next.hasValue) changes.add(next.requireValue);
    });
  });

  tearDown(() {
    container.dispose();
    bundle.dispose();
    session.dispose();
  });

  test('订阅走 PUT 并广播变更，busy 状态在完成后清空', () async {
    bundle.adapter.enqueueJson(
      method: 'PUT',
      path: '/actors/7/subscription',
      statusCode: 204,
    );

    final notifier = container.read(actorSubscriptionToggleProvider.notifier);
    final future = notifier.toggle(actorId: 7, isSubscribed: false);
    expect(container.read(actorSubscriptionToggleProvider), contains(7));

    final result = await future;
    expect(result.status, ActorSubscriptionToggleStatus.subscribed);
    expect(container.read(actorSubscriptionToggleProvider), isEmpty);
    expect(bundle.adapter.hitCount('PUT', '/actors/7/subscription'), 1);
    expect(changes.single.actorId, 7);
    expect(changes.single.isSubscribed, isTrue);
  });

  test('取消订阅走 DELETE 并广播取消', () async {
    bundle.adapter.enqueueJson(
      method: 'DELETE',
      path: '/actors/7/subscription',
      statusCode: 204,
    );

    final result = await container
        .read(actorSubscriptionToggleProvider.notifier)
        .toggle(actorId: 7, isSubscribed: true);

    expect(result.status, ActorSubscriptionToggleStatus.unsubscribed);
    expect(bundle.adapter.hitCount('DELETE', '/actors/7/subscription'), 1);
    expect(changes.single.isSubscribed, isFalse);
  });

  test('busy 中重复请求直接忽略且不重复发请求', () async {
    final held = Completer<void>();
    bundle.adapter.enqueueResponder(
      method: 'PUT',
      path: '/actors/7/subscription',
      responder: (RequestOptions _, dynamic __) async {
        await held.future;
        return ResponseBody.fromBytes(const <int>[], 204);
      },
    );
    final notifier = container.read(actorSubscriptionToggleProvider.notifier);

    final first = notifier.toggle(actorId: 7, isSubscribed: false);
    final second = await notifier.toggle(actorId: 7, isSubscribed: false);
    expect(second.status, ActorSubscriptionToggleStatus.ignored);

    held.complete();
    expect((await first).status, ActorSubscriptionToggleStatus.subscribed);
    expect(bundle.adapter.hitCount('PUT', '/actors/7/subscription'), 1);
  });
}
