import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/app/cached_page_state_handle.dart';
import 'package:sakuramedia/app/app_page_state_cache_keys.dart';
import 'package:sakuramedia/features/actors/data/actors_api.dart';
import 'package:sakuramedia/features/actors/presentation/actor_list_page_state.dart';
import 'package:sakuramedia/features/actors/presentation/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/paged_actor_summary_controller.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actors/actor_filter_toolbar.dart';
import 'package:sakuramedia/widgets/actors/actor_summary_grid.dart';

class DesktopActorsPage extends StatefulWidget {
  const DesktopActorsPage({super.key});

  @override
  State<DesktopActorsPage> createState() => _DesktopActorsPageState();
}

class _DesktopActorsPageState extends State<DesktopActorsPage> {
  late final CachedPageStateHandle<ActorListPageStateEntry> _pageStateHandle;

  ActorListPageStateEntry get _pageState => _pageStateHandle.value;

  PagedActorSummaryController get _actorsController => _pageState.controller;
  ActorFilterState get _filterState => _pageState.filterState;

  @override
  void initState() {
    super.initState();
    _pageStateHandle = obtainCachedPageState<ActorListPageStateEntry>(
      context,
      key: desktopActorsPageStateKey(),
      create:
          () => ActorListPageStateEntry(actorsApi: context.read<ActorsApi>()),
    );
  }

  @override
  void dispose() {
    _pageStateHandle.dispose();
    super.dispose();
  }

  void _applyFilter(ActorFilterState nextState) {
    if (nextState.subscriptionStatus == _filterState.subscriptionStatus &&
        nextState.gender == _filterState.gender &&
        nextState.sortField == _filterState.sortField &&
        nextState.sortDirection == _filterState.sortDirection) {
      return;
    }
    setState(() {
      _pageState.filterState = nextState;
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
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _actorsController.scrollController,
        child: AnimatedBuilder(
          animation: _actorsController,
          builder: (context, _) {
            final footer = _buildLoadMoreFooter(context);
            return Column(
              key: const Key('actors-page'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActorsHeader(
                  total: _actorsController.total,
                  filterState: _filterState,
                  onFilterChanged: _applyFilter,
                  onResetFilters: _resetFilters,
                ),
                SizedBox(height: context.appSpacing.lg),
                ActorSummaryGrid(
                  items: _actorsController.items,
                  isLoading: _actorsController.isInitialLoading,
                  errorMessage: _actorsController.initialErrorMessage,
                  onActorTap:
                      (actor) => context.pushDesktopActorDetail(
                        actorId: actor.id,
                        fallbackPath: desktopActorsPath,
                      ),
                  onActorSubscriptionTap:
                      (actor) => _toggleActorSubscription(actor.id),
                  isActorSubscriptionUpdating:
                      (actor) =>
                          _actorsController.isSubscriptionUpdating(actor.id),
                  emptyMessage: '暂无女优数据',
                ),
                if (footer != null) ...[
                  SizedBox(height: context.appSpacing.md),
                  footer,
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget? _buildLoadMoreFooter(BuildContext context) {
    if (_actorsController.items.isEmpty) {
      return null;
    }

    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    if (_actorsController.isLoadingMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.md),
          child: SizedBox(
            width: componentTokens.movieCardLoaderSize,
            height: componentTokens.movieCardLoaderSize,
            child: CircularProgressIndicator(
              strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (_actorsController.loadMoreErrorMessage == null) {
      return null;
    }

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: componentTokens.iconSizeXl,
                color: context.appTextPalette.secondary,
              ),
              SizedBox(width: spacing.sm),
              Text(
                _actorsController.loadMoreErrorMessage!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(width: spacing.sm),
              TextButton(
                onPressed: _actorsController.loadMore,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.sm,
                    vertical: spacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActorsHeader extends StatelessWidget {
  const _ActorsHeader({
    required this.total,
    required this.filterState,
    required this.onFilterChanged,
    required this.onResetFilters,
  });

  final int total;
  final ActorFilterState filterState;
  final ValueChanged<ActorFilterState> onFilterChanged;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ActorFilterToolbar(
          filterState: filterState,
          onChanged: onFilterChanged,
          onReset: onResetFilters,
        ),
        const Spacer(),
        Text(
          '$total 位',
          key: const Key('actors-page-total'),
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          ),
        ),
      ],
    );
  }
}
