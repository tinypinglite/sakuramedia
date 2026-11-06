import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/app/providers/riverpod_page_cache_provider.dart';
import 'package:sakuramedia/app/riverpod_page_cache.dart';
import 'package:sakuramedia/core/format/app_number_format.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_list_item_dto.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_filter_options_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_filter_options_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_provider.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_summary_scope.dart';
import 'package:sakuramedia/features/actors/presentation/widgets/actor_taste_recommendation_rail.dart';
import 'package:sakuramedia/features/discovery/presentation/providers/taste_profile_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/providers/stable_set_selection.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_range_section.dart';
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

/// 演员筛选所有 section 的纵向 Column。
///
/// 桌面玻璃筛选浮层和移动 `MobileActorFilterDrawer` 都用它，
/// 避免双份维护。底栏/重置按钮由调用方自己附加。
class ActorFilterSectionGroup extends ConsumerWidget {
  const ActorFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final ActorFilterState filterState;
  final ValueChanged<ActorFilterState> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final optionsScope = ActorFilterOptionsScope(
      subscriptionStatus: filterState.subscriptionStatus,
      gender: filterState.gender,
    );
    final options = ref.watch(actorFilterOptionsProvider(optionsScope));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterOptionSection<ActorSubscriptionStatus>(
          title: l10n.widgetActorFilterSubscriptionTitle,
          options: ActorSubscriptionStatus.values,
          selectedValue: filterState.subscriptionStatus,
          labelBuilder: (value) => value.label(AppLocalizations.of(context)),
          onSelected: (value) =>
              onChanged(filterState.copyWith(subscriptionStatus: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterOptionSection<ActorGender>(
          title: l10n.widgetActorFilterGenderTitle,
          options: ActorGender.values,
          selectedValue: filterState.gender,
          labelBuilder: (value) => value.label(AppLocalizations.of(context)),
          onSelected: (value) => onChanged(filterState.copyWith(gender: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterOptionSection<bool>(
          title: l10n.widgetActorFilterPlayableTitle,
          options: const [false, true],
          selectedValue: filterState.hasPlayableMovies,
          labelBuilder: (value) => value
              ? l10n.widgetActorFilterHasPlayable
              : l10n.widgetActorFilterAll,
          optionKeyBuilder: (value) => Key(
            value ? 'actor-filter-playable-only' : 'actor-filter-playable-all',
          ),
          onSelected: (value) =>
              onChanged(filterState.copyWith(hasPlayableMovies: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        _ActorProfileFilterSectionsAsync(
          options: options,
          filterState: filterState,
          onChanged: onChanged,
          onRetry: () =>
              ref.invalidate(actorFilterOptionsProvider(optionsScope)),
        ),
      ],
    );
  }
}

class _ActorProfileFilterSectionsAsync extends StatefulWidget {
  const _ActorProfileFilterSectionsAsync({
    required this.options,
    required this.filterState,
    required this.onChanged,
    required this.onRetry,
  });

  final AsyncValue<ActorFilterOptionsDto> options;
  final ActorFilterState filterState;
  final ValueChanged<ActorFilterState> onChanged;
  final VoidCallback onRetry;

  @override
  State<_ActorProfileFilterSectionsAsync> createState() =>
      _ActorProfileFilterSectionsAsyncState();
}

class _ActorProfileFilterSectionsAsyncState
    extends State<_ActorProfileFilterSectionsAsync> {
  /// 上一次成功加载的 options。切换订阅 / 性别会创建新的 family 实例，
  /// 新实例没有缓存；沿用旧数据渲染骨架，可以保持与真实内容完全同形。
  ActorFilterOptionsDto? _lastOptions;

  Widget _buildProfileSections(
    BuildContext context, {
    required ActorFilterOptionsDto options,
    required ValueChanged<ActorFilterState> onChanged,
  }) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActorNumericRangeFilterSection(
          title: l10n.widgetActorAgeLabel,
          range: options.age,
          suffix: l10n.widgetActorAgeUnit,
          selectedMin: widget.filterState.ageMin,
          selectedMax: widget.filterState.ageMax,
          onChanged: (range) => onChanged(
            widget.filterState.copyWith(ageMin: range.$1, ageMax: range.$2),
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        ActorNumericRangeFilterSection(
          title: l10n.widgetActorHeightLabel,
          range: options.heightCm,
          suffix: ' cm',
          selectedMin: widget.filterState.heightMin,
          selectedMax: widget.filterState.heightMax,
          onChanged: (range) => onChanged(
            widget.filterState.copyWith(
              heightMin: range.$1,
              heightMax: range.$2,
            ),
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        ActorCupFilterSection(
          options: options.cups,
          selectedCups: widget.filterState.cups,
          onChanged: (cups) =>
              onChanged(widget.filterState.copyWith(cups: cups)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.options.value;
    if (data != null) {
      _lastOptions = data;
    }
    return widget.options.when(
      data: (value) => _buildProfileSections(
        context,
        options: value,
        onChanged: widget.onChanged,
      ),
      loading: () => AppSkeletonizer(
        child: _buildProfileSections(
          context,
          options: _lastOptions ?? actorFilterOptionsPlaceholder(),
          onChanged: (_) {},
        ),
      ),
      error: (_, _) => _ActorProfileFilterOptionsMessage(
        message: AppLocalizations.of(
          context,
        ).widgetActorFilterOptionsLoadFailed,
        onRetry: widget.onRetry,
      ),
    );
  }
}

class _ActorProfileFilterOptionsMessage extends StatelessWidget {
  const _ActorProfileFilterOptionsMessage({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          message,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        if (onRetry != null) ...[
          SizedBox(width: context.appSpacing.sm),
          AppTextButton(
            label: AppLocalizations.of(context).commonRetry,
            size: AppTextButtonSize.xSmall,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}

class ActorNumericRangeFilterSection extends StatelessWidget {
  const ActorNumericRangeFilterSection({
    super.key,
    required this.title,
    required this.range,
    required this.suffix,
    required this.selectedMin,
    required this.selectedMax,
    required this.onChanged,
  });

  final String title;
  final ActorFilterRangeDto range;
  final String suffix;
  final int? selectedMin;
  final int? selectedMax;
  final ValueChanged<(int?, int?)> onChanged;

  bool get _hasValues => range.hasValues;

  RangeValues get _values {
    if (!_hasValues) {
      return const RangeValues(0, 0);
    }
    final lower = range.min!;
    final upper = range.max!;
    final start = (selectedMin ?? lower).clamp(lower, upper).toDouble();
    final end = (selectedMax ?? upper).clamp(lower, upper).toDouble();
    return start <= end
        ? RangeValues(start, end)
        : RangeValues(lower.toDouble(), upper.toDouble());
  }

  void _apply(RangeValues values) {
    final lower = range.min!;
    final upper = range.max!;
    final nextMin = values.start.round() <= lower ? null : values.start.round();
    final nextMax = values.end.round() >= upper ? null : values.end.round();
    if (nextMin != selectedMin || nextMax != selectedMax) {
      onChanged((nextMin, nextMax));
    }
  }

  String _rangeLabel(AppLocalizations l10n, RangeValues values) {
    final lower = values.start.round();
    final upper = values.end.round();
    final min = range.min;
    final max = range.max;
    if (min == null || max == null || (lower == min && upper == max)) {
      return l10n.widgetActorFilterUnlimited;
    }
    if (lower == min) {
      return '≤ $upper$suffix';
    }
    if (upper == max) {
      return '≥ $lower$suffix';
    }
    return '$lower ~ $upper$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_hasValues) {
      return Text(
        l10n.widgetActorFilterNoProfileData(title),
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.medium,
          tone: AppTextTone.muted,
        ),
      );
    }
    if (range.min == range.max) {
      return Text(
        '$title ${range.min}$suffix',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.medium,
          tone: AppTextTone.secondary,
        ),
      );
    }
    return AppFilterRangeSection(
      title: title,
      values: _values,
      min: range.min!.toDouble(),
      max: range.max!.toDouble(),
      valueLabelBuilder: (values) => _rangeLabel(l10n, values),
      minLabel: '${range.min}$suffix',
      maxLabel: '${range.max}$suffix',
      sliderKey: Key('actor-filter-$title-slider'),
      onChangeEnd: _apply,
    );
  }
}

class ActorCupFilterSection extends StatelessWidget {
  const ActorCupFilterSection({
    super.key,
    required this.options,
    required this.selectedCups,
    required this.onChanged,
  });

  final List<ActorCupFilterOptionDto> options;
  final List<String> selectedCups;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.widgetActorCupLabel,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        if (options.isEmpty)
          Text(
            l10n.widgetActorFilterNoData,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          )
        else
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.sm,
            children: options
                .map(
                  (option) => AppFilterChip(
                    label: '${option.value} (${formatAppCount(option.count)})',
                    selected: selectedCups.contains(option.value),
                    onPressed: () {
                      final next = Set<String>.of(selectedCups);
                      if (!next.add(option.value)) {
                        next.remove(option.value);
                      }
                      final cups = next.toList()..sort();
                      onChanged(cups);
                    },
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}
