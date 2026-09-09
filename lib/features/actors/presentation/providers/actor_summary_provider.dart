import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sakuramedia/core/network/paginated_response_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_subscription_toggle_result.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_scope.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/async_notifier_dispose_guard.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';

part 'actor_summary_provider.g.dart';

/// 缓存页（桌面 / 移动演员列表）共用的 autoDispose family。
///
/// provider 默认随无监听者释放；页面在 `initState` 通过
/// [cacheLink] 交给 `RiverpodPageCache`，从而精确复刻旧的「LRU 24 + 登出
/// 清空」寿命，而不是把列表无限常驻在 ProviderScope 里。
@Riverpod(retry: kNoAsyncNotifierRetry)
class ActorSummary extends _$ActorSummary
    with
        PagedAsyncNotifierMixin<ActorSummaryState, ActorListItemDto>,
        FilterablePagedAsyncNotifierMixin<
          ActorSummaryState,
          ActorListItemDto,
          ActorFilterState
        > {
  KeepAliveLink? _cacheLink;

  /// 仅供页面缓存收集。build 在首个 await 前同步赋值，故页面初始化期间可读。
  KeepAliveLink? get cacheLink => _cacheLink;

  @override
  int get pageSize => 24;

  @override
  String get initialLoadErrorText => '女优列表加载失败，请稍后重试';

  @override
  String get loadMoreErrorText => '加载更多失败，请点击重试';

  @override
  ActorFilterState get initialFilter => ActorFilterState.initial;

  @override
  PagedListState<ActorListItemDto> pagedOf(ActorSummaryState state) =>
      state.paged;

  @override
  ActorSummaryState applyPaged(
    ActorSummaryState state,
    PagedListState<ActorListItemDto> paged,
  ) => state.copyWith(paged: paged);

  @override
  ActorSummaryState applyFilterToState(
    ActorSummaryState state,
    ActorFilterState filter,
  ) => state.copyWith(filter: filter);

  @override
  Future<ActorSummaryState> build(ActorSummaryScope scope) async {
    // `reload()` 在初始 AsyncError 时会 `invalidateSelf()`；同一个缓存实例重跑
    // build 时必须复用首个 link，不能每次 retry 新建一个而让 LRU 只持有旧 link。
    _cacheLink ??= ref.keepAlive();
    attachDisposeGuard();
    final paged = await loadInitialPage();
    return ActorSummaryState(paged: paged, filter: activeFilter);
  }

  @override
  Future<PaginatedResponseDto<ActorListItemDto>> fetchPage(
    int page,
    int pageSize,
  ) {
    final filter = activeFilter;
    return ref
        .read(actorsApiProvider)
        .getActors(
          page: page,
          pageSize: pageSize,
          subscriptionStatus: filter.subscriptionStatus,
          gender: filter.gender,
          ageMin: filter.ageMin,
          ageMax: filter.ageMax,
          heightMin: filter.heightMin,
          heightMax: filter.heightMax,
          cups: filter.cups,
          sort: filter.sortExpression,
        );
  }

  Future<void> applyFilter(ActorFilterState filter) {
    return applyFilterState(filter);
  }

  /// 先将这一行置 busy，服务端成功后才写回订阅态，保留旧控制器的交互时序。
  Future<ActorSubscriptionToggleResult> toggleSubscription(int actorId) async {
    final current = state.value;
    final actor = current?.paged.items
        .where((item) => item.id == actorId)
        .firstOrNull;
    if (actor == null || current!.isSubscriptionUpdating(actorId)) {
      return const ActorSubscriptionToggleResult.ignored();
    }

    _setSubscriptionUpdating(actorId, true);
    final result = await toggleActorSubscription(
      actorId: actorId,
      isSubscribed: actor.isSubscribed,
      subscribeActor: ref.read(actorsApiProvider).subscribeActor,
      unsubscribeActor: ref.read(actorsApiProvider).unsubscribeActor,
    );
    if (isDisposed) {
      return const ActorSubscriptionToggleResult.ignored();
    }
    if (result.status == ActorSubscriptionToggleStatus.subscribed ||
        result.status == ActorSubscriptionToggleStatus.unsubscribed) {
      _patchSubscription(
        actorId,
        result.status == ActorSubscriptionToggleStatus.subscribed,
      );
    }
    _setSubscriptionUpdating(actorId, false);
    return result;
  }

  void _patchSubscription(int actorId, bool isSubscribed) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final paged = current.paged.patchWhere(
      (actor) => actor.id == actorId,
      (actor) => actor.copyWith(isSubscribed: isSubscribed),
    );
    if (identical(paged, current.paged)) {
      return;
    }
    state = AsyncData(current.copyWith(paged: paged));
  }

  void _setSubscriptionUpdating(int actorId, bool updating) {
    final current = state.value;
    if (current == null) {
      return;
    }
    final next = Set<int>.of(current.subscriptionUpdatingActorIds);
    final changed = updating ? next.add(actorId) : next.remove(actorId);
    if (!changed) {
      return;
    }
    state = AsyncData(current.copyWith(subscriptionUpdatingActorIds: next));
  }
}
