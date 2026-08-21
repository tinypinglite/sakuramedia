import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart' show HookConsumerWidget;
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_list_item_dto.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/features/subscriptions/presentation/movie_subscription_filter_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_state.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/features/subscriptions/presentation/widgets/movie_subscription_filter_sections.dart';
import 'package:sakuramedia/features/subscriptions/presentation/widgets/movie_subscription_row.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_notice_card.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_magnet_search_dialog.dart';

/// 订阅管理页的列表主体：顶栏（筛选 / 计数 / 操作）+ 行卡片列表。
///
/// **本页只有桌面端**——订阅管理是运维视图，移动端不提供入口，所以这里不做双端分流：
/// 筛选走桌面就地浮层，多选态用 [AppSelectionHeaderToolbar] 原地改写整行。真要补移动端
/// 时，参考 videos / actors 的做法（`onFilterTap` 弹底部抽屉 + `AppListHeader.selection`
/// + 贴底 `AppSelectionBottomBar`），别在这里留没有调用方的分支。
///
/// 状态分段签不在这里——它归页面，固定在滚动区之上。
class MovieSubscriptionListSection extends HookConsumerWidget {
  const MovieSubscriptionListSection({
    super.key,
    required this.onOpenMovie,
    this.scrollController,
  });

  /// 打开影片详情。桌面 / 移动的详情路由不同，由各自的页面注入——本组件不认路由。
  final void Function(BuildContext context, String movieNumber) onOpenMovie;

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.appSpacing;
    final ownedScrollController = useScrollController();
    final effectiveScrollController = scrollController ?? ownedScrollController;
    ref.listen(
      movieSubscriptionManagerProvider.select((value) => value.value?.filter),
      (previous, next) {
        if (previous != null &&
            next != null &&
            previous != next &&
            effectiveScrollController.hasClients) {
          effectiveScrollController.jumpTo(0);
        }
      },
    );
    return CustomScrollView(
      key: const Key('movie-subscriptions-scroll-view'),
      controller: effectiveScrollController,
      slivers: [
        const SliverToBoxAdapter(child: _ListHeader()),
        SliverToBoxAdapter(child: SizedBox(height: spacing.lg)),
        const SliverToBoxAdapter(child: _queryExplanationTip),
        SliverToBoxAdapter(child: SizedBox(height: spacing.md)),
        _ListBodySliver(onOpenMovie: onOpenMovie),
      ],
    );
  }
}

// --- 顶栏 -------------------------------------------------------------------

class _ListHeader extends ConsumerWidget {
  const _ListHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(movieSubscriptionManagerProvider);
    final current = asyncState.value;
    if (current != null && current.selectionMode) {
      return _SelectionHeader(state: current);
    }

    final filter = current?.filter ?? MovieSubscriptionFilterState.initial;
    final total = current?.paged.total ?? 0;
    final hasItems = current?.paged.items.isNotEmpty ?? false;
    final isInitialLoading = asyncState.isLoading && !asyncState.hasValue;

    void applyFilter(MovieSubscriptionFilterState next) {
      unawaited(
        ref
            .read(movieSubscriptionManagerProvider.notifier)
            .applyFilterState(next),
      );
    }

    Widget buildPanel(BuildContext panelContext) {
      return MovieSubscriptionFilterSectionGroup(
        filterState: filter,
        onChanged: applyFilter,
      );
    }

    final panelFooter = AppFilterPanelFooter(
      isDefault: filter.isPanelDefault,
      onReset: () => applyFilter(filter.resetPanel()),
    );

    return AppListHeader(
      key: const Key('movie-subscriptions-list-header'),
      filterButtonKey: const Key('movie-subscriptions-filter-button'),
      filterLabel: filter.triggerLabel,
      filterPanelKey: const Key('movie-subscriptions-filter-panel'),
      filterPanelBuilder: buildPanel,
      filterPanelFooter: panelFooter,
      filterUpdate:
          current?.paged.filterUpdate ?? const FilterUpdateState.idle(),
      hasPreviousFilterItems: hasItems,
      onRetryFilter: () => unawaited(
        ref.read(movieSubscriptionManagerProvider.notifier).retryFilter(),
      ),
      informationSlots: <Widget>[
        AppListHeaderInfo(
          key: const Key('movie-subscriptions-total-info'),
          label: '共 $total 部',
        ),
      ],
      actionSlots: <Widget>[
        AppSelectionEntryButton(
          onPressed: hasItems
              ? () => ref
                    .read(movieSubscriptionManagerProvider.notifier)
                    .enterSelectionMode()
              : null,
        ),
        AppIconButton(
          key: const Key('movie-subscriptions-refresh-button'),
          icon: const Icon(Icons.refresh_rounded),
          tooltip: isInitialLoading ? '刷新中' : '刷新',
          onPressed: isInitialLoading ? null : () => _refresh(ref),
        ),
      ],
    );
  }
}

void _refresh(WidgetRef ref) {
  unawaited(() async {
    final message = await ref
        .read(movieSubscriptionManagerProvider.notifier)
        .refresh();
    if (message != null) showToast(message);
  }());
}

// --- 多选态顶栏 --------------------------------------------------------------

class _SelectionHeader extends ConsumerWidget {
  const _SelectionHeader({required this.state});

  final MovieSubscriptionManagerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(movieSubscriptionManagerProvider.notifier);
    final busy = state.isBatchRunning;
    final loadedCount = state.paged.items.length;
    final allSelected = loadedCount > 0 && state.selectionCount >= loadedCount;
    final selectAllLabel = allSelected ? '取消全选' : '全选（$loadedCount）';

    return AppSelectionHeaderToolbar(
      key: const Key('movie-subscriptions-selection-header'),
      countLabel: '已选 ${state.selectionCount} 部',
      countKey: const Key('movie-subscriptions-selection-count'),
      selectAllLabel: selectAllLabel,
      selectAllKey: const Key('movie-subscriptions-select-all-button'),
      onToggleAll: busy || loadedCount == 0
          ? null
          : notifier.toggleSelectAllLoaded,
      exitKey: const Key('movie-subscriptions-selection-exit'),
      onExit: busy ? null : notifier.exitSelectionMode,
      actions: _buildBatchActions(context, ref, state),
    );
  }
}

/// 多选态顶栏里的批量取消订阅按钮。
List<Widget> _buildBatchActions(
  BuildContext context,
  WidgetRef ref,
  MovieSubscriptionManagerState state,
) {
  final busy = state.isBatchRunning;
  return <Widget>[
    AppButton(
      key: const Key('movie-subscriptions-batch-unsubscribe-button'),
      label: '取消订阅（${state.selectionCount}）',
      size: AppButtonSize.small,
      variant: AppButtonVariant.danger,
      icon: const Icon(Icons.bookmark_remove_outlined),
      isLoading: state.isBatchActionRunning(
        MovieSubscriptionBatchAction.unsubscribe,
      ),
      onPressed: busy || !state.hasSelection
          ? null
          : () => unawaited(_confirmBatchUnsubscribe(context, ref, state)),
    ),
  ];
}

Future<void> _confirmBatchUnsubscribe(
  BuildContext context,
  WidgetRef ref,
  MovieSubscriptionManagerState state,
) async {
  final count = state.selectionCount;
  final confirmed = await showAppConfirmDialog(
    context,
    dialogKey: const Key('movie-subscriptions-batch-unsubscribe-dialog'),
    title: '取消订阅 $count 部影片？',
    message: '取消后它们不再自动找资源。已有本地媒体的影片会被跳过，不会删除任何文件。',
    confirmLabel: '取消订阅',
    danger: true,
  );
  if (!confirmed) return;

  final result = await ref
      .read(movieSubscriptionManagerProvider.notifier)
      .batchUnsubscribe();
  if (!context.mounted) return;
  await showMovieSubscriptionBatchFeedback(context, result, subscribe: false);
}

// --- 查询说明 ----------------------------------------------------------------

const _queryExplanationTip = AppNoticeCard(
  leadingIcon: Icons.info_outline_rounded,
  description:
      '订阅影片后，系统通过定时任务在索引器中搜索可下载资源，找到后自动提交下载。'
      '新片（发行 90 天内）每轮查询、不限次数；'
      '老片默认至多查 3 次，用尽则标记「已放弃」，需手动重置后重新排队。'
      '查询出错不消耗次数，下一轮自动重试。'
      '重置不会清除种子黑名单——已判死的种子不再重试，系统会去寻找新的种子。',
);

// --- 列表体 -----------------------------------------------------------------

class _ListBodySliver extends ConsumerWidget {
  const _ListBodySliver({required this.onOpenMovie});

  final void Function(BuildContext context, String movieNumber) onOpenMovie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 只订阅 paged 段：多选 / 进行中集合变化时它保持相等，列表 sliver 不整体重建，
    // 每行由 [_RowConsumer] 各自订阅自己的选中 / pending 态。
    final asyncPaged = ref.watch(
      movieSubscriptionManagerProvider.select(
        (asyncState) => asyncState.whenData((state) => state.paged),
      ),
    );
    final notifier = ref.read(movieSubscriptionManagerProvider.notifier);

    // 不传 fixedItemExtent：错误行是条件渲染、进度行会换行，行高本来就不固定，
    // 强行给固定 extent 会让内容溢出。
    return SliverPagedAsyncSection<
      PagedListState<MovieSubscriptionListItemDto>,
      MovieSubscriptionListItemDto
    >(
      asyncState: asyncPaged,
      pagedOf: (paged) => paged,
      itemSpacing: context.appSpacing.sm,
      initialErrorMessage: '订阅列表加载失败，请稍后重试',
      emptyMessage: '当前筛选下没有订阅影片。',
      emptyBuilder: (context) => const _EmptyState(),
      initialRetryKey: const Key('movie-subscriptions-initial-retry-button'),
      onReload: () => unawaited(notifier.reload()),
      onLoadMore: () => unawaited(notifier.loadMore()),
      itemBuilder: (context, item, _) =>
          _RowConsumer(item: item, onOpenMovie: onOpenMovie),
    );
  }
}

/// 分状态的空态文案。
///
/// 待办三态为空是**好消息**，不该用「暂无数据」这种失败口吻打发——说清"没有卡住
/// 的订阅"，并给一个「看全部订阅」的去处，免得用户以为页面坏了。
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter =
        ref.watch(
          movieSubscriptionManagerProvider.select(
            (asyncState) => asyncState.value?.filter,
          ),
        ) ??
        MovieSubscriptionFilterState.initial;

    if (filter.hasSearch) {
      return AppEmptyState(
        key: const Key('movie-subscriptions-empty-state'),
        icon: Icons.search_off_rounded,
        message: '没有匹配「${filter.trimmedSearch}」的订阅影片。换个番号或标题片段再试。',
      );
    }

    final (icon, title, message) = switch (filter.status) {
      MovieSubscriptionStatus.missing => (
        Icons.check_circle_outline_rounded,
        '没有缺资源的订阅',
        '所有订阅影片要么已经拿到资源，要么还在正常查询中。',
      ),
      MovieSubscriptionStatus.exhausted => (
        Icons.check_circle_outline_rounded,
        '没有被放弃的订阅',
        '没有影片因多次没找到资源而放弃，不需要手动重置。',
      ),
      MovieSubscriptionStatus.importFailed => (
        Icons.check_circle_outline_rounded,
        '没有卡在导入的影片',
        '下载完成的影片都顺利入库了。',
      ),
      MovieSubscriptionStatus.failed => (
        Icons.check_circle_outline_rounded,
        '索引器一切正常',
        '最近一轮资源查询没有出错。',
      ),
      MovieSubscriptionStatus.pending => (
        Icons.hourglass_empty_rounded,
        '没有待查的订阅',
        '新订阅的影片会先落在这里，等下一轮定时任务查过就转到别的状态。',
      ),
      MovieSubscriptionStatus.downloading => (
        Icons.download_outlined,
        '没有正在下载的订阅',
        '找到种子的影片会出现在这里，进度可以去任务中心看。',
      ),
      MovieSubscriptionStatus.imported => (
        Icons.inbox_outlined,
        '还没有入库的订阅影片',
        '资源下载并导入媒体库后，影片会归到这里。',
      ),
      MovieSubscriptionStatus.unknown || null => (
        Icons.bookmark_border_rounded,
        '还没有订阅任何影片',
        '在影片列表或详情页点订阅，之后就能在这里跟进求片进度。',
      ),
    };

    final isFilteredView = filter.status != null;
    return Column(
      children: [
        AppEmptyState(
          key: const Key('movie-subscriptions-empty-state'),
          icon: icon,
          title: title,
          message: message,
        ),
        if (isFilteredView) ...[
          SizedBox(height: context.appSpacing.md),
          AppButton(
            key: const Key('movie-subscriptions-empty-see-all-button'),
            label: '查看全部订阅',
            size: AppButtonSize.small,
            variant: AppButtonVariant.secondary,
            onPressed: () => unawaited(
              ref
                  .read(movieSubscriptionManagerProvider.notifier)
                  .applyStatus(null),
            ),
          ),
        ],
      ],
    );
  }
}

/// 单行的订阅者：只 watch 自己的选中 / pending 态，避免整表重建。
class _RowConsumer extends ConsumerWidget {
  const _RowConsumer({required this.item, required this.onOpenMovie});

  final MovieSubscriptionListItemDto item;
  final void Function(BuildContext context, String movieNumber) onOpenMovie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionMode = ref.watch(
      movieSubscriptionManagerProvider.select(
        (asyncState) => asyncState.value?.selectionMode ?? false,
      ),
    );
    final isSelected = ref.watch(
      movieSubscriptionManagerProvider.select(
        (asyncState) => asyncState.value?.isSelected(item.movieNumber) ?? false,
      ),
    );
    final isPending = ref.watch(
      movieSubscriptionManagerProvider.select(
        (asyncState) => asyncState.value?.isPending(item.movieNumber) ?? false,
      ),
    );
    final notifier = ref.read(movieSubscriptionManagerProvider.notifier);

    return MovieSubscriptionRow(
      item: item,
      selectionMode: selectionMode,
      isSelected: isSelected,
      isPending: isPending,
      onTap: selectionMode
          ? () => notifier.toggleSelection(item.movieNumber)
          : () => onOpenMovie(context, item.movieNumber),
      onOpenDownloads: () =>
          context.goDesktopDownloadTasks(movieNumber: item.movieNumber),
      onSearchMagnet: () => showMovieMagnetSearchDialog(
        context: context,
        movieNumber: item.movieNumber,
      ),
      onUnsubscribe: () => unawaited(_unsubscribeRow(ref, item.movieNumber)),
    );
  }
}

/// 单条取消订阅不弹确认：它是可逆的（重新订阅即可）、也不删任何文件，
/// 二次确认只会让日常清理变啰嗦。批量才确认——那一下影响面大得多。
Future<void> _unsubscribeRow(WidgetRef ref, String movieNumber) async {
  final result = await ref
      .read(movieSubscriptionManagerProvider.notifier)
      .unsubscribe(movieNumber);
  showMovieSubscriptionFeedback(result);
}
