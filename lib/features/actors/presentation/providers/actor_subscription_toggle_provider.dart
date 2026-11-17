import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/actors/presentation/actor_subscription_toggle_result.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';

part 'actor_subscription_toggle_provider.g.dart';

/// 跨女优列表复用的单片订阅动作：统一请求、行级 busy 状态和变更广播。
///
/// 列表数据仍由各自的 Provider 持有；它们收到 [actorSubscriptionEventsProvider]
/// 后负责按自己的 DTO 结构就地更新订阅态。
@Riverpod(keepAlive: true)
class ActorSubscriptionToggle extends _$ActorSubscriptionToggle {
  @override
  Set<int> build() => const <int>{};

  Future<ActorSubscriptionToggleResult> toggle({
    required int actorId,
    required bool isSubscribed,
  }) async {
    if (actorId <= 0 || state.contains(actorId)) {
      return const ActorSubscriptionToggleResult.ignored();
    }
    state = Set<int>.unmodifiable(<int>{...state, actorId});
    final result = await toggleActorSubscription(
      actorId: actorId,
      isSubscribed: isSubscribed,
      subscribeActor: ref.read(actorsApiProvider).subscribeActor,
      unsubscribeActor: ref.read(actorsApiProvider).unsubscribeActor,
      l10n: ref.read(appLocalizationsProvider),
    );
    if (result.status == ActorSubscriptionToggleStatus.subscribed ||
        result.status == ActorSubscriptionToggleStatus.unsubscribed) {
      ref
          .read(actorSubscriptionEventsProvider.notifier)
          .reportChange(
            actorId: actorId,
            isSubscribed:
                result.status == ActorSubscriptionToggleStatus.subscribed,
          );
    }
    state = Set<int>.unmodifiable(state.where((id) => id != actorId));
    return result;
  }
}
