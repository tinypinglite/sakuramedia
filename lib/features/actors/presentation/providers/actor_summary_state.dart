import 'package:flutter/foundation.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

@immutable
class ActorSummaryState {
  const ActorSummaryState({
    required this.paged,
    required this.filter,
    this.subscriptionUpdatingActorIds = const <int>{},
  });

  final PagedListState<ActorListItemDto> paged;
  final ActorFilterState filter;
  final Set<int> subscriptionUpdatingActorIds;

  bool isSubscriptionUpdating(int actorId) =>
      subscriptionUpdatingActorIds.contains(actorId);

  ActorSummaryState copyWith({
    PagedListState<ActorListItemDto>? paged,
    ActorFilterState? filter,
    Set<int>? subscriptionUpdatingActorIds,
  }) {
    return ActorSummaryState(
      paged: paged ?? this.paged,
      filter: filter ?? this.filter,
      subscriptionUpdatingActorIds: Set<int>.unmodifiable(
        subscriptionUpdatingActorIds ?? this.subscriptionUpdatingActorIds,
      ),
    );
  }
}
