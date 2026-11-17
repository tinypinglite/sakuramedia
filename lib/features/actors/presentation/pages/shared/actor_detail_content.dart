import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_detail_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_movie_year_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_subscription_toggle_result.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_detail_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_mutation_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_removal_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_subscription_events_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_tag_filter_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actors_api_provider.dart';
import 'package:sakuramedia/features/actors/presentation/pages/shared/actor_detail_chrome.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_merge_dialog.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_profile_editor.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_tag_filter_menu_button.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/pages/mobile/movie_filter_drawer.dart';
import 'package:sakuramedia/features/movies/presentation/pages/shared/movie_summary_list_content.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/features/tags/presentation/providers/tag_selection_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_sort_menu_button.dart';
import 'package:sakuramedia/widgets/domain/tags/media_tag_filter_section.dart';

class ActorDetailContent extends ConsumerStatefulWidget {
  const ActorDetailContent({
    super.key,
    required this.actorId,
    required this.mobile,
    required this.onMovieTap,
    this.onRefreshFailure,
  });

  final int actorId;
  final bool mobile;
  final void Function(BuildContext context, String movieNumber) onMovieTap;
  final void Function(BuildContext context)? onRefreshFailure;

  @override
  ConsumerState<ActorDetailContent> createState() => _ActorDetailContentState();
}

class _ActorDetailContentState extends ConsumerState<ActorDetailContent> {
  List<MovieFilterYearOption> _movieYearOptions =
      const <MovieFilterYearOption>[];
  bool _hasLoadedMovieYears = false;
  bool _isMovieYearsLoading = false;
  String? _movieYearsErrorMessage;
  bool? _isActorSubscribedOverride;
  bool _isActorSubscriptionUpdating = false;

  MovieSummaryScope get _scope =>
      MovieSummaryScope.actor(actorId: widget.actorId);

  /// 标签选择变化后重拉作品列表：有选择走 tag 条件，清空则回到无标签请求。
  void _applyTagSelection(TagSelectionState selection) {
    final notifier = ref.read(movieSummaryProvider(_scope).notifier);
    if (selection.hasSelection) {
      unawaited(
        notifier.applyTagFilter(
          tagIds: selection.selectedTagIds,
          tagMatch: selection.matchMode,
        ),
      );
    } else {
      unawaited(notifier.clearTagFilter());
    }
  }

  void _loadMovieYearsIfNeeded() {
    if (_hasLoadedMovieYears || _isMovieYearsLoading) {
      return;
    }
    unawaited(_loadMovieYears());
  }

  Future<void> _loadMovieYears({bool force = false}) async {
    if (_isMovieYearsLoading || (_hasLoadedMovieYears && !force)) {
      return;
    }
    setState(() {
      _isMovieYearsLoading = true;
      _movieYearsErrorMessage = null;
    });

    try {
      final years = await ref
          .read(actorsApiProvider)
          .getActorMovieYears(actorId: widget.actorId);
      if (!mounted) {
        return;
      }
      setState(() {
        _movieYearOptions = years
            .map(_toFilterYearOption)
            .toList(growable: false);
        _hasLoadedMovieYears = true;
        _isMovieYearsLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isMovieYearsLoading = false;
        _movieYearsErrorMessage = AppLocalizations.of(
          context,
        ).actorMovieYearsLoadFailed;
      });
    }
  }

  MovieFilterYearOption _toFilterYearOption(ActorMovieYearDto item) {
    return MovieFilterYearOption(year: item.year, movieCount: item.movieCount);
  }

  Future<void> _toggleActorSubscription({required bool isSubscribed}) async {
    if (_isActorSubscriptionUpdating) {
      return;
    }

    final l10n = AppLocalizations.of(context);
    setState(() {
      _isActorSubscriptionUpdating = true;
    });

    ActorSubscriptionToggleResult result;

    try {
      if (isSubscribed) {
        await ref
            .read(actorsApiProvider)
            .unsubscribeActor(actorId: widget.actorId);
        result = const ActorSubscriptionToggleResult.unsubscribed();
        _isActorSubscribedOverride = false;
      } else {
        await ref
            .read(actorsApiProvider)
            .subscribeActor(actorId: widget.actorId);
        result = const ActorSubscriptionToggleResult.subscribed();
        _isActorSubscribedOverride = true;
      }
    } catch (error) {
      result = ActorSubscriptionToggleResult.failed(
        message: apiErrorMessage(
          error,
          fallback: isSubscribed
              ? l10n.actorUnsubscribeFailed
              : l10n.actorSubscribeFailed,
          l10n: l10n,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    if (result.status == ActorSubscriptionToggleStatus.subscribed ||
        result.status == ActorSubscriptionToggleStatus.unsubscribed) {
      ref
          .read(actorSubscriptionEventsProvider.notifier)
          .reportChange(
            actorId: widget.actorId,
            isSubscribed:
                result.status == ActorSubscriptionToggleStatus.subscribed,
          );
    }

    setState(() {
      _isActorSubscriptionUpdating = false;
    });
    showActorSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  Future<void> _openActorEditor(ActorDetailDto actor) async {
    final updated = await showActorProfileEditor(
      context,
      actor: actor,
      api: ref.read(actorsApiProvider),
    );
    if (!mounted || updated == null) {
      return;
    }
    ref
        .read(actorDetailProvider(widget.actorId).notifier)
        .replaceActor(updated);
    ref
        .read(actorMutationEventsProvider.notifier)
        .reportUpdated(updated.summary);
  }

  Future<void> _openActorMerger(ActorDetailDto actor) async {
    final result = await showActorMergeDialog(
      context,
      actor: actor,
      api: ref.read(actorsApiProvider),
    );
    if (!mounted || result == null) {
      return;
    }
    ref
        .read(actorDetailProvider(widget.actorId).notifier)
        .replaceActor(result.actor);
    ref
        .read(actorMutationEventsProvider.notifier)
        .reportUpdated(result.actor.summary);
    ref
        .read(actorRemovalEventsProvider.notifier)
        .reportRemoved(result.sourceActorIds);
    // 影片归属发生变化：重拉作品列表与懒加载的年份筛选。
    ref.invalidate(movieSummaryProvider(_scope));
    ref.invalidate(actorTagFilterProvider(widget.actorId));
    setState(() {
      _hasLoadedMovieYears = false;
      _movieYearOptions = const <MovieFilterYearOption>[];
    });
    showToast(
      AppLocalizations.of(
        context,
      ).actorMergeCompleted(result.sourceActorIds.length),
      tone: AppToastTone.success,
    );
  }

  /// 影片区顶栏：桌面玻璃分组，移动端紧凑图标行。
  /// 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
  ///
  /// 数量属于当前作品筛选结果，随作品列表一起展示。
  Widget _buildFilterHeader(
    BuildContext context,
    MovieSummaryListHeaderArgs args,
  ) {
    final l10n = AppLocalizations.of(context);
    final filterState = args.filterState;
    final totalLabel = l10n.actorMovieCountLabel(args.total);
    final showTotal = ref.read(movieSummaryProvider(_scope)).hasValue;
    if (widget.mobile) {
      return AppMobileListHeader(
        leading: showTotal ? AppMobileHeaderText(countLabel: totalLabel) : null,
        actions: <Widget>[
          AppGlassFilterIconButton(
            key: const Key('actor-detail-filter-trigger'),
            summary: filterState.triggerLabel(l10n),
            isActive: filterState.hasActiveFilters,
            onPressed: () =>
                unawaited(_openFilterDrawer(filterState, args.onApply)),
          ),
          ActorTagFilterMenuButton(
            actorId: widget.actorId,
            triggerKey: const Key('actor-detail-tag-filter-trigger'),
            panelKey: const Key('actor-detail-tag-filter-panel'),
            drawerKey: const Key('mobile-actor-detail-tag-filter-drawer'),
            useDrawer: true,
          ),
          MovieSortMenuButton(
            triggerKey: const Key('actor-detail-sort-trigger'),
            drawerKey: const Key('mobile-actor-detail-sort-drawer'),
            filterState: filterState,
            onChanged: args.onApply,
            useDrawer: true,
            iconOnly: true,
          ),
        ],
        filterUpdate: args.filterUpdate,
        hasPreviousFilterItems: args.total > 0,
        onRetryFilter: args.onRetryFilter,
      );
    }
    return AppGlassListHeader(
      leading: AppGlassFilterPopover(
        panelKey: const Key('actor-detail-filter-panel'),
        scrollable: true,
        isDefault: !filterState.hasActiveFilters,
        onReset: () => args.onApply(filterState.resetFilters()),
        triggerKey: const Key('actor-detail-filter-trigger'),
        label: filterState.triggerLabel(l10n),
        onBeforeOpen: _loadMovieYearsIfNeeded,
        info: [if (showTotal) AppGlassHeaderText(label: totalLabel)],
        panelBuilder: (context) => MovieFilterSectionGroup(
          filterState: filterState,
          onChanged: args.onApply,
          showActorAgeSection: false,
          mediaTagSection: MediaTagFilterSection(
            filter: filterState,
            onChanged: args.onApply,
          ),
          yearOptions: _movieYearOptions,
          isYearOptionsLoading: _isMovieYearsLoading,
          yearOptionsErrorMessage: _movieYearsErrorMessage,
          onYearOptionsRetry: () => unawaited(_loadMovieYears(force: true)),
        ),
      ),
      trailing: AppGlassHeaderGroup(
        children: <Widget>[
          ActorTagFilterMenuButton(
            actorId: widget.actorId,
            triggerKey: const Key('actor-detail-tag-filter-trigger'),
            panelKey: const Key('actor-detail-tag-filter-panel'),
            drawerKey: const Key('mobile-actor-detail-tag-filter-drawer'),
            glassGrouped: true,
          ),
          MovieSortMenuButton(
            triggerKey: const Key('actor-detail-sort-trigger'),
            drawerKey: const Key('mobile-actor-detail-sort-drawer'),
            filterState: filterState,
            onChanged: args.onApply,
            glassGrouped: true,
          ),
          if (args.onEnterSelection != null)
            AppGlassHeaderButton(
              key: const Key('actor-detail-enter-selection-button'),
              icon: Icons.check_circle_outline,
              label: l10n.baseSelect,
              onTap: args.onEnterSelection!,
            ),
        ],
      ),
      filterUpdate: args.filterUpdate,
      hasPreviousFilterItems: args.total > 0,
      onRetryFilter: args.onRetryFilter,
    );
  }

  Future<void> _openFilterDrawer(
    MovieFilterState current,
    ValueChanged<MovieFilterState> onApply,
  ) async {
    // 年份是懒加载的，而抽屉内容是**打开那一刻的快照**（不像桌面浮层会随
    // didUpdateWidget 重建）。所以这里先把年份取回来再弹，否则抽屉里的年份分节
    // 会永远停在转圈状态。只有首次点击会等这一次请求。
    if (!_hasLoadedMovieYears) {
      await _loadMovieYears();
    }
    if (!mounted) {
      return;
    }
    await showMobileMovieFilterDrawer(
      context,
      current: current,
      onChanged: onApply,
      showActorAgeSection: false,
      mediaTagSectionBuilder: (context, local, onApply) =>
          MediaTagFilterSection(filter: local, onChanged: onApply),
      yearOptions: _movieYearOptions,
      yearOptionsErrorMessage: _movieYearsErrorMessage,
      onYearOptionsRetry: () => unawaited(_loadMovieYears(force: true)),
    );
  }

  Future<void> _handleRefresh() async {
    try {
      await Future.wait<void>([
        ref.read(actorDetailProvider(widget.actorId).notifier).refresh(),
        ref.read(movieSummaryProvider(_scope).notifier).refresh(),
        if (_hasLoadedMovieYears) _loadMovieYears(force: true),
      ]);
      // 手势刷新成功计一次浏览（与 movie 详情页一致；provider 的 refresh
      // 自身不上报，避免后台同步顶进「最近浏览」）。
      ref.read(actorDetailProvider(widget.actorId).notifier).reportView();
      if (mounted) {
        setState(() {
          _isActorSubscribedOverride = null;
        });
      }
    } catch (_) {
      if (mounted) {
        final onRefreshFailure = widget.onRefreshFailure;
        if (onRefreshFailure != null) {
          onRefreshFailure(context);
        } else {
          showToast(
            AppLocalizations.of(context).actorRefreshFailed,
            tone: AppToastTone.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actorAsync = ref.watch(actorDetailProvider(widget.actorId));
    final actorState = actorAsync.value;
    // 保持作品列表与女优详情并行首拉；loading/error 外壳仍由本页先接管。
    ref.watch(movieSummaryProvider(_scope).select((state) => state.hasValue));
    ref.listen(actorTagFilterProvider(widget.actorId), (previous, next) {
      if (previous == null) {
        return;
      }
      if (listEquals(previous.selectedTagIds, next.selectedTagIds) &&
          previous.matchMode == next.matchMode) {
        return;
      }
      _applyTagSelection(next);
    });
    final mobile = widget.mobile;
    final sectionSpacing = mobile
        ? context.appSpacing.md
        : context.appSpacing.lg;
    final Widget content;
    if (actorAsync.isLoading && actorState?.actor == null) {
      content = ActorDetailLoadingBody(mobile: mobile);
    } else if (actorState?.errorMessage != null || actorState?.actor == null) {
      content = ActorDetailErrorBody(
        mobile: mobile,
        message:
            actorState?.errorMessage ??
            AppLocalizations.of(context).actorDetailLoadFailed,
        onRetry: () => unawaited(
          ref.read(actorDetailProvider(widget.actorId).notifier).reload(),
        ),
      );
    } else {
      final actor = actorState!.actor!;
      final isActorSubscribed =
          _isActorSubscribedOverride ?? actor.summary.isSubscribed;
      content = MovieSummaryListContent(
        scope: _scope,
        surfaceColor: mobile
            ? context.appColors.surfaceCard
            : context.appColors.surfacePage,
        contentKey: Key(
          mobile ? 'mobile-actor-detail-page' : 'actor-detail-page',
        ),
        sectionSpacing: sectionSpacing,
        batchKeyPrefix: 'actor-detail',
        emptyMessage: AppLocalizations.of(context).actorMoviesEmpty,
        onMovieTap: widget.onMovieTap,
        bodyBuilder: (context, scrollController, child, onRefresh) =>
            ActorDetailPageBody(
              mobile: mobile,
              scrollController: scrollController,
              onRefresh: onRefresh,
              child: child,
            ),
        enableRefresh: mobile,
        onRefreshOverride: _handleRefresh,
        usePinnedMobileHeader: true,
        useMobileSelectionLayout: mobile,
        showHeaderLeadingInSelection: true,
        headerLeading: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ActorDetailHeader(
              mobile: mobile,
              actor: actor,
              isSubscribed: isActorSubscribed,
              isSubscriptionUpdating: _isActorSubscriptionUpdating,
              onSubscriptionTap: _isActorSubscriptionUpdating
                  ? null
                  : () => _toggleActorSubscription(
                      isSubscribed: isActorSubscribed,
                    ),
              onEditTap: () => unawaited(_openActorEditor(actor)),
              onMergeTap: () => unawaited(_openActorMerger(actor)),
            ),
            SizedBox(height: sectionSpacing),
          ],
        ),
        headerBuilder: _buildFilterHeader,
      );
    }
    return AppPageRefreshScope(onRefresh: _handleRefresh, child: content);
  }
}
