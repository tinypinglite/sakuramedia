import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/actors/actor_filter_toolbar.dart';
import 'package:sakuramedia/widgets/actors/actor_summary_grid.dart';

class MobileActorsPage extends StatefulWidget {
  const MobileActorsPage({super.key});

  @override
  State<MobileActorsPage> createState() => _MobileActorsPageState();
}

class _MobileActorsPageState extends State<MobileActorsPage> {
  late final PagedActorSummaryController _actorsController;
  ActorFilterState _filterState = ActorFilterState.initial;

  @override
  void initState() {
    super.initState();
    _actorsController = PagedActorSummaryController(
      fetchPage:
          (page, pageSize) => context.read<ActorsApi>().getActors(
            page: page,
            pageSize: pageSize,
            subscriptionStatus: _filterState.subscriptionStatus,
            gender: _filterState.gender,
          ),
      subscribeActor: context.read<ActorsApi>().subscribeActor,
      unsubscribeActor: context.read<ActorsApi>().unsubscribeActor,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
    );
    _actorsController.attachScrollListener();
    _actorsController.initialize();
  }

  @override
  void dispose() {
    _actorsController.dispose();
    super.dispose();
  }

  void _applyFilter(ActorFilterState nextState) {
    if (nextState.subscriptionStatus == _filterState.subscriptionStatus &&
        nextState.gender == _filterState.gender) {
      return;
    }
    setState(() {
      _filterState = nextState;
    });
    if (_actorsController.scrollController.hasClients) {
      _actorsController.scrollController.jumpTo(0);
    }
    unawaited(_actorsController.reload());
  }

  void _resetFilters() {
    _applyFilter(ActorFilterState.initial);
  }

  Future<void> _toggleActorSubscription(int actorId) async {
    final result = await _actorsController.toggleSubscription(actorId: actorId);
    if (!mounted) {
      return;
    }
    showActorSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.surfaceCard,
      child: SingleChildScrollView(
        controller: _actorsController.scrollController,
        child: AnimatedBuilder(
          animation: _actorsController,
          builder: (context, _) {
            final showFooter =
                _actorsController.items.isNotEmpty &&
                (_actorsController.isLoadingMore ||
                    _actorsController.loadMoreErrorMessage != null);
            return Column(
              key: const Key('mobile-actors-page'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppFilterTotalHeader(
                  leading: ActorFilterToolbar(
                    filterState: _filterState,
                    onChanged: _applyFilter,
                    onReset: _resetFilters,
                  ),
                  totalText: '${_actorsController.total} 位',
                  totalKey: const Key('mobile-actors-page-total'),
                ),
                SizedBox(height: context.appSpacing.md),
                ActorSummaryGrid(
                  items: _actorsController.items,
                  isLoading: _actorsController.isInitialLoading,
                  errorMessage: _actorsController.initialErrorMessage,
                  onActorTap:
                      (actor) => context.push(
                        buildMobileActorDetailRoutePath(actor.id),
                        extra: mobileActorsPath,
                      ),
                  onActorSubscriptionTap:
                      (actor) => _toggleActorSubscription(actor.id),
                  isActorSubscriptionUpdating:
                      (actor) =>
                          _actorsController.isSubscriptionUpdating(actor.id),
                  emptyMessage: '暂无女优数据',
                ),
                if (showFooter) ...[
                  SizedBox(height: context.appSpacing.md),
                  AppPagedLoadMoreFooter(
                    isLoading: _actorsController.isLoadingMore,
                    errorMessage: _actorsController.loadMoreErrorMessage,
                    onRetry: _actorsController.loadMore,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
