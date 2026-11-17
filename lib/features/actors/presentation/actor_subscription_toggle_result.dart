import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

typedef ActorSubscriptionWriter = Future<void> Function({required int actorId});

enum ActorSubscriptionToggleStatus { subscribed, unsubscribed, failed, ignored }

/// 演员订阅写操作的 UI 反馈值。
///
/// 独立于任何列表控制器：演员列表、演员详情与目录搜索均可复用，避免缓存页
/// Riverpod 化后无需为了这个小型值对象保留旧分页控制器。
class ActorSubscriptionToggleResult {
  const ActorSubscriptionToggleResult({required this.status, this.message});

  const ActorSubscriptionToggleResult.subscribed()
    : this(status: ActorSubscriptionToggleStatus.subscribed);

  const ActorSubscriptionToggleResult.unsubscribed()
    : this(status: ActorSubscriptionToggleStatus.unsubscribed);

  const ActorSubscriptionToggleResult.failed({required String message})
    : this(status: ActorSubscriptionToggleStatus.failed, message: message);

  const ActorSubscriptionToggleResult.ignored()
    : this(status: ActorSubscriptionToggleStatus.ignored);

  final ActorSubscriptionToggleStatus status;
  final String? message;
}

/// 保持原控制器的错误文案与成功后才翻转状态的时序。
///
/// [l10n] 提供当前语言的失败兜底文案。
Future<ActorSubscriptionToggleResult> toggleActorSubscription({
  required int actorId,
  required bool isSubscribed,
  required ActorSubscriptionWriter subscribeActor,
  required ActorSubscriptionWriter unsubscribeActor,
  required AppLocalizations l10n,
}) async {
  try {
    if (isSubscribed) {
      await unsubscribeActor(actorId: actorId);
      return const ActorSubscriptionToggleResult.unsubscribed();
    }
    await subscribeActor(actorId: actorId);
    return const ActorSubscriptionToggleResult.subscribed();
  } catch (error) {
    return ActorSubscriptionToggleResult.failed(
      message: apiErrorMessage(
        error,
        fallback: isSubscribed
            ? l10n.actorUnsubscribeFailed
            : l10n.actorSubscribeFailed,
        l10n: l10n,
      ),
    );
  }
}
