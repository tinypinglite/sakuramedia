import 'package:flutter/material.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/actors/data/actor_list_item_dto.dart';
import 'package:sakuramedia/features/shared/presentation/paged_load_controller.dart';

typedef ActorSummaryPageFetcher =
    Future<PaginatedResponseDto<ActorListItemDto>> Function(
      int page,
      int pageSize,
    );

typedef ActorSubscriptionWriter = Future<void> Function({required int actorId});

enum ActorSubscriptionToggleStatus { subscribed, unsubscribed, failed, ignored }

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

class PagedActorSummaryController
    extends PagedLoadController<ActorListItemDto> {
  PagedActorSummaryController({
    required ActorSummaryPageFetcher fetchPage,
    required this.subscribeActor,
    required this.unsubscribeActor,
    int initialPage = 1,
    int pageSize = 24,
    double loadMoreTriggerOffset = 300,
    String initialLoadErrorText = '女优列表加载失败，请稍后重试',
    String loadMoreErrorText = '加载更多失败，请点击重试',
    ScrollController? scrollController,
  }) : super(
         fetchPage: fetchPage,
         initialPage: initialPage,
         pageSize: pageSize,
         loadMoreTriggerOffset: loadMoreTriggerOffset,
         initialLoadErrorText: initialLoadErrorText,
         loadMoreErrorText: loadMoreErrorText,
         scrollController: scrollController,
       );

  final ActorSubscriptionWriter subscribeActor;
  final ActorSubscriptionWriter unsubscribeActor;
  final Set<int> _updatingActorIds = <int>{};

  bool isSubscriptionUpdating(int actorId) {
    return _updatingActorIds.contains(actorId);
  }

  Future<ActorSubscriptionToggleResult> toggleSubscription({
    required int actorId,
  }) async {
    final index = mutableItems.indexWhere((item) => item.id == actorId);
    if (index == -1 || _updatingActorIds.contains(actorId)) {
      return const ActorSubscriptionToggleResult.ignored();
    }

    final actor = mutableItems[index];
    _updatingActorIds.add(actorId);
    notifyListenersSafely();

    try {
      if (actor.isSubscribed) {
        await unsubscribeActor(actorId: actorId);
        mutableItems[index] = actor.copyWith(isSubscribed: false);
        return const ActorSubscriptionToggleResult.unsubscribed();
      }

      await subscribeActor(actorId: actorId);
      mutableItems[index] = actor.copyWith(isSubscribed: true);
      return const ActorSubscriptionToggleResult.subscribed();
    } catch (error) {
      return ActorSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: actor.isSubscribed ? '取消订阅女优失败' : '订阅女优失败',
        ),
      );
    } finally {
      _updatingActorIds.remove(actorId);
      notifyListenersSafely();
    }
  }
}
