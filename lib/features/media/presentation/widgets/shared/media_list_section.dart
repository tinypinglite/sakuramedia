import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/data/media_storage_descriptor.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_browse_provider.dart';
import 'package:sakuramedia/features/media/presentation/providers/media_libraries_provider.dart';
import 'package:sakuramedia/features/media/presentation/widgets/media_browse_filter_toolbar.dart';
import 'package:sakuramedia/features/media/presentation/widgets/mobile/media_mobile_list_card.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_cover_thumbnail.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_meta_line.dart';
import 'package:sakuramedia/features/media/presentation/widgets/shared/media_list_item_path_line.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_async_section.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_badge.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_left_cover_card.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart'
    show AppFilterPanelFooter;

/// 「媒体管理」列表 tab 的主体：筛选头 + 白底 media card 列表（桌面 / 移动共用）。
///
/// 数据源：`mediaBrowseProvider` + `mediaLibrariesProvider`。多选、筛选、reload 全部
/// 由内部 `ref.read(...notifier)` 触发；父页只提供跨 provider 的动作（秒传弹窗、批量
/// 删除、复合刷新）。
///
/// 平台差异（`mobile: true` 时启用）：
/// - 行卡片：桌面固定行高 `_MediaRow` / 移动流式 [MediaMobileListCard]（长按进入多选态）；
/// - 筛选入口：桌面 popover 工具栏 / 移动底部抽屉（`MediaBrowseFilterSectionGroup` 复用）；
/// - 多选：桌面顶栏按钮流 / 移动 `AppListHeader.selection`（顶）+ `AppSelectionBottomBar`（底）。
///
/// 视觉参考「下载任务」卡片（[_DownloadTaskCard]）：页面灰底 + 每张 media card 直接浮起
/// 为独立白卡（不再套 `AppContentCard`）。多选操作全部收敛到顶部 [AppFilterTotalHeader]
/// 的 trailing，跟筛选、总数、刷新同一条行。
class MediaListSection extends StatelessWidget {
  const MediaListSection({
    super.key,
    required this.scrollController,
    required this.isTriggering,
    required this.isDeleting,
    required this.onRapidUpload,
    required this.onBatchDelete,
    this.onRefresh,
    this.onOpenMovieDetail,
    this.keyPrefix = 'media-management',
    this.mobile = false,
    this.selectionMode = false,
    this.onEnterSelection,
    this.onExitSelection,
  });

  final ScrollController scrollController;

  /// 秒传触发中——按钮 spinner；由父页承担因为秒传流程含跨库弹窗 + api + toast。
  final bool isTriggering;

  /// 批量删除进行中——按钮 spinner + 禁用其它多选动作；父页编排 confirm + 串行循环。
  final bool isDeleting;

  /// 父页秒传入口：弹目标库对话框 → 调 `mediaApi.createMediaRapidUpload` → 从列表移除。
  final Future<void> Function() onRapidUpload;

  /// 父页批量删除入口：弹二次确认 → 串行循环 `mediaApi.deleteMedia` → 汇总 toast。
  final Future<void> Function() onBatchDelete;

  /// 可选：父页复合刷新（例如同时刷新秒传批次）；不传则默认刷新媒体列表 + 媒体库。
  final Future<void> Function()? onRefresh;

  /// 可选：媒体封面点击跳影片详情（JAV 项）；不传则封面不可点。
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

  @override
  Widget build(BuildContext context) {
    final scrollView = CustomScrollView(
      key: Key('$keyPrefix-list-scroll-view'),
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _MediaListHeader(
            keyPrefix: keyPrefix,
            mobile: mobile,
            selectionMode: selectionMode,
            isTriggering: isTriggering,
            isDeleting: isDeleting,
            onRapidUpload: onRapidUpload,
            onBatchDelete: onBatchDelete,
            onRefresh: onRefresh,
            onExitSelection: onExitSelection,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
        _MediaListBodySliver(
          keyPrefix: keyPrefix,
          mobile: mobile,
          selectionMode: selectionMode,
          onEnterSelection: onEnterSelection,
          onOpenMovieDetail: onOpenMovieDetail,
        ),
      ],
    );

    // 移动端多选态：列表下方常驻批量操作条（删除 / 秒传）。
    if (mobile && selectionMode) {
      return Column(
        children: [
          Expanded(child: scrollView),
          _MediaMobileSelectionBar(
            keyPrefix: keyPrefix,
            isTriggering: isTriggering,
            isDeleting: isDeleting,
            onRapidUpload: onRapidUpload,
            onBatchDelete: onBatchDelete,
          ),
        ],
      );
    }
    return scrollView;
  }
}

class _MediaListHeader extends ConsumerWidget {
  const _MediaListHeader({
    required this.keyPrefix,
    required this.mobile,
    required this.selectionMode,
    required this.isTriggering,
    required this.isDeleting,
    required this.onRapidUpload,
    required this.onBatchDelete,
    required this.onRefresh,
    required this.onExitSelection,
  });

  final String keyPrefix;
  final bool mobile;
  final bool selectionMode;
  final bool isTriggering;
  final bool isDeleting;
  final Future<void> Function() onRapidUpload;
  final Future<void> Function() onBatchDelete;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onExitSelection;

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
    unawaited(
      ref
          .read(mediaBrowseProvider.notifier)
          .applyFilterState(MediaBrowseFilterState.initial),
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
    final busy = isTriggering || isDeleting;
    final allLoadedSelected = currentState?.allLoadedSelected ?? false;

    // 移动端多选态：顶栏换 `AppListHeader.selection`（退出 / 计数 / 全选），
    // 与 PornBox / 订阅列表的多选顶栏同一套组件；高度与常规顶栏严格一致。
    if (mobile && selectionMode) {
      return AppListHeader.selection(
        key: Key('$keyPrefix-selection-header'),
        selectionLabel: '已选 $selectionCount 项',
        selectionExitButtonKey: Key('$keyPrefix-exit-selection-button'),
        onExitSelection: () {
          ref.read(mediaBrowseProvider.notifier).clearSelection();
          onExitSelection?.call();
        },
        actionSlots: [
          AppTextButton(
            key: Key('$keyPrefix-select-all-button'),
            label: allLoadedSelected ? '取消全选本页' : '全选本页',
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

    // 移动端非多选态：筛选入口（开底部抽屉）+ 总数 + 刷新，用双端共用的
    // AppListHeader（常规态与多选态由同一个组件原地切换）。
    if (mobile) {
      return AppListHeader(
        key: Key('$keyPrefix-header'),
        onFilterTap: () => _openMobileFilterDrawer(
          context,
          filter: filter,
          libraries: librariesState.libraries,
          ref: ref,
        ),
        filterLabel: filter.triggerLabel,
        filterButtonKey: Key('$keyPrefix-filter-trigger'),
        filterTooltip: '筛选',
        filterUpdate:
            currentState?.paged.filterUpdate ?? const FilterUpdateState.idle(),
        hasPreviousFilterItems: hasItems,
        onRetryFilter: () =>
            unawaited(ref.read(mediaBrowseProvider.notifier).retryFilter()),
        informationSlots: [
          AppListHeaderInfo(
            key: Key('$keyPrefix-total-text'),
            label: '共 $total 条',
          ),
        ],
        actionSlots: [
          AppIconButton(
            key: Key('$keyPrefix-refresh-button'),
            tooltip: isInitialLoading ? '刷新中' : '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: isInitialLoading
                ? null
                : () {
                    unawaited((onRefresh ?? () => _defaultRefresh(ref))());
                  },
          ),
        ],
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
          ? '共 $total 条 · 已选 $selectionCount 项'
          : '共 $total 条',
      totalKey: const Key('media-management-total-text'),
      filterUpdate:
          currentState?.paged.filterUpdate ?? const FilterUpdateState.idle(),
      hasPreviousFilterItems: hasItems,
      onRetryFilter: () =>
          unawaited(ref.read(mediaBrowseProvider.notifier).retryFilter()),
      trailing: _MediaListActionBar(
        hasItems: hasItems,
        hasSelection: hasSelection,
        selectionCount: selectionCount,
        allLoadedSelected: allLoadedSelected,
        isTriggering: isTriggering,
        isDeleting: isDeleting,
        isInitialLoading: isInitialLoading,
        busy: busy,
        onRapidUpload: onRapidUpload,
        onBatchDelete: onBatchDelete,
        onRefresh: () => unawaited((onRefresh ?? () => _defaultRefresh(ref))()),
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
        isDefault: _local.isDefault,
        onReset: () => _apply(MediaBrowseFilterState.initial),
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
  });

  final String keyPrefix;
  final bool mobile;
  final bool selectionMode;
  final VoidCallback? onEnterSelection;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 多选集合变化时 paged 段保持相等，因此列表 sliver 不会整体重建；
    // 每一行通过 [_MediaRowConsumer] 只订阅自己的选中态。
    final asyncPaged = ref.watch(
      mediaBrowseProvider.select(
        (asyncState) => asyncState.whenData((state) => state.paged),
      ),
    );

    return SliverPagedAsyncSection<
      PagedListState<MediaListItemDto>,
      MediaListItemDto
    >(
      asyncState: asyncPaged,
      pagedOf: (state) => state,
      itemSpacing: context.appSpacing.sm,
      fixedItemExtent: mobile
          ? null
          : context.appComponentTokens.mediaManagementRowHeight,
      initialErrorMessage: '媒体列表加载失败，请稍后重试',
      emptyMessage: '当前筛选下没有媒体记录。调整筛选条件或稍后再试。',
      initialRetryKey: Key('$keyPrefix-initial-retry-button'),
      onReload: () =>
          unawaited(ref.read(mediaBrowseProvider.notifier).reload()),
      onLoadMore: () =>
          unawaited(ref.read(mediaBrowseProvider.notifier).loadMore()),
      itemBuilder: (context, item, _) => mobile
          ? _MediaMobileRowConsumer(
              keyPrefix: keyPrefix,
              item: item,
              selectionMode: selectionMode,
              onEnterSelection: onEnterSelection,
              onOpenMovieDetail: onOpenMovieDetail,
            )
          : _MediaRowConsumer(item: item, onOpenMovieDetail: onOpenMovieDetail),
    );
  }
}

/// 移动端行 consumer：订阅选中态 / 存储描述 / 禁选原因，组装 [MediaMobileListCard]。
class _MediaMobileRowConsumer extends ConsumerWidget {
  const _MediaMobileRowConsumer({
    required this.keyPrefix,
    required this.item,
    required this.selectionMode,
    required this.onEnterSelection,
    this.onOpenMovieDetail,
  });

  final String keyPrefix;
  final MediaListItemDto item;
  final bool selectionMode;
  final VoidCallback? onEnterSelection;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(
      mediaBrowseProvider.select(
        (asyncState) => asyncState.value?.isSelected(item.id) ?? false,
      ),
    );
    final storageDescriptors = ref.watch(
      mediaLibrariesProvider.select(
        (asyncState) =>
            asyncState.value?.storageDescriptors ??
            const <int, MediaStorageDescriptor>{},
      ),
    );
    final disabledReason = _disabledReasonFor(item);

    return MediaMobileListCard(
      keyPrefix: keyPrefix,
      item: item,
      storage: resolveMediaStorageDescriptor(
        item.libraryId,
        storageDescriptors,
      ),
      isSelected: isSelected,
      selectionMode: selectionMode,
      disabledReason: disabledReason,
      onLongPress: disabledReason != null
          ? null
          : () {
              ref.read(mediaBrowseProvider.notifier).toggleSelection(item.id);
              onEnterSelection?.call();
            },
      onToggleSelect: disabledReason != null
          ? null
          : () =>
                ref.read(mediaBrowseProvider.notifier).toggleSelection(item.id),
      onOpenMovieDetail: onOpenMovieDetail,
    );
  }
}

/// 移动端多选态底部批量操作条：删除（危险）+ 秒传到 115（主操作）等宽平分。
class _MediaMobileSelectionBar extends ConsumerWidget {
  const _MediaMobileSelectionBar({
    required this.keyPrefix,
    required this.isTriggering,
    required this.isDeleting,
    required this.onRapidUpload,
    required this.onBatchDelete,
  });

  final String keyPrefix;
  final bool isTriggering;
  final bool isDeleting;
  final Future<void> Function() onRapidUpload;
  final Future<void> Function() onBatchDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectionCount = ref.watch(
      mediaBrowseProvider.select(
        (asyncState) => asyncState.value?.selectionCount ?? 0,
      ),
    );
    final busy = isTriggering || isDeleting;
    return AppSelectionBottomBar(
      leading: Text(
        '已选 $selectionCount 项',
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
          key: Key('$keyPrefix-batch-delete-button'),
          label: '删除',
          variant: AppButtonVariant.danger,
          icon: const Icon(Icons.delete_outline_rounded),
          isLoading: isDeleting,
          onPressed: busy || selectionCount == 0 ? null : onBatchDelete,
        ),
        AppButton(
          key: Key('$keyPrefix-rapid-upload-button'),
          label: '秒传到 115',
          variant: AppButtonVariant.primary,
          icon: const Icon(Icons.cloud_upload_outlined),
          isLoading: isTriggering,
          onPressed: busy || selectionCount == 0 ? null : onRapidUpload,
        ),
      ],
    );
  }
}

class _MediaRowConsumer extends ConsumerWidget {
  const _MediaRowConsumer({required this.item, this.onOpenMovieDetail});

  final MediaListItemDto item;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = ref.watch(
      mediaBrowseProvider.select(
        (asyncState) => asyncState.value?.isSelected(item.id) ?? false,
      ),
    );
    final storageDescriptors = ref.watch(
      mediaLibrariesProvider.select(
        (asyncState) =>
            asyncState.value?.storageDescriptors ??
            const <int, MediaStorageDescriptor>{},
      ),
    );
    final disabledReason = _disabledReasonFor(item);

    return _MediaRow(
      item: item,
      storage: resolveMediaStorageDescriptor(
        item.libraryId,
        storageDescriptors,
      ),
      isSelected: isSelected,
      // 有禁选原因的行不响应 tap（且 _MediaRow 会挂 Tooltip 告诉用户原因）；
      // 后端 active_media_id 唯一约束会拒绝新批次，前端提前拦截更友好。
      disabledReason: disabledReason,
      onToggle: disabledReason != null
          ? null
          : () =>
                ref.read(mediaBrowseProvider.notifier).toggleSelection(item.id),
      onOpenMovieDetail: onOpenMovieDetail,
    );
  }
}

/// 顶栏右侧多选操作条：全选 / 清空 / 批量删除 / 秒传 / 刷新。
///
/// 无选择态：仅保留「全选本页」+「刷新」（不占空间过多，视觉上不喧宾夺主）；
/// 有选择态：追加「清空 / 批量删除 / 秒传到 115」，主/危险色收拢注意力。
class _MediaListActionBar extends ConsumerWidget {
  const _MediaListActionBar({
    required this.hasItems,
    required this.hasSelection,
    required this.selectionCount,
    required this.allLoadedSelected,
    required this.isTriggering,
    required this.isDeleting,
    required this.isInitialLoading,
    required this.busy,
    required this.onRapidUpload,
    required this.onBatchDelete,
    required this.onRefresh,
  });

  final bool hasItems;
  final bool hasSelection;
  final int selectionCount;
  final bool allLoadedSelected;
  final bool isTriggering;
  final bool isDeleting;
  final bool isInitialLoading;
  final bool busy;
  final Future<void> Function() onRapidUpload;
  final Future<void> Function() onBatchDelete;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.appSpacing;
    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AppButton(
          key: const Key('media-management-select-all-button'),
          label: allLoadedSelected ? '取消全选本页' : '全选本页',
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
            key: const Key('media-management-clear-selection-button'),
            label: '清空选择',
            size: AppButtonSize.small,
            variant: AppButtonVariant.secondary,
            onPressed: busy
                ? null
                : () => ref.read(mediaBrowseProvider.notifier).clearSelection(),
          ),
        if (hasSelection)
          AppButton(
            key: const Key('media-management-batch-delete-button'),
            label: '批量删除（$selectionCount）',
            size: AppButtonSize.small,
            variant: AppButtonVariant.danger,
            icon: const Icon(Icons.delete_outline_rounded),
            isLoading: isDeleting,
            onPressed: busy ? null : onBatchDelete,
          ),
        if (hasSelection)
          AppButton(
            key: const Key('media-management-rapid-upload-button'),
            label: '秒传到 115（$selectionCount）',
            size: AppButtonSize.small,
            variant: AppButtonVariant.primary,
            icon: const Icon(Icons.cloud_upload_outlined),
            isLoading: isTriggering,
            onPressed: busy ? null : onRapidUpload,
          ),
        AppIconButton(
          key: const Key('media-management-refresh-button'),
          tooltip: isInitialLoading ? '刷新中' : '刷新',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: isInitialLoading ? null : onRefresh,
        ),
      ],
    );
  }
}

/// 单条 media 卡片：走 [AppLeftCoverCard] 外壳（封面贴左的白底卡），整卡点选、
/// 选中态外框换 `selectionBorder`（无 checkbox，靠外框传达选中）。
///
/// 内容层次（自上而下）：
/// 1) 标题栏：标题（一行）+ 可选副标题；右上贴角「失效」badge（仅无效时显示）。
/// 2) 元数据 Wrap：kind / 存储位置 / 库名 compact badge + 大小 / 时长 / 分辨率 muted 文本。
/// 3) 路径行：folder icon + 相对路径 muted；右侧「更新 …」（若有）。
///
/// 封面区独立 InkWell：JAV 项跳影片详情，视频项无跳转（videos 域没有单视频详情页）。
class _MediaRow extends StatelessWidget {
  const _MediaRow({
    required this.item,
    required this.storage,
    required this.isSelected,
    required this.onToggle,
    this.disabledReason,
    this.onOpenMovieDetail,
  });

  final MediaListItemDto item;
  final MediaStorageDescriptor storage;
  final bool isSelected;

  /// 非空时行禁选：`onToggle` 应传 null，`disabledReason` 会作为 Tooltip 文案挂在整卡上。
  final String? disabledReason;
  final VoidCallback? onToggle;

  /// 封面跳影片详情回调（JAV 项）；null 时封面纯图不可点。
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final componentTokens = context.appComponentTokens;

    final card = AppLeftCoverCard(
      key: Key('media-management-row-${item.id}'),
      coverWidth: componentTokens.downloadTaskCoverWidth,
      bodyMinHeight: componentTokens.mediaManagementRowHeight,
      bodyPadding: EdgeInsets.symmetric(
        horizontal: spacing.lg,
        vertical: spacing.md,
      ),
      selected: isSelected,
      onTap: onToggle,
      cover: _MediaCoverSlot(item: item, onOpenMovieDetail: onOpenMovieDetail),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaHeadingLine(item: item),
          SizedBox(height: spacing.md),
          MediaListItemMetaLine(
            item: item,
            storage: storage,
            spacing: spacing.sm,
            runSpacing: spacing.xs,
          ),
          SizedBox(height: spacing.sm),
          MediaListItemPathLine(
            keyPrefix: 'media-management',
            item: item,
            storage: storage,
            showUpdatedAt: true,
          ),
        ],
      ),
    );

    // 项目约定没有 AppTooltip 包装件，直接用 Flutter 原生。
    final reason = disabledReason;
    if (reason != null) {
      return Tooltip(message: reason, child: card);
    }
    return card;
  }
}

/// 集中的行禁选决策：目前仅有秒传进行中一种原因，未来加新原因（例如批量删除
/// 排队中）直接在这里返回相应文案；`_MediaRow` 只关心"有无原因"。
String? _disabledReasonFor(MediaListItemDto item) {
  if (item.lastRapidUploadStatus == LastRapidUploadStatus.inProgress) {
    return '已在秒传批次中，无法加入新操作';
  }
  return null;
}

/// 封面 slot：宽图横向铺满，`BoxFit.cover` 横向裁切；JAV 且有番号 → InkWell
/// 独立可点跳详情；否则纯图/占位。
///
/// 内层 InkWell 会拦截手势不冒泡到外层"切换选中"，两层交互天然分离。
/// URL 优先取 `coverImage`（横版）而非 `thin_cover_image`（竖版 thin）。
class _MediaCoverSlot extends StatelessWidget {
  const _MediaCoverSlot({required this.item, this.onOpenMovieDetail});

  final MediaListItemDto item;
  final void Function(BuildContext context, String movieNumber)?
  onOpenMovieDetail;

  String? get _wideCoverUrl {
    final coverUrl = item.coverImage?.bestAvailableUrl.trim();
    if (coverUrl != null && coverUrl.isNotEmpty) {
      return coverUrl;
    }
    final thinUrl = item.thinCoverImage?.bestAvailableUrl.trim();
    if (thinUrl != null && thinUrl.isNotEmpty) {
      return thinUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final url = _wideCoverUrl;
    final componentTokens = context.appComponentTokens;
    final image = MediaCoverThumbnail(
      url: url,
      width: componentTokens.downloadTaskCoverWidth,
      height: componentTokens.mediaManagementRowHeight,
      fit: BoxFit.cover,
      placeholderKey: Key('media-management-cover-placeholder-${item.id}'),
      imageKey: Key('media-management-cover-${item.id}'),
      placeholderBackground: context.appColors.surfaceMuted,
    );

    // JAV 且有番号：封面独立可点，跳影片详情。videos 域无单视频详情页，视频项
    // 封面保持纯图（点击冒泡到外层触发选中）。
    final movieNumber = item.movieNumber?.trim();
    final openMovieDetail = onOpenMovieDetail;
    if (!item.isJav || movieNumber == null || movieNumber.isEmpty) {
      return image;
    }
    if (openMovieDetail == null) {
      return image;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('media-management-cover-tap-${item.id}'),
        onTap: () => openMovieDetail(context, movieNumber),
        child: image,
      ),
    );
  }
}

/// 标题栏：标题 + 可选副标题；右上贴角「失效」badge（仅无效时）。
class _MediaHeadingLine extends StatelessWidget {
  const _MediaHeadingLine({required this.item});

  final MediaListItemDto item;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.displayHeading,
                key: Key('media-management-row-heading-${item.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
              if (item.displaySubtitle != null) ...[
                SizedBox(height: spacing.xs),
                Text(
                  item.displaySubtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.regular,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!item.valid) ...[
          SizedBox(width: spacing.sm),
          const AppBadge(
            label: '失效',
            tone: AppBadgeTone.error,
            size: AppBadgeSize.compact,
          ),
        ],
      ],
    );
  }
}

/// 元数据行 / 路径行已抽为共享件 [MediaListItemMetaLine] /
/// [MediaListItemPathLine]（`widgets/shared/media_list_item_*_line.dart`），
/// 桌面行与移动卡共用；badge 映射走 [rapidUploadStatusBadge]。
