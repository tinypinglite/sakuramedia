import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/app/language/providers/app_localizations_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
import 'package:sakuramedia/features/discovery/data/taste_profile_dto.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/discovery_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/session_scoped_invalidation.dart';

part 'taste_profile_provider.g.dart';

/// 口味画像：发现页与女优页共用一份，订阅变更由事件广播就地补丁。
@Riverpod(keepAlive: true, retry: kNoAsyncNotifierRetry)
class TasteProfile extends _$TasteProfile
    with AsyncNotifierDisposeGuardMixin<TasteProfileDto> {
  @override
  Future<TasteProfileDto> build() async {
    invalidateOnSignOut(ref);
    attachDisposeGuard();
    // 订阅广播只在这里接一次，所有口味面板共享同一份补丁结果。
    ref.listen(actorSubscriptionEventsProvider, (_, next) {
      final change = next.value;
      if (change == null) return;
      applySubscription(
        actorId: change.actorId,
        isSubscribed: change.isSubscribed,
      );
    });
    return ref.read(discoveryApiProvider).getTasteProfile();
  }

  /// 下拉刷新保留已呈现的画像；失败返回提示文案，不打断同页其它区块。
  Future<String?> refresh() async {
    final current = state.value;
    if (current == null) {
      final next = await AsyncValue.guard(
        () => ref.read(discoveryApiProvider).getTasteProfile(),
      );
      if (!isDisposed) {
        state = next;
      }
      return state.hasError
          ? ref.apiErrorMessage(
              state.error!,
              fallback: ref
                  .read(appLocalizationsProvider)
                  .errorTasteProfileLoadFailed,
            )
          : null;
    }
    try {
      final next = await ref.read(discoveryApiProvider).getTasteProfile();
      if (!isDisposed) {
        state = AsyncData(next);
      }
      return null;
    } catch (error) {
      return ref.apiErrorMessage(
        error,
        fallback: ref
            .read(appLocalizationsProvider)
            .errorTasteProfileLoadFailed,
      );
    }
  }

  void applySubscription({required int actorId, required bool isSubscribed}) {
    if (isDisposed) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.applySubscription(actorId: actorId, isSubscribed: isSubscribed),
    );
  }
}
