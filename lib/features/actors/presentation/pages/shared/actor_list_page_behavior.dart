import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_scope.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_taste_recommendation_rail.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/taste_profile_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/providers/stable_set_selection.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_summary_grid.dart';

/// 女优列表双端共享的 scope、缓存、搜索、筛选、刷新与订阅行为。
///
/// 页面只保留自己的 header 和滚动容器；桌面与移动的刷新差异收敛在
/// [isMobile] 这一个平台维度上。
mixin ActorListPageBehaviorMixin<W extends ConsumerStatefulWidget>
    on ConsumerState<W> {
  late final ScrollController actorScrollController;
  late final TextEditingController actorSearchController;
  final GlobalKey actorListHeaderKey = GlobalKey();

  RiverpodPageHandle? _pageCacheHandle;
  bool _searchExpanded = false;

  ActorSummaryScope get actorScope;

  bool get actorSearchExpanded => _searchExpanded;
  bool get isMobile => actorScope == const ActorSummaryScope.mobile();

  @override
  void initState() {
    super.initState();
    actorScrollController = ScrollController();
    actorSearchController = TextEditingController(
      text:
          ref.read(actorSummaryProvider(actorScope)).value?.filter.query ?? '',
    );
    _pageCacheHandle = ref
        .read(riverpodPageCacheProvider)
        .obtain(
          key: actorScope.cacheKey,
          resolveLinks: () {
            final link = ref
                .read(actorSummaryProvider(actorScope).notifier)
                .cacheLink;
            return link == null ? const [] : [link];
          },
        );
  }

  @override
  void dispose() {
    _pageCacheHandle?.release();
    actorSearchController.dispose();
    actorScrollController.dispose();
    super.dispose();
  }

  PagedViewSnapshot<ActorListItemDto> watchActorSnapshot() {
    return ref.watch(
      actorSummaryProvider(
        actorScope,
      ).select((state) => pagedViewSnapshot(state, (summary) => summary.paged)),
    );
  }

  ActorFilterState watchActorFilter() {
    return ref.watch(
      actorSummaryProvider(
        actorScope,
      ).select((state) => state.value?.filter ?? ActorFilterState.initial),
    );
  }

  StableSetSelection<int> watchActorSubscriptionUpdating() {
    return ref.watch(
      actorSummaryProvider(actorScope).select(
        (state) => StableSetSelection<int>(
          state.value?.subscriptionUpdatingActorIds ?? const <int>{},
        ),
      ),
    );
  }

  bool get canAutoLoadMoreActors =>
      ref.read(actorSummaryProvider(actorScope)).value?.paged.canAutoLoadMore ??
      false;

  Future<void> loadMoreActors() =>
      ref.read(actorSummaryProvider(actorScope).notifier).loadMore();

  void applyActorFilter(ActorFilterState nextState) {
    final current = ref.read(actorSummaryProvider(actorScope)).value?.filter;
    if (current == nextState) {
      return;
    }
    if ((nextState.query ?? '').isEmpty &&
        actorSearchController.text.isNotEmpty) {
      actorSearchController.clear();
    }
    _scrollActorListToStart();
    unawaited(
      ref
          .read(actorSummaryProvider(actorScope).notifier)
          .applyFilter(nextState),
    );
  }

  void applyActorSearchQuery(String value) {
    final current =
        ref.read(actorSummaryProvider(actorScope)).value?.filter ??
        ActorFilterState.initial;
    applyActorFilter(current.withSearchQuery(value));
  }

  void toggleActorSearch() {
    setState(() => _searchExpanded = !_searchExpanded);
  }

  void resetActorFilters() {
    final current =
        ref.read(actorSummaryProvider(actorScope)).value?.filter ??
        ActorFilterState.initial;
    applyActorFilter(current.resetFilters());
  }

  void retryActorFilter() {
    unawaited(
      ref.read(actorSummaryProvider(actorScope).notifier).retryFilter(),
    );
  }

  void _scrollActorListToStart() {
    if (!actorScrollController.hasClients) {
      return;
    }
    if (isMobile && actorListHeaderKey.currentContext != null) {
      AppPinnedListHeader.scrollToStart(
        actorListHeaderKey,
        actorScrollController,
      );
      return;
    }
    actorScrollController.jumpTo(
      actorScrollController.position.minScrollExtent,
    );
  }

  Future<void> refreshActorList() async {
    await Future.wait<void>([
      ref.read(actorSummaryProvider(actorScope).notifier).refresh(),
      ref.read(tasteProfileProvider.notifier).refresh(),
    ]);
  }

  Future<void> toggleActorSubscription(int actorId) async {
    final result = await ref
        .read(actorSummaryProvider(actorScope).notifier)
        .toggleSubscription(actorId);
    if (!mounted) {
      return;
    }
    showActorSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  List<Widget> buildActorListSlivers({
    required PagedViewSnapshot<ActorListItemDto> snapshot,
    required ActorFilterState filter,
    required StableSetSelection<int> subscriptionUpdating,
    required ValueChanged<int> onActorTap,
    Key? sliverGroupKey,
  }) {
    final items = snapshot.items;
    final initialErrorMessage = snapshot.initialError != null
        ? AppLocalizations.of(context).errorActorListLoadFailed
        : null;
    return <Widget>[
      if (!filter.hasActiveFilters)
        SliverToBoxAdapter(
          child: ActorTasteRecommendationRail(onActorTap: onActorTap),
        ),
      SliverMainAxisGroup(
        key: sliverGroupKey,
        slivers: <Widget>[
          if (!snapshot.filterUpdate.hasFailed || items.isNotEmpty)
            AppSkeletonizer.sliver(
              enabled: snapshot.isInitialLoading,
              child: ActorSummarySliver(
                items: snapshot.isInitialLoading
                    ? actorListItemPlaceholders(count: 24)
                    : items,
                errorMessage: initialErrorMessage,
                onErrorRetry: () => unawaited(
                  ref.read(actorSummaryProvider(actorScope).notifier).reload(),
                ),
                onActorTap: (actor) => onActorTap(actor.id),
                onActorSubscriptionTap: (actor) =>
                    toggleActorSubscription(actor.id),
                isActorSubscriptionUpdating: (actor) =>
                    subscriptionUpdating.contains(actor.id),
                emptyMessage: !filter.hasActiveFilters
                    ? AppLocalizations.of(context).actorListEmpty
                    : AppLocalizations.of(context).actorListEmptyFiltered,
              ),
            ),
          // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
          PagedLoadMoreFooterSliver(
            watchFooter: (ref) => ref.watch(
              actorSummaryProvider(actorScope).select(
                (state) => pagedLoadMoreFooterSnapshot(state.value?.paged),
              ),
            ),
            onLoadMore: (ref) => unawaited(loadMoreActors()),
          ),
        ],
      ),
    ];
  }
}
