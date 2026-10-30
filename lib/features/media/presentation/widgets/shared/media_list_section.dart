import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_bottom_safe_area_sliver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_fixed_header_layout.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/actions/media_row_action_flow.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/media_placeholders.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/media_browse_filter_toolbar.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_card.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_text_field.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_toolbar.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart'
    show AppFilterPanelFooter;
import 'package:sakuramedia/widgets/domain/media/media_sort_menu_button.dart';

/// 「媒体管理」列表 tab 的主体：筛选头 + 白底 media card 列表（桌面 / 移动共用）。
///
/// 数据源：`mediaBrowseProvider` + `mediaLibrariesProvider`。多选、筛选、reload 全部
/// 由内部 `ref.read(...notifier)` 触发；父页只提供跨 provider 的批量操作与复合刷新。
///
/// 平台差异（`mobile: true` 时启用）：
/// - 行卡片：桌面 / 移动均使用 [MediaListItemCard]；
/// - 行点击：普通态 = JAV 弹「影片操作」/ PornBox 弹视频操作（桌面弹窗、移动底部
///   抽屉），选择态 = 勾选 / 取消勾选；移动端长按直接进入选择态并选中该行；
/// - 筛选入口：桌面 popover 工具栏 / 移动底部抽屉（`MediaBrowseFilterSectionGroup` 复用）；
/// - 多选：桌面顶栏「选择」入口 + 选择态操作条 / 移动 `AppListHeader.selection`（顶）
///   + `AppSelectionBottomBar`（底）。
///
/// 视觉参考「下载任务」卡片（[_DownloadTaskCard]）：页面灰底 + 每张 media card 直接浮起
/// 为独立白卡（不再套 `AppContentCard`）。多选操作全部收敛到顶部 [AppFilterTotalHeader]
/// 的 trailing，跟筛选、总数、刷新同一条行。
class MediaListSection extends HookConsumerWidget {
  const MediaListSection({
    super.key,
    required this.scrollController,
    required this.isDeleting,
    required this.isTransferring,
    required this.onBatchDelete,
    required this.onBatchTransfer,
    this.isResettingThumbnails = false,
    this.onBatchResetThumbnails,
    this.onRefresh,
    this.onOpenMovieDetail,
    this.keyPrefix = 'media-management',
    this.mobile = false,
    this.selectionMode = false,
    this.onEnterSelection,
    this.onExitSelection,
    this.onDeleteItem,
    this.deletingItemId,
    this.onTransferItem,
    this.transferringItemId,
    this.onRetryThumbnails,
    this.retryingThumbnailMediaId,
    this.onOpenRowActions,
    this.onEditTags,
  });

  final ScrollController scrollController;

  /// 批量操作进行中——按钮 spinner + 禁用其它多选动作。
  final bool isDeleting;

  final bool isTransferring;

  /// 父页批量删除入口：弹二次确认 → 提交后端批量任务 → 提示已提交。
  final Future<void> Function() onBatchDelete;

  final Future<void> Function() onBatchTransfer;

  final bool isResettingThumbnails;

  final Future<void> Function()? onBatchResetThumbnails;

  /// 可选：父页复合刷新；不传则默认刷新媒体列表 + 媒体库。
  final Future<void> Function()? onRefresh;

  /// 可选：JAV 行弹层里的「影片详情」入口；不传时弹层不显示该动作。
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  /// 测试 Key 前缀：桌面 `media-management`，移动 `mobile-media-management`。
  final String keyPrefix;

  /// 移动端布局开关：流式行卡 + 底部抽屉筛选 + 多选态工具栏/底部操作条。
  final bool mobile;

  /// 多选态（移动端长按进入后为 true）：行卡切换为点选、顶栏换选择工具栏、
  /// 列表底部追加批量操作条。
  final bool selectionMode;

  /// 移动端长按行进入多选态；桌面端不用。
  final VoidCallback? onEnterSelection;

  /// 移动端退出多选态（清空选择由本组件内部调 provider）；桌面端不用。
  final VoidCallback? onExitSelection;

  /// 单项删除入口；不传时不显示卡片级删除按钮。
  final Future<void> Function(MediaListItemDto item)? onDeleteItem;

  /// 当前正在删除的媒体 ID，用于只显示对应卡片的 loading。
  final ValueListenable<int?>? deletingItemId;

  /// 单项迁移入口；不传时不显示卡片级迁移按钮。
  final Future<void> Function(MediaListItemDto item)? onTransferItem;

  /// 当前正在迁移的媒体 ID，用于只显示对应卡片的 loading。
  final ValueListenable<int?>? transferringItemId;

  /// 单项缩略图重试入口；不传时不显示卡片级重试按钮。
  final Future<void> Function(MediaListItemDto item)? onRetryThumbnails;

  /// 当前正在重试缩略图的媒体 ID，用于只显示对应卡片的 loading。
  final ValueListenable<int?>? retryingThumbnailMediaId;

  /// 移动端单项「更多」入口：桌面端不用（行内平铺图标，hover 有 tooltip）。
  final Future<void> Function(MediaListItemDto item)? onOpenRowActions;
  final Future<void> Function(MediaListItemDto item)? onEditTags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchExpanded = useState(false);
    final scrollView = CustomScrollView(
      key: Key('$keyPrefix-list-scroll-view'),
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
        _MediaListBodySliver(
          keyPrefix: keyPrefix,
          mobile: mobile,
          selectionMode: selectionMode,
          onEnterSelection: onEnterSelection,
          onOpenMovieDetail: onOpenMovieDetail,
          isDeleting: isDeleting,
          isTransferring: isTransferring,
          isResettingThumbnails: isResettingThumbnails,
          onDeleteItem: onDeleteItem,
          deletingItemId: deletingItemId,
          onTransferItem: onTransferItem,
          transferringItemId: transferringItemId,
          onRetryThumbnails: onRetryThumbnails,
          retryingThumbnailMediaId: retryingThumbnailMediaId,
          onOpenRowActions: onOpenRowActions,
          onEditTags: onEditTags,
        ),
        // loadMore 的 loading / 失败提示独立订阅：翻页状态翻转只重建这个
        // footer，不重建上面的列表本体。
        // 页脚独立订阅 loadMore 状态：翻页 loading/失败翻转只重建它。
        PagedLoadMoreFooterSliver(
          watchFooter: (ref) => ref.watch(
            mediaBrowseProvider.select(
              (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
            ),
          ),
          onLoadMore: (ref) =>
              unawaited(ref.read(mediaBrowseProvider.notifier).loadMore()),
        ),
        ...bottomSafeAreaSliver(context),
      ],
    );
    final resultView = Consumer(
      builder: (context, ref, _) {
        final paged = ref.watch(
          mediaBrowseProvider.select((asyncState) => asyncState.value?.paged),
        );
        return AppFixedHeaderLayout(
          header: _MediaListHeader(
            keyPrefix: keyPrefix,
            mobile: mobile,
            selectionMode: selectionMode,
            isDeleting: isDeleting,
            isTransferring: isTransferring,
            onBatchDelete: onBatchDelete,
            onBatchTransfer: onBatchTransfer,
            isResettingThumbnails: isResettingThumbnails,
            onBatchResetThumbnails: onBatchResetThumbnails,
            onRefresh: onRefresh,
            onEnterSelection: onEnterSelection,
            onExitSelection: onExitSelection,
            searchExpanded: searchExpanded.value,
            onToggleSearchExpanded: () =>
                searchExpanded.value = !searchExpanded.value,
          ),
          child: AppFilterResultLoadingOverlay(
            surfaceColor: mobile
                ? context.appColors.surfaceCard
                : context.appColors.surfaceElevated,
            isLoading: paged?.filterUpdate.isLoading ?? false,
            hasPreviousItems: paged?.items.isNotEmpty ?? false,
            child: scrollView,
          ),
        );
      },
    );

    // 移动端多选态：列表下方常驻批量操作条。
    if (mobile && selectionMode) {
      return Column(
        children: [
          Expanded(child: resultView),
          _MediaMobileSelectionBar(
            keyPrefix: keyPrefix,
            isDeleting: isDeleting,
            isTransferring: isTransferring,
            isResettingThumbnails: isResettingThumbnails,
            onBatchDelete: onBatchDelete,
            onBatchTransfer: onBatchTransfer,
            onBatchResetThumbnails: onBatchResetThumbnails,
          ),
        ],
      );
    }
    return resultView;
  }
}

class _MediaListHeader extends ConsumerWidget {
  const _MediaListHeader({
    required this.keyPrefix,
    required this.mobile,
    required this.selectionMode,
    required this.isDeleting,
    required this.isTransferring,
    required this.isResettingThumbnails,
    required this.onBatchDelete,
    required this.onBatchTransfer,
    required this.onBatchResetThumbnails,
    required this.onRefresh,
    required this.onEnterSelection,
    required this.onExitSelection,
    required this.searchExpanded,
    required this.onToggleSearchExpanded,
  });

  final String keyPrefix;
  final bool mobile;
  final bool selectionMode;
  final bool isDeleting;
  final bool isTransferring;
  final bool isResettingThumbnails;
  final Future<void> Function() onBatchDelete;
  final Future<void> Function() onBatchTransfer;
  final Future<void> Function()? onBatchResetThumbnails;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onEnterSelection;
  final VoidCallback? onExitSelection;
  final bool searchExpanded;
  final VoidCallback onToggleSearchExpanded;

  Future<void> _defaultRefresh(WidgetRef ref) async {
    await Future.wait<void>([_refreshBrowse(ref), _refreshLibraries(ref)]);
  }

  Future<void> _refreshBrowse(WidgetRef ref) async {
    final message = await ref.read(mediaBrowseProvider.notifier).refresh();
    if (message != null) showToast(message);
  }

  Future<void> _refreshLibraries(WidgetRef ref) async {
    final message = await ref.read(mediaLibrariesProvider.notifier).refresh();
    if (message != null) showToast(message);
  }

  void _applyFilter(WidgetRef ref, MediaBrowseFilterState next) {
    unawaited(ref.read(mediaBrowseProvider.notifier).applyFilterState(next));
  }

  void _resetFilter(WidgetRef ref) {
    final current =
        ref.read(mediaBrowseProvider).value?.filter ??
        MediaBrowseFilterState.initial;
    unawaited(
      ref
          .read(mediaBrowseProvider.notifier)
          .applyFilterState(current.resetFilters()),
    );
  }

  Future<void> _openMobileFilterDrawer(
    BuildContext context, {
    required MediaBrowseFilterState filter,
    required List<MediaLibraryDto> libraries,
    required WidgetRef ref,
  }) {
    return showAppBottomDrawer(
      context: context,
      drawerKey: Key('$keyPrefix-filter-drawer'),
      heightFactor: 0.8,
      builder: (_) => _MediaListMobileFilterDrawerContent(
        initial: filter,
        libraries: libraries,
        onChanged: (next) => _applyFilter(ref, next),
        scrollViewKey: Key('$keyPrefix-filter-scroll-view'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncState = ref.watch(mediaBrowseProvider);
    final librariesAsync = ref.watch(mediaLibrariesProvider);
    final librariesState = librariesAsync.value ?? MediaLibrariesState.empty;

    final currentState = asyncState.value;
    final total = currentState?.paged.total ?? 0;
    final selectionCount = currentState?.selectionCount ?? 0;
    final hasSelection = selectionCount > 0;
    final hasItems =
        currentState != null && currentState.paged.items.isNotEmpty;
    final filter = currentState?.filter ?? MediaBrowseFilterState.initial;
    final isInitialLoading = asyncState.isLoading && !asyncState.hasValue;
    final busy = isDeleting || isTransferring || isResettingThumbnails;
    final allLoadedSelected = currentState?.allLoadedSelected ?? false;
    final searchToggle = AppIconButton(
      key: Key('$keyPrefix-search-toggle'),
      tooltip: searchExpanded
          ? l10n.mediaListCollapseSearchTooltip
          : l10n.mediaListSearchFileNameTooltip,
      semanticLabel: searchExpanded
          ? l10n.mediaListCollapseSearchTooltip
          : l10n.mediaListSearchFileNameTooltip,
      icon: Icon(
        searchExpanded ? Icons.close_rounded : Icons.search_rounded,
      ),
      isSelected: searchExpanded || filter.hasSearch,
      backgroundColor: Colors.transparent,
      selectedBackgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
      selectedBorderColor: Colors.transparent,
      onPressed: onToggleSearchExpanded,
    );
    final searchField = _MediaFileNameSearchField(
      fieldKey: Key('$keyPrefix-search-field'),
      clearButtonKey: Key('$keyPrefix-search-clear'),
      search: filter.search,
      onSubmitted: (value) => _applyFilter(ref, filter.copyWith(search: value)),
    );

    // 移动端多选态：顶栏换 `AppListHeader.selection`（退出 / 计数 / 全选），
    // 与 PornBox / 订阅列表的多选顶栏同一套组件；高度与常规顶栏严格一致。
    if (mobile && selectionMode) {
      return AppListHeader.selection(
        key: Key('$keyPrefix-selection-header'),
        selectionLabel: l10n.mediaListSelectedItems(selectionCount),
        selectionExitButtonKey: Key('$keyPrefix-exit-selection-button'),
        onExitSelection: () {
          ref.read(mediaBrowseProvider.notifier).clearSelection();
          onExitSelection?.call();
        },
        actionSlots: [
          AppTextButton(
            key: Key('$keyPrefix-select-all-button'),
            label: allLoadedSelected
                ? l10n.mediaListClearSelectAllLoaded
                : l10n.mediaListSelectAllLoaded,
            size: AppTextButtonSize.small,
            onPressed: !hasItems || busy
                ? null
                : () => ref
                      .read(mediaBrowseProvider.notifier)
                      .toggleSelectAllLoaded(),
          ),
        ],
      );
    }

    // 移动端非多选态：默认只显示搜索图标；展开后只保留筛选、输入框和图标。
    if (mobile) {
      if (searchExpanded) {
        return AppListHeader(
          key: Key('$keyPrefix-header'),
          onFilterTap: () => _openMobileFilterDrawer(
            context,
            filter: filter,
            libraries: librariesState.libraries,
            ref: ref,
          ),
          filterLabel: null,
          filterButtonKey: Key('$keyPrefix-filter-trigger'),
          filterTooltip: l10n.mediaListFilterTooltip,
          leadingGap: context.appSpacing.sm,
          filterUpdate:
              currentState?.paged.filterUpdate ??
              const FilterUpdateState.idle(),
          hasPreviousFilterItems: hasItems,
          onRetryFilter: () =>
              unawaited(ref.read(mediaBrowseProvider.notifier).retryFilter()),
          center: Row(
            children: [
              Expanded(child: searchField),
              SizedBox(width: context.appSpacing.sm),
              searchToggle,
            ],
          ),
        );
      }
      return AppListHeader(
        key: Key('$keyPrefix-header'),
        onFilterTap: () => _openMobileFilterDrawer(
          context,
          filter: filter,
          libraries: librariesState.libraries,
          ref: ref,
        ),
        // 移动端空间有限，筛选摘要收进 Tooltip，和排序入口一样只留图标。
        filterLabel: null,
        filterButtonKey: Key('$keyPrefix-filter-trigger'),
        filterTooltip: l10n.mediaListFilterTooltip,
        leadingGap: context.appSpacing.xs,
        filterUpdate:
            currentState?.paged.filterUpdate ?? const FilterUpdateState.idle(),
        hasPreviousFilterItems: hasItems,
        onRetryFilter: () =>
            unawaited(ref.read(mediaBrowseProvider.notifier).retryFilter()),
        center: Row(
          children: [
            MediaSortMenuButton(
              triggerKey: Key('$keyPrefix-sort-trigger'),
              drawerKey: Key('$keyPrefix-sort-drawer'),
              keyPrefix: keyPrefix,
              filterState: filter,
              onChanged: (next) => _applyFilter(ref, next),
              useDrawer: true,
            ),
            const Spacer(),
            AppListHeaderInfo(
              key: Key('$keyPrefix-total-text'),
              label: l10n.mediaListTotalItems(total),
            ),
            SizedBox(width: context.appSpacing.xs),
            AppTextButton(
              key: Key('$keyPrefix-enter-selection-button'),
              label: l10n.mediaListEnterSelection,
              size: AppTextButtonSize.xSmall,
              icon: const Icon(Icons.check_circle_outline, size: 14),
              onPressed: hasItems && !busy ? onEnterSelection : null,
            ),
            SizedBox(width: context.appSpacing.xs),
            AppIconButton(
              key: Key('$keyPrefix-refresh-button'),
              tooltip: isInitialLoading
                  ? l10n.mediaListRefreshing
                  : l10n.commonRefresh,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: isInitialLoading
                  ? null
                  : () {
                      unawaited((onRefresh ?? () => _defaultRefresh(ref))());
                    },
            ),
            SizedBox(width: context.appSpacing.xs),
            searchToggle,
          ],
        ),
      );
    }

    if (searchExpanded && !selectionMode) {
      return AppListHeader(
        key: Key('$keyPrefix-header'),
        filterButtonKey: Key('$keyPrefix-filter-trigger'),
        filterLabel: null,
        filterTooltip: l10n.mediaListFilterTooltip,
        filterPanelKey: const Key('media-management-filter-panel'),
        filterPanelExtraWidth: 240,
        leadingGap: context.appSpacing.sm,
        filterPanelBuilder: (_) => MediaBrowseFilterSectionGroup(
          filterState: filter,
          libraries: librariesState.libraries,
          onChanged: (next) => _applyFilter(ref, next),
        ),
        filterPanelFooter: AppFilterPanelFooter(
          isDefault: !filter.hasActiveFilters,
          onReset: () => _resetFilter(ref),
        ),
        filterUpdate:
            currentState?.paged.filterUpdate ?? const FilterUpdateState.idle(),
        hasPreviousFilterItems: hasItems,
        onRetryFilter: () =>
            unawaited(ref.read(mediaBrowseProvider.notifier).retryFilter()),
        center: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: constraints.maxWidth.clamp(0.0, 360.0).toDouble(),
              child: Row(
                children: [
                  Expanded(child: searchField),
                  SizedBox(width: context.appSpacing.sm),
                  searchToggle,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return AppFilterTotalHeader(
      leading: MediaBrowseFilterToolbar(
        filterState: filter,
        libraries: librariesState.libraries,
        onChanged: (next) => _applyFilter(ref, next),
        onReset: () => _resetFilter(ref),
      ),
      totalText: hasSelection
          ? l10n.mediaListTotalItemsWithSelection(total, selectionCount)
          : l10n.mediaListTotalItems(total),
      totalKey: const Key('media-management-total-text'),
      filterUpdate:
          currentState?.paged.filterUpdate ?? const FilterUpdateState.idle(),
      hasPreviousFilterItems: hasItems,
      onRetryFilter: () =>
          unawaited(ref.read(mediaBrowseProvider.notifier).retryFilter()),
      trailing: _MediaListActionBar(
        hasItems: hasItems,
        selectionMode: selectionMode,
        hasSelection: hasSelection,
        selectionCount: selectionCount,
        allLoadedSelected: allLoadedSelected,
        isDeleting: isDeleting,
        isTransferring: isTransferring,
        isResettingThumbnails: isResettingThumbnails,
        isInitialLoading: isInitialLoading,
        busy: busy,
        onEnterSelection: onEnterSelection,
        onExitSelection: onExitSelection,
        onBatchDelete: onBatchDelete,
        onBatchTransfer: onBatchTransfer,
        canResetThumbnails:
            filter.thumbnailGenerationState ==
                MediaBrowseThumbnailGenerationFilter.terminal ||
            filter.thumbnailGenerationState ==
                MediaBrowseThumbnailGenerationFilter.succeeded,
        resetThumbnailsLabel:
            filter.thumbnailGenerationState ==
                MediaBrowseThumbnailGenerationFilter.succeeded
            ? l10n.mediaListActionRegenerateThumbnails
            : l10n.mediaListActionRetryThumbnails,
        onBatchResetThumbnails: onBatchResetThumbnails,
        onRefresh: () => unawaited((onRefresh ?? () => _defaultRefresh(ref))()),
        searchToggle: selectionMode ? null : searchToggle,
      ),
    );
  }
}

/// 移动端筛选抽屉内容：沿用 `movie_filter_drawer` 的「本地 `_local` + 即时外发」模式
/// （就地反映选中态，打开期间点选 chip 立即点亮），壳用共享
/// [AppMobileFilterDrawerScaffold]（与其余筛选抽屉一致，无标题、条件即时更新）。
class _MediaListMobileFilterDrawerContent extends StatefulWidget {
  const _MediaListMobileFilterDrawerContent({
    required this.initial,
    required this.libraries,
    required this.onChanged,
    required this.scrollViewKey,
  });

  final MediaBrowseFilterState initial;
  final List<MediaLibraryDto> libraries;
  final ValueChanged<MediaBrowseFilterState> onChanged;
  final Key scrollViewKey;

  @override
  State<_MediaListMobileFilterDrawerContent> createState() =>
      _MediaListMobileFilterDrawerContentState();
}

class _MediaListMobileFilterDrawerContentState
    extends State<_MediaListMobileFilterDrawerContent> {
  late MediaBrowseFilterState _local;

  @override
  void initState() {
    super.initState();
    _local = widget.initial;
  }

  void _apply(MediaBrowseFilterState next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: widget.scrollViewKey,
      footer: AppFilterPanelFooter(
        isDefault: !_local.hasActiveFilters,
        onReset: () => _apply(_local.resetFilters()),
      ),
      child: MediaBrowseFilterSectionGroup(
        filterState: _local,
        libraries: widget.libraries,
        onChanged: _apply,
      ),
    );
  }
}

class _MediaListBodySliver extends ConsumerWidget {
  const _MediaListBodySliver({
    required this.keyPrefix,
    required this.mobile,
    required this.selectionMode,
    required this.onEnterSelection,
    required this.onOpenMovieDetail,
    required this.isDeleting,
    required this.isTransferring,
    required this.isResettingThumbnails,
    required this.onDeleteItem,
    required this.deletingItemId,
    required this.onTransferItem,
    required this.transferringItemId,
    required this.onRetryThumbnails,
    required this.retryingThumbnailMediaId,
    required this.onOpenRowActions,
    required this.onEditTags,
  });

  final String keyPrefix;
  final bool mobile;
  final bool selectionMode;
  final VoidCallback? onEnterSelection;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;
  final bool isDeleting;
  final bool isTransferring;
  final bool isResettingThumbnails;
  final Future<void> Function(MediaListItemDto item)? onDeleteItem;
  final ValueListenable<int?>? deletingItemId;
  final Future<void> Function(MediaListItemDto item)? onTransferItem;
  final ValueListenable<int?>? transferringItemId;
  final Future<void> Function(MediaListItemDto item)? onRetryThumbnails;
  final ValueListenable<int?>? retryingThumbnailMediaId;
  final Future<void> Function(MediaListItemDto item)? onOpenRowActions;
  final Future<void> Function(MediaListItemDto item)? onEditTags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 多选集合变化时 paged 段保持相等，因此列表 sliver 不会整体重建；
    // 每一行通过 [_MediaRowConsumer] 只订阅自己的选中态。
    // loadMore 的 loading / 失败只影响页脚：这里清成中立值，翻页状态翻转
    // 不重建列表 sliver（页脚由 [PagedLoadMoreFooterSliver] 展示）。
    final asyncPaged = ref.watch(
      mediaBrowseProvider.select(
        (asyncState) =>
            asyncState.whenData((state) => withoutLoadMoreStatus(state.paged)),
      ),
    );

    Widget buildRow(BuildContext context, MediaListItemDto item) => mobile
        ? _MediaMobileRowConsumer(
            keyPrefix: keyPrefix,
            item: item,
            selectionMode: selectionMode,
            onEnterSelection: onEnterSelection,
            onOpenMovieDetail: onOpenMovieDetail,
            isDeleting: isDeleting,
            isTransferring: isTransferring,
            isResettingThumbnails: isResettingThumbnails,
            onDeleteItem: onDeleteItem,
            deletingItemId: deletingItemId,
            onTransferItem: onTransferItem,
            transferringItemId: transferringItemId,
            onRetryThumbnails: onRetryThumbnails,
            retryingThumbnailMediaId: retryingThumbnailMediaId,
            onOpenRowActions: onOpenRowActions,
            onEditTags: onEditTags,
          )
        : _MediaRowConsumer(
            keyPrefix: keyPrefix,
            item: item,
            selectionMode: selectionMode,
            onOpenMovieDetail: onOpenMovieDetail,
            isDeleting: isDeleting,
            isTransferring: isTransferring,
            isResettingThumbnails: isResettingThumbnails,
            onDeleteItem: onDeleteItem,
            deletingItemId: deletingItemId,
            onTransferItem: onTransferItem,
            transferringItemId: transferringItemId,
            onRetryThumbnails: onRetryThumbnails,
            retryingThumbnailMediaId: retryingThumbnailMediaId,
            onEditTags: onEditTags,
          );

    return SliverPagedAsyncSection<
      PagedListState<MediaListItemDto>,
      MediaListItemDto
    >(
      asyncState: asyncPaged,
      pagedOf: (state) => state,
      itemSpacing: context.appSpacing.sm,
      initialErrorMessage: l10n.errorMediaListLoadFailed,
      emptyMessage: l10n.mediaListEmpty,
      // loading 用占位媒体渲染真实行，由 [AppSkeletonizer] 灰化。
      skeletonBuilder: (context) {
        final placeholders = mediaListItemPlaceholders();
        return AppSkeletonizer(
          enabled: true,
          child: Column(
            children: [
              for (var index = 0; index < placeholders.length; index++) ...[
                if (index > 0) SizedBox(height: context.appSpacing.sm),
                buildRow(context, placeholders[index]),
              ],
            ],
          ),
        );
      },
      initialRetryKey: Key('$keyPrefix-initial-retry-button'),
      onReload: () =>
          unawaited(ref.read(mediaBrowseProvider.notifier).reload()),
      onLoadMore: () =>
          unawaited(ref.read(mediaBrowseProvider.notifier).loadMore()),
      itemBuilder: (context, item, _) => buildRow(context, item),
      // 页脚由 PagedLoadMoreFooterSliver 独立渲染。
      showLoadMoreFooter: false,
    );
  }
}

/// 移动端行 consumer：订阅选中态 / 媒体库，组装 [MediaListItemCard]。
class _MediaMobileRowConsumer extends ConsumerWidget {
  const _MediaMobileRowConsumer({
    required this.keyPrefix,
    required this.item,
    required this.selectionMode,
    required this.onEnterSelection,
    this.onOpenMovieDetail,
    required this.isDeleting,
    required this.isTransferring,
    required this.isResettingThumbnails,
    required this.onDeleteItem,
    required this.deletingItemId,
    required this.onTransferItem,
    required this.transferringItemId,
    required this.onRetryThumbnails,
    required this.retryingThumbnailMediaId,
    required this.onOpenRowActions,
    required this.onEditTags,
  });

  final String keyPrefix;
  final MediaListItemDto item;
  final bool selectionMode;
  final VoidCallback? onEnterSelection;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;
  final bool isDeleting;
  final bool isTransferring;
  final bool isResettingThumbnails;
  final Future<void> Function(MediaListItemDto item)? onDeleteItem;
  final ValueListenable<int?>? deletingItemId;
  final Future<void> Function(MediaListItemDto item)? onTransferItem;
  final ValueListenable<int?>? transferringItemId;
  final Future<void> Function(MediaListItemDto item)? onRetryThumbnails;
  final ValueListenable<int?>? retryingThumbnailMediaId;
  final Future<void> Function(MediaListItemDto item)? onOpenRowActions;
  final Future<void> Function(MediaListItemDto item)? onEditTags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isSelected = ref.watch(
      mediaBrowseProvider.select(
        (asyncState) => asyncState.value?.isSelected(item.id) ?? false,
      ),
    );
    final librariesById = ref.watch(
      mediaLibrariesProvider.select(
        (asyncState) =>
            asyncState.value?.librariesById ?? const <int, MediaLibraryDto>{},
      ),
    );
    final library = item.libraryId == null
        ? null
        : librariesById[item.libraryId];

    Widget buildCard(int? deletingId, int? transferringId, int? retryingId) {
      final isRegenerateThumbnails =
          item.thumbnailGenerationState ==
          MediaThumbnailGenerationState.succeeded;
      final isRetryable =
          !selectionMode &&
          (item.thumbnailGenerationState ==
                  MediaThumbnailGenerationState.terminal ||
              isRegenerateThumbnails);
      final isRetrying = retryingId == item.id;
      final busy =
          isDeleting ||
          isTransferring ||
          isResettingThumbnails ||
          deletingId != null ||
          transferringId != null ||
          retryingId != null;
      return MediaListItemCard(
        keyPrefix: keyPrefix,
        item: item,
        library: library,
        mobile: true,
        selected: isSelected,
        onTap: selectionMode
            ? () => ref
                  .read(mediaBrowseProvider.notifier)
                  .toggleSelection(item.id)
            : () => unawaited(
                openMediaRowActions(
                  context,
                  ref,
                  item,
                  mobile: true,
                  onOpenMovieDetail: onOpenMovieDetail,
                ),
              ),
        onLongPress: selectionMode
            ? null
            : () {
                ref.read(mediaBrowseProvider.notifier).toggleSelection(item.id);
                onEnterSelection?.call();
              },
        onDelete: selectionMode || onDeleteItem == null
            ? null
            : () => unawaited(onDeleteItem!(item)),
        onEditTags: selectionMode || busy || !item.isJav || onEditTags == null
            ? null
            : () => unawaited(onEditTags!(item)),
        isDeleting: deletingId == item.id,
        canDelete: !busy,
        onTransfer: selectionMode || onTransferItem == null
            ? null
            : () => unawaited(onTransferItem!(item)),
        isTransferring: transferringId == item.id,
        canTransfer: !busy,
        onRetryThumbnails: isRetryable && onRetryThumbnails != null
            ? () => unawaited(onRetryThumbnails!(item))
            : null,
        isRetryingThumbnails: isRetrying,
        canRetryThumbnails: isRetryable && !busy,
        retryThumbnailsLabel: isRegenerateThumbnails
            ? l10n.mediaListActionRegenerateThumbnails
            : l10n.mediaListActionRetryThumbnails,
        onOpenActions: selectionMode || onOpenRowActions == null
            ? null
            : () => unawaited(onOpenRowActions!(item)),
      );
    }

    final listenables = <Listenable>[
      ?deletingItemId,
      ?transferringItemId,
      ?retryingThumbnailMediaId,
    ];
    if (listenables.isEmpty) return buildCard(null, null, null);
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, child) => buildCard(
        deletingItemId?.value,
        transferringItemId?.value,
        retryingThumbnailMediaId?.value,
      ),
    );
  }
}

/// 移动端多选态底部批量操作条。
class _MediaMobileSelectionBar extends ConsumerWidget {
  const _MediaMobileSelectionBar({
    required this.keyPrefix,
    required this.isDeleting,
    required this.isTransferring,
    required this.isResettingThumbnails,
    required this.onBatchDelete,
    required this.onBatchTransfer,
    required this.onBatchResetThumbnails,
  });

  final String keyPrefix;
  final bool isDeleting;
  final bool isTransferring;
  final bool isResettingThumbnails;
  final Future<void> Function() onBatchDelete;
  final Future<void> Function() onBatchTransfer;
  final Future<void> Function()? onBatchResetThumbnails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selectionCount = ref.watch(
      mediaBrowseProvider.select(
        (asyncState) => asyncState.value?.selectionCount ?? 0,
      ),
    );
    final resetThumbnailsMode = ref.watch(
      mediaBrowseProvider.select(
        (asyncState) => asyncState.value?.filter.thumbnailGenerationState,
      ),
    );
    final resetThumbnailsLabel = switch (resetThumbnailsMode) {
      MediaBrowseThumbnailGenerationFilter.terminal =>
        l10n.mediaListBatchRetryThumbnails,
      MediaBrowseThumbnailGenerationFilter.succeeded =>
        l10n.mediaListBatchRegenerateThumbnails,
      _ => null,
    };
    final busy = isDeleting || isTransferring || isResettingThumbnails;
    return AppSelectionBottomBar(
      leading: Text(
        l10n.mediaListSelectedItems(selectionCount),
        key: Key('$keyPrefix-bottom-selection-count'),
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.semibold,
          tone: AppTextTone.primary,
        ),
      ),
      actions: [
        AppButton(
          key: Key('$keyPrefix-batch-transfer-button'),
          label: l10n.mediaListActionTransfer,
          size: AppButtonSize.small,
          icon: const Icon(Icons.drive_file_move_outline),
          isLoading: isTransferring,
          onPressed: busy || selectionCount == 0 ? null : onBatchTransfer,
        ),
        AppButton(
          key: Key('$keyPrefix-batch-delete-button'),
          label: l10n.commonDelete,
          size: AppButtonSize.small,
          variant: AppButtonVariant.danger,
          icon: const Icon(Icons.delete_outline_rounded),
          isLoading: isDeleting,
          onPressed: busy || selectionCount == 0 ? null : onBatchDelete,
        ),
        if (resetThumbnailsLabel != null && onBatchResetThumbnails != null)
          AppButton(
            key: Key('$keyPrefix-batch-reset-thumbnails-button'),
            label: resetThumbnailsLabel,
            size: AppButtonSize.small,
            // 「重新生成」比「重试」长，去掉图标保证 4 字完整显示。
            icon:
                resetThumbnailsMode ==
                    MediaBrowseThumbnailGenerationFilter.terminal
                ? const Icon(Icons.refresh_rounded)
                : null,
            isLoading: isResettingThumbnails,
            onPressed: busy || selectionCount == 0
                ? null
                : onBatchResetThumbnails,
          ),
      ],
    );
  }
}

class _MediaRowConsumer extends ConsumerWidget {
  const _MediaRowConsumer({
    required this.keyPrefix,
    required this.item,
    required this.selectionMode,
    this.onOpenMovieDetail,
    required this.isDeleting,
    required this.isTransferring,
    required this.isResettingThumbnails,
    required this.onDeleteItem,
    required this.deletingItemId,
    required this.onTransferItem,
    required this.transferringItemId,
    required this.onRetryThumbnails,
    required this.retryingThumbnailMediaId,
    required this.onEditTags,
  });

  final String keyPrefix;
  final MediaListItemDto item;
  final bool selectionMode;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;
  final bool isDeleting;
  final bool isTransferring;
  final bool isResettingThumbnails;
  final Future<void> Function(MediaListItemDto item)? onDeleteItem;
  final ValueListenable<int?>? deletingItemId;
  final Future<void> Function(MediaListItemDto item)? onTransferItem;
  final ValueListenable<int?>? transferringItemId;
  final Future<void> Function(MediaListItemDto item)? onRetryThumbnails;
  final ValueListenable<int?>? retryingThumbnailMediaId;
  final Future<void> Function(MediaListItemDto item)? onEditTags;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isSelected = ref.watch(
      mediaBrowseProvider.select(
        (asyncState) => asyncState.value?.isSelected(item.id) ?? false,
      ),
    );
    final librariesById = ref.watch(
      mediaLibrariesProvider.select(
        (asyncState) =>
            asyncState.value?.librariesById ?? const <int, MediaLibraryDto>{},
      ),
    );
    final library = item.libraryId == null
        ? null
        : librariesById[item.libraryId];

    Widget buildCard(int? deletingId, int? transferringId, int? retryingId) {
      final isRegenerateThumbnails =
          item.thumbnailGenerationState ==
          MediaThumbnailGenerationState.succeeded;
      final isRetryable =
          !selectionMode &&
          (item.thumbnailGenerationState ==
                  MediaThumbnailGenerationState.terminal ||
              isRegenerateThumbnails);
      final isRetrying = retryingId == item.id;
      final busy =
          isDeleting ||
          isTransferring ||
          isResettingThumbnails ||
          deletingId != null ||
          transferringId != null ||
          retryingId != null;
      return MediaListItemCard(
        keyPrefix: keyPrefix,
        item: item,
        library: library,
        mobile: false,
        selected: isSelected,
        onTap: selectionMode
            ? () => ref
                  .read(mediaBrowseProvider.notifier)
                  .toggleSelection(item.id)
            : () => unawaited(
                openMediaRowActions(
                  context,
                  ref,
                  item,
                  mobile: false,
                  onOpenMovieDetail: onOpenMovieDetail,
                ),
              ),
        onDelete: selectionMode || onDeleteItem == null
            ? null
            : () => unawaited(onDeleteItem!(item)),
        onEditTags: selectionMode || busy || !item.isJav || onEditTags == null
            ? null
            : () => unawaited(onEditTags!(item)),
        isDeleting: deletingId == item.id,
        canDelete: !busy,
        onTransfer: selectionMode || onTransferItem == null
            ? null
            : () => unawaited(onTransferItem!(item)),
        isTransferring: transferringId == item.id,
        canTransfer: !busy,
        onRetryThumbnails: isRetryable && onRetryThumbnails != null
            ? () => unawaited(onRetryThumbnails!(item))
            : null,
        isRetryingThumbnails: isRetrying,
        canRetryThumbnails: isRetryable && !busy,
        retryThumbnailsLabel: isRegenerateThumbnails
            ? l10n.mediaListActionRegenerateThumbnails
            : l10n.mediaListActionRetryThumbnails,
        showUpdatedAt: true,
      );
    }

    final listenables = <Listenable>[
      ?deletingItemId,
      ?transferringItemId,
      ?retryingThumbnailMediaId,
    ];
    if (listenables.isEmpty) return buildCard(null, null, null);
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, child) => buildCard(
        deletingItemId?.value,
        transferringItemId?.value,
        retryingThumbnailMediaId?.value,
      ),
    );
  }
}

/// 顶栏右侧操作条：普通态 =「选择」入口 + 刷新 + 搜索；选择态 = 全选 /
/// 迁移 / 重试 / 批量删除 / 退出选择，危险色只用于删除。
///
/// 「选择」是进入多选的唯一显式入口（移动端另有长按）；选择态下点行才是勾选。
/// 退出选择与移动端多选顶栏同一语义：清空已选并结束选择模式。
class _MediaListActionBar extends ConsumerWidget {
  const _MediaListActionBar({
    required this.hasItems,
    required this.selectionMode,
    required this.hasSelection,
    required this.selectionCount,
    required this.allLoadedSelected,
    required this.isDeleting,
    required this.isTransferring,
    required this.isResettingThumbnails,
    required this.isInitialLoading,
    required this.busy,
    required this.onEnterSelection,
    required this.onExitSelection,
    required this.onBatchDelete,
    required this.onBatchTransfer,
    required this.canResetThumbnails,
    required this.resetThumbnailsLabel,
    required this.onBatchResetThumbnails,
    required this.onRefresh,
    required this.searchToggle,
  });

  final bool hasItems;
  final bool selectionMode;
  final bool hasSelection;
  final int selectionCount;
  final bool allLoadedSelected;
  final bool isDeleting;
  final bool isTransferring;
  final bool isResettingThumbnails;
  final bool isInitialLoading;
  final bool busy;
  final VoidCallback? onEnterSelection;
  final VoidCallback? onExitSelection;
  final Future<void> Function() onBatchDelete;
  final Future<void> Function() onBatchTransfer;
  final bool canResetThumbnails;
  final String resetThumbnailsLabel;
  final Future<void> Function()? onBatchResetThumbnails;
  final VoidCallback onRefresh;
  final Widget? searchToggle;

  void _exitSelection(WidgetRef ref) {
    ref.read(mediaBrowseProvider.notifier).clearSelection();
    onExitSelection?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    if (!selectionMode) {
      return Wrap(
        spacing: spacing.xs,
        runSpacing: spacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppSelectionEntryButton(
            key: const Key('media-management-enter-selection-button'),
            onPressed: hasItems && !busy ? onEnterSelection : null,
          ),
          AppIconButton(
            key: const Key('media-management-refresh-button'),
            tooltip: isInitialLoading
                ? l10n.mediaListRefreshing
                : l10n.commonRefresh,
            icon: const Icon(Icons.refresh_rounded),
            onPressed: isInitialLoading ? null : onRefresh,
          ),
          ?searchToggle,
        ],
      );
    }
    return Wrap(
      spacing: spacing.xs,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(
          key: const Key('media-management-select-all-button'),
          label: allLoadedSelected
              ? l10n.mediaListClearSelectAllLoaded
              : l10n.mediaListSelectAllLoaded,
          size: AppButtonSize.small,
          variant: AppButtonVariant.secondary,
          onPressed: !hasItems || busy
              ? null
              : () => ref
                    .read(mediaBrowseProvider.notifier)
                    .toggleSelectAllLoaded(),
        ),
        if (hasSelection)
          AppButton(
            key: const Key('media-management-batch-transfer-button'),
            label: l10n.mediaListBatchTransfer(selectionCount),
            size: AppButtonSize.small,
            icon: const Icon(Icons.drive_file_move_outline),
            isLoading: isTransferring,
            onPressed: busy ? null : onBatchTransfer,
          ),
        if (hasSelection &&
            canResetThumbnails &&
            onBatchResetThumbnails != null)
          AppButton(
            key: const Key('media-management-batch-reset-thumbnails-button'),
            label: l10n.mediaListBatchResetThumbnailsCount(
              resetThumbnailsLabel,
              selectionCount,
            ),
            size: AppButtonSize.small,
            icon: const Icon(Icons.refresh_rounded),
            isLoading: isResettingThumbnails,
            onPressed: busy ? null : onBatchResetThumbnails,
          ),
        if (hasSelection)
          AppButton(
            key: const Key('media-management-batch-delete-button'),
            label: l10n.mediaListBatchDelete(selectionCount),
            size: AppButtonSize.small,
            variant: AppButtonVariant.danger,
            icon: const Icon(Icons.delete_outline_rounded),
            isLoading: isDeleting,
            onPressed: busy ? null : onBatchDelete,
          ),
        AppTextButton(
          key: const Key('media-management-exit-selection-button'),
          label: l10n.mediaListExitSelection,
          size: AppTextButtonSize.small,
          onPressed: busy ? null : () => _exitSelection(ref),
        ),
      ],
    );
  }
}

/// 文件名搜索固定回车提交，避免每次输入都触发带前导通配符的分页计数查询。
class _MediaFileNameSearchField extends StatefulWidget {
  const _MediaFileNameSearchField({
    required this.fieldKey,
    required this.clearButtonKey,
    required this.search,
    required this.onSubmitted,
  });

  final Key fieldKey;
  final Key clearButtonKey;
  final String search;
  final ValueChanged<String> onSubmitted;

  @override
  State<_MediaFileNameSearchField> createState() =>
      _MediaFileNameSearchFieldState();
}

class _MediaFileNameSearchFieldState extends State<_MediaFileNameSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.search);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void didUpdateWidget(covariant _MediaFileNameSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search &&
        _controller.text != widget.search) {
      _controller.value = TextEditingValue(
        text: widget.search,
        selection: TextSelection.collapsed(offset: widget.search.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final normalized = value.trim();
    if (_controller.text != normalized) {
      _controller.value = TextEditingValue(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
    }
    widget.onSubmitted(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formTokens = context.appFormTokens;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) => AppTextField(
        fieldKey: widget.fieldKey,
        controller: _controller,
        focusNode: _focusNode,
        hintText: l10n.mediaListSearchFileNameHint,
        textInputAction: TextInputAction.search,
        height: formTokens.compactFieldHeight,
        borderRadius: context.appRadius.smBorder,
        contentPadding: EdgeInsets.symmetric(
          horizontal: formTokens.fieldHorizontalPadding,
        ),
        prefix: Icon(
          Icons.search_rounded,
          size: context.appComponentTokens.iconSizeSm,
          color: context.appTextPalette.muted,
        ),
        suffix: value.text.isEmpty
            ? null
            : AppIconButton(
                key: widget.clearButtonKey,
                tooltip: l10n.baseClearSearch,
                semanticLabel: l10n.baseClearSearch,
                icon: const Icon(Icons.close_rounded),
                size: AppIconButtonSize.mini,
                onPressed: () {
                  _controller.clear();
                  widget.onSubmitted('');
                },
              ),
        tightSuffix: true,
        onFieldSubmitted: _submit,
      ),
    );
  }
}
