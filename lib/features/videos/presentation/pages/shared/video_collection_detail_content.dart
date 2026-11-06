import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:sakuramedia/widgets/base/feedback/app_toast.dart';
import 'package:sakuramedia/core/network/api_error_message.dart';
import 'package:sakuramedia/features/shared/data/batch_operation_dto.dart';
import 'package:sakuramedia/features/shared/presentation/batch_operation_submit.dart';
import 'package:sakuramedia/features/shared/presentation/providers/batch_operation_submission_provider.dart';
import 'package:sakuramedia/features/shared/presentation/providers/collection_playback_handoff_provider.dart';
import 'package:sakuramedia/features/videos/data/dto/video_collection_dto.dart';
import 'package:sakuramedia/features/videos/presentation/actions/video_playback_launcher.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/pages/desktop/video_actions_dialog.dart';
import 'package:sakuramedia/features/videos/presentation/pages/mobile/video_actions_sheet.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_detail_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_collection_detail_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_mutation_events_provider.dart';
import 'package:sakuramedia/features/videos/presentation/providers/videos_api_provider.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/videos/presentation/video_display_title.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/collections/pick_video_collection_dialog.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/mobile_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';
import 'package:sakuramedia/widgets/base/feedback/app_filter_result_loading_overlay.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/layout/grids/app_adaptive_card_grid.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/app_selection_bottom_bar.dart';
import 'package:sakuramedia/widgets/base/interaction/selection/multi_select_state_mixin.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_list_header.dart';
import 'package:sakuramedia/widgets/domain/collections/collection_member_views.dart';
import 'package:sakuramedia/widgets/domain/videos/video_collection_sort_menu_button.dart';
import 'package:sakuramedia/widgets/shell/mobile/app_mobile_subpage_shell.dart';

/// 视频合集详情共享实现（桌面 / 移动双端壳收敛的 content 层）。
///
/// 只保留 `mobile` 作为平台语义；具体用哪套路由、弹层和动作壳由本层判断。
class VideoCollectionDetailContent extends ConsumerStatefulWidget {
  const VideoCollectionDetailContent({
    super.key,
    required this.collectionId,
    required this.surfaceColor,
    required this.keyPrefix,
    required this.mobile,
  });

  final int collectionId;
  final Color surfaceColor;
  final String keyPrefix;
  final bool mobile;

  @override
  ConsumerState<VideoCollectionDetailContent> createState() =>
      _VideoCollectionDetailContentState();
}

class _VideoCollectionDetailContentState
    extends ConsumerState<VideoCollectionDetailContent>
    with MultiSelectStateMixin<VideoCollectionDetailContent, int> {
  late final ScrollController _itemsScrollController;
  final _listHeaderKey = GlobalKey();

  VideoCollectionDetailProvider get _providerRef =>
      videoCollectionDetailProvider(widget.collectionId);

  VideoMutationEvents get _mutationBroadcaster =>
      ref.read(videoMutationEventsProvider.notifier);

  bool get _isMobile => widget.mobile;

  @override
  List<int> get selectionOrderedIds =>
      ref
          .read(_providerRef)
          .value
          ?.items
          .map((item) => item.video.id)
          .toList(growable: false) ??
      const <int>[];

  @override
  void initState() {
    super.initState();
    _itemsScrollController = ScrollController();
  }

  @override
  void dispose() {
    _itemsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_providerRef);
    final state = async.value;
    final notifier = ref.read(_providerRef.notifier);
    if (_isMobile) {
      _reportTitle(state);
    }
    final isLoading = async.isLoading && state == null;

    final content = Builder(
      builder: (context) {
        if (!isLoading && async.hasError && state == null) {
          return _buildError(context, async.error!);
        }
        if (!isLoading && state == null) {
          return const SizedBox.shrink();
        }
        // loading 用占位数据渲染同一份真实布局，由 [AppSkeletonizer] 灰化，
        // 骨架与数据到位后的首屏严格同形。
        final displayState = isLoading
            ? videoCollectionDetailPlaceholder()
            : state!;
        final hasListHeader =
            displayState.items.isNotEmpty || !displayState.filterUpdate.isIdle;
        return AppSkeletonizer(
          enabled: isLoading,
          child: _isMobile
              ? _buildMobileLayout(
                  context,
                  displayState,
                  hasListHeader: hasListHeader,
                )
              : _buildDesktopLayout(
                  context,
                  displayState,
                  hasListHeader: hasListHeader,
                ),
        );
      },
    );

    if (_isMobile) {
      return content;
    }
    return AppPageRefreshScope(onRefresh: notifier.refresh, child: content);
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    VideoCollectionDetailState state, {
    required bool hasListHeader,
  }) {
    final description = state.collection.description.trim();
    return Column(
      key: Key('${widget.keyPrefix}-detail-page'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isMobile && !hasListHeader) _buildTitleBlock(context, state),
        if (hasListHeader)
          selectionMode
              ? _buildSelectionHeader(context, state)
              : _buildListHeader(context, state),
        if (!_isMobile &&
            hasListHeader &&
            !selectionMode &&
            description.isNotEmpty) ...[
          SizedBox(height: context.appSpacing.sm),
          Text(
            description,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
        SizedBox(height: context.appSpacing.lg),
        Expanded(
          child: AppFilterResultLoadingOverlay(
            surfaceColor: widget.surfaceColor,
            isLoading: state.filterUpdate.isLoading,
            hasPreviousItems: state.items.isNotEmpty,
            child: _buildBody(context, state),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    VideoCollectionDetailState state, {
    required bool hasListHeader,
  }) {
    final description = state.collection.description.trim();
    return Column(
      key: Key('${widget.keyPrefix}-detail-page'),
      children: [
        Expanded(
          child: AppFilterResultLoadingOverlay(
            surfaceColor: widget.surfaceColor,
            isLoading: state.filterUpdate.isLoading,
            hasPreviousItems: state.items.isNotEmpty,
            child: CustomScrollView(
              key: Key('${widget.keyPrefix}-detail-scroll'),
              controller: _itemsScrollController,
              slivers: <Widget>[
                if (hasListHeader)
                  AppPinnedSliverSection(
                    headerKey: _listHeaderKey,
                    before: <Widget>[
                      if (_isMobile) ...[
                        SliverToBoxAdapter(
                          child: _buildMobileHero(context, state),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: context.appSpacing.md),
                        ),
                      ],
                    ],
                    header: selectionMode
                        ? _buildSelectionHeader(context, state)
                        : _buildListHeader(context, state),
                    headerBottomSpacing: context.appSpacing.md,
                    after: <Widget>[
                      if (!_isMobile &&
                          !selectionMode &&
                          description.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: context.appSpacing.md,
                            ),
                            child: Text(
                              description,
                              style: resolveAppTextStyle(
                                context,
                                size: AppTextSize.s14,
                                weight: AppTextWeight.regular,
                                tone: AppTextTone.secondary,
                              ),
                            ),
                          ),
                        ),
                      ..._buildMobileBodySlivers(context, state),
                    ],
                  )
                else ...[
                  if (_isMobile) ...[
                    SliverToBoxAdapter(child: _buildMobileHero(context, state)),
                    SliverToBoxAdapter(
                      child: SizedBox(height: context.appSpacing.md),
                    ),
                  ] else
                    SliverToBoxAdapter(child: _buildTitleBlock(context, state)),
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.appSpacing.md),
                  ),
                  ..._buildMobileBodySlivers(context, state),
                ],
              ],
            ),
          ),
        ),
        if (selectionMode) _buildBatchBar(context, state),
      ],
    );
  }

  // --------------------------------------------------------- 状态三态

  Widget _buildError(BuildContext context, Object error) {
    final l10n = AppLocalizations.of(context);
    final message = apiErrorMessage(
      error,
      fallback: l10n.videoCollectionsLoadFailed,
      l10n: l10n,
    );
    if (_isMobile) {
      return AppEmptyState(message: message);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppEmptyState(message: message),
        SizedBox(height: context.appSpacing.md),
        AppButton(
          label: l10n.commonRetry,
          variant: AppButtonVariant.secondary,
          onPressed: () => ref.read(_providerRef.notifier).refresh(),
        ),
      ],
    );
  }

  // --------------------------------------------------------- 标题块

  /// 空合集标题块：有成员时合集名和「播放全部」收进筛选栏，不再单独占行。
  Widget _buildTitleBlock(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    final collection = state.collection;
    final description = collection.description.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          collection.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: resolveAppTextStyle(
            context,
            // 与切片合集详情统一 s18——两个合集详情是姊妹页。
            size: AppTextSize.s18,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ),
        ),
        if (description.isNotEmpty) ...[
          SizedBox(height: context.appSpacing.sm),
          Text(
            description,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.regular,
              tone: AppTextTone.secondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMobileHero(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    final collection = state.collection;
    final description = collection.description.trim();
    final coverUrl = collection.coverImage?.origin.trim();
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final overlay = context.appColors.mediaOverlayStrong;

    return ClipRRect(
      key: const Key('mobile-video-collection-hero'),
      borderRadius: context.appRadius.lgBorder,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: context.appColors.surfaceMuted),
            if (coverUrl != null && coverUrl.isNotEmpty)
              MaskedImage(url: coverUrl, fit: BoxFit.cover)
            else
              Center(
                child: Icon(
                  Icons.video_collection_outlined,
                  size: context.appComponentTokens.iconSizeXl,
                  color: context.appTextPalette.muted,
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    overlay.withValues(alpha: 0.08),
                    overlay.withValues(alpha: 0.18),
                    overlay.withValues(alpha: 0.9),
                  ],
                  stops: const <double>[0, 0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: spacing.lg,
              right: spacing.md,
              bottom: spacing.md,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: resolveAppTextStyle(
                            context,
                            size: AppTextSize.s24,
                            weight: AppTextWeight.semibold,
                            tone: AppTextTone.onMedia,
                            height: 1.08,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          SizedBox(height: spacing.xs),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                resolveAppTextStyle(
                                  context,
                                  size: AppTextSize.s12,
                                  weight: AppTextWeight.regular,
                                  tone: AppTextTone.onMedia,
                                  height: 1.35,
                                ).copyWith(
                                  color: context.appTextPalette.onMedia
                                      .withValues(alpha: 0.78),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: spacing.md),
                  AppGlassIconButton(
                    key: const Key('mobile-video-collection-hero-play-button'),
                    tooltip: l10n.videoPlayAll,
                    icon: Icons.play_arrow_rounded,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    size: 48,
                    iconSize: 26,
                    prominent: true,
                    onPressed: state.items.isEmpty ? null : () => _playFrom(0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 把合集名报给外层返回栏。数据是异步来的，所以每次 build 后用
  /// post-frame 回调写——直接在 build 里改 notifier 会触发 build-during-build。
  void _reportTitle(VideoCollectionDetailState? state) {
    final name = state?.collection.name.trim() ?? '';
    if (name.isEmpty) {
      return;
    }
    final notifier = AppMobileSubpageTitle.read(context);
    if (notifier == null || notifier.value == name) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        notifier.value = name;
      }
    });
  }

  // --------------------------------------------------------- 顶栏

  /// 移动成员列表顶栏：玻璃外标题/计数 + 图标操作。
  Widget _buildListHeader(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    if (!_isMobile) {
      return _buildDesktopGlassListHeader(context, state);
    }
    final count = state.collection.itemCount == 0
        ? state.items.length
        : state.collection.itemCount;
    final l10n = AppLocalizations.of(context);
    return AppMobileListHeader(
      leading: AppMobileHeaderText(
        key: Key('${widget.keyPrefix}-total'),
        countLabel: l10n.videoCollectionVideoCount(count),
      ),
      actions: <Widget>[
        VideoCollectionSortMenuButton(
          triggerKey: Key('${widget.keyPrefix}-sort-trigger'),
          panelKey: Key('${widget.keyPrefix}-sort-panel'),
          drawerKey: const Key('mobile-video-collection-sort-drawer'),
          keyPrefix: widget.keyPrefix,
          sort: state.sort,
          onChanged: _applySort,
          useDrawer: _isMobile,
          iconOnly: true,
        ),
        if (state.items.isNotEmpty)
          AppGlassIconButton(
            key: const Key('mobile-video-collection-play-all-button'),
            tooltip: l10n.videoPlayAll,
            icon: Icons.play_arrow_rounded,
            onPressed: () => _playFrom(0),
          ),
        AppGlassIconButton(
          key: Key('${widget.keyPrefix}-enter-selection-button'),
          tooltip: l10n.videoSelect,
          icon: Icons.check_circle_outline,
          onPressed: enterSelection,
        ),
      ],
      filterUpdate: state.filterUpdate,
      hasPreviousFilterItems: state.items.isNotEmpty,
      onRetryFilter: () =>
          unawaited(ref.read(_providerRef.notifier).retrySort()),
    );
  }

  /// 桌面端把合集名、排序、成员数和「播放全部 / 选择」收进同一条筛选栏。
  /// 外层 [AppGlassListHeader] 横向可滚动，窗口变窄时操作不会被截断。
  Widget _buildDesktopGlassListHeader(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    final l10n = AppLocalizations.of(context);
    final collection = state.collection;
    final count = state.collection.itemCount == 0
        ? state.items.length
        : state.collection.itemCount;
    return AppGlassListHeader(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Tooltip(
            message: collection.name,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.appLayoutTokens.filterFieldWidthXl,
              ),
              child: Text(
                collection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s18,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
          ),
          SizedBox(width: context.appSpacing.md),
          AppGlassHeaderGroup(
            children: <Widget>[
              VideoCollectionSortMenuButton(
                triggerKey: Key('${widget.keyPrefix}-sort-trigger'),
                panelKey: Key('${widget.keyPrefix}-sort-panel'),
                keyPrefix: widget.keyPrefix,
                sort: state.sort,
                onChanged: _applySort,
                glassGrouped: true,
                fieldControlKey: Key('${widget.keyPrefix}-sort-field'),
                directionControlKey: Key('${widget.keyPrefix}-sort-direction'),
              ),
              AppGlassHeaderText(
                key: Key('${widget.keyPrefix}-total'),
                label: l10n.videoCollectionVideoCount(count),
              ),
            ],
          ),
        ],
      ),
      trailing: AppGlassHeaderGroup(
        children: <Widget>[
          AppGlassHeaderButton(
            key: const Key('video-collection-play-all-button'),
            icon: Icons.play_arrow_rounded,
            label: l10n.videoPlayAll,
            enabled: state.items.isNotEmpty,
            onTap: () => _playFrom(0),
            foregroundColor: Theme.of(context).colorScheme.primary,
          ),
          AppGlassHeaderButton(
            key: Key('${widget.keyPrefix}-enter-selection-button'),
            icon: Icons.check_circle_outline,
            label: l10n.videoSelect,
            onTap: enterSelection,
          ),
        ],
      ),
      filterUpdate: state.filterUpdate,
      hasPreviousFilterItems: state.items.isNotEmpty,
      onRetryFilter: () =>
          unawaited(ref.read(_providerRef.notifier).retrySort()),
    );
  }

  void _applySort({required VideoSortField? field, SortDirection? direction}) {
    if (_itemsScrollController.hasClients) {
      _itemsScrollController.jumpTo(0);
    }
    ref
        .read(_providerRef.notifier)
        .applySort(field: field, direction: direction);
  }

  /// 多选态顶栏：桌面原地改写整条顶栏（批量动作内联），移动端只留退出/计数/全选、
  /// 批量动作走贴底 [_buildBatchBar]。
  Widget _buildSelectionHeader(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    final videoIds = state.items.map((it) => it.video.id);
    final allSelected = isAllSelected(videoIds);
    final hasSelection = selectedCount > 0;
    final l10n = AppLocalizations.of(context);
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.videoCollectionAdd,
      BatchOperationType.videoCollectionRemove,
      BatchOperationType.videoDelete,
    ]);
    if (_isMobile) {
      return AppMobileSelectionHeader(
        selectionLabel: l10n.videoSelectedCount(selectedCount),
        countKey: Key('${widget.keyPrefix}-selection-count-text'),
        exitKey: Key('${widget.keyPrefix}-exit-selection-button'),
        onExitSelection: exitSelection,
        selectAllKey: Key('${widget.keyPrefix}-select-all-button'),
        selectAllTooltip: allSelected
            ? l10n.videoDeselectAll
            : l10n.videoSelectAll,
        onToggleAll: () => toggleSelectAll(videoIds),
      );
    }
    return AppGlassSelectionHeader(
      selectionLabel: l10n.videoSelectedCount(selectedCount),
      countKey: Key('${widget.keyPrefix}-selection-count-text'),
      selectAllLabel: allSelected ? l10n.videoDeselectAll : l10n.videoSelectAll,
      selectAllKey: Key('${widget.keyPrefix}-select-all-button'),
      onToggleAll: () => toggleSelectAll(videoIds),
      actions: <AppGlassSelectionAction>[
        AppGlassSelectionAction(
          key: Key('${widget.keyPrefix}-batch-add-collection-button'),
          label: l10n.videoAddToCollection,
          icon: Icons.playlist_add_rounded,
          onTap: hasSelection && !submitting
              ? () => _batchAddToOtherCollection(state)
              : null,
        ),
        AppGlassSelectionAction(
          key: Key('${widget.keyPrefix}-batch-remove-button'),
          label: l10n.videoRemoveFromCollectionTitle,
          icon: Icons.playlist_remove_rounded,
          onTap: hasSelection && !submitting ? () => _batchRemove(state) : null,
        ),
        AppGlassSelectionAction(
          key: Key('${widget.keyPrefix}-batch-delete-button'),
          label: l10n.videoDeleteTitle,
          icon: Icons.delete_outline_rounded,
          foregroundColor: context.appTextPalette.error,
          onTap: hasSelection && !submitting ? () => _batchDelete(state) : null,
        ),
      ],
      exitKey: Key('${widget.keyPrefix}-exit-selection-button'),
      onExitSelection: exitSelection,
    );
  }

  Widget _buildBatchBar(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    final hasSelection = selectedCount > 0;
    final l10n = AppLocalizations.of(context);
    final submitting = watchBatchOperationSubmitting(ref, const [
      BatchOperationType.videoCollectionAdd,
      BatchOperationType.videoCollectionRemove,
      BatchOperationType.videoDelete,
    ]);
    return AppSelectionBottomBar(
      key: Key('${widget.keyPrefix}-batch-bottom-bar'),
      actions: [
        AppButton(
          key: Key('${widget.keyPrefix}-batch-add-collection-button'),
          label: l10n.videoAddToCollection,
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection && !submitting
              ? () => _batchAddToOtherCollection(state)
              : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-remove-button'),
          label: l10n.videoRemove,
          variant: AppButtonVariant.secondary,
          onPressed: hasSelection && !submitting
              ? () => _batchRemove(state)
              : null,
        ),
        AppButton(
          key: Key('${widget.keyPrefix}-batch-delete-button'),
          label: l10n.commonDelete,
          variant: AppButtonVariant.danger,
          onPressed: hasSelection && !submitting
              ? () => _batchDelete(state)
              : null,
        ),
      ],
    );
  }

  // --------------------------------------------------------- body

  List<Widget> _buildMobileBodySlivers(
    BuildContext context,
    VideoCollectionDetailState state,
  ) {
    if (state.items.isEmpty && state.filterUpdate.hasFailed) {
      return const <Widget>[SliverToBoxAdapter(child: SizedBox.shrink())];
    }
    if (state.items.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppEmptyState(
            message: AppLocalizations.of(context).videoCollectionEmptyHint,
          ),
        ),
      ];
    }
    final items = state.items;
    return <Widget>[
      SliverPadding(
        padding: EdgeInsets.only(
          bottom: context.appSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        sliver: AppAdaptiveCardSliver<VideoCollectionItemDto>(
          gridKey: Key('${widget.keyPrefix}-detail-grid'),
          items: items,
          layout: AppAdaptiveCardGridLayout.masonry,
          tileAspect: (index) => _resolveCoverAspect(
            items[index].video.coverWidth,
            items[index].video.coverHeight,
          ),
          itemBuilder: (context, item, _) => _buildMemberCard(context, item),
        ),
      ),
    ];
  }

  Widget _buildBody(BuildContext context, VideoCollectionDetailState state) {
    if (state.items.isEmpty && state.filterUpdate.hasFailed) {
      return const SizedBox.shrink();
    }
    if (state.items.isEmpty) {
      return AppEmptyState(
        message: AppLocalizations.of(context).videoCollectionEmptyHint,
      );
    }
    return _buildGrid(context, state);
  }

  Widget _buildGrid(BuildContext context, VideoCollectionDetailState state) {
    final items = state.items;
    final spacing = context.appSpacing.md;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = resolveAppCardGridColumnCount(
          context,
          width: constraints.maxWidth,
          spacing: spacing,
          orientation: AppCardGridOrientation.mixed,
        );
        return MasonryGridView.count(
          controller: _itemsScrollController,
          key: Key('${widget.keyPrefix}-detail-grid'),
          // 横向缩进由 shell 提供，此处只补底部留白（仅移动）：区块留白之外
          // 还要补回外壳不再吞掉的底部安全区。
          padding: _isMobile
              ? EdgeInsets.only(
                  bottom:
                      context.appSpacing.lg +
                      MediaQuery.paddingOf(context).bottom,
                )
              : null,
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            final aspect = _resolveCoverAspect(
              item.video.coverWidth,
              item.video.coverHeight,
            );
            return AspectRatio(
              aspectRatio: aspect,
              child: _buildMemberCard(context, item),
            );
          },
        );
      },
    );
  }

  Widget _buildMemberCard(BuildContext context, VideoCollectionItemDto item) {
    return CollectionMemberCard(
      key: ValueKey<int>(item.video.id),
      onLongPress: _isMobile && !selectionMode
          ? selectionLongPressHandler(item.video.id)
          : null,
      coverUrl: item.video.coverImage?.origin,
      // expandToParent 模式下 coverAspectRatio 仅在 cover placeholder 时
      // 影响占位比例；瀑布流 tile 已按真实比例分配高度，传 16:9 兜底即可。
      coverAspectRatio: 16 / 9,
      title: item.video.displayTitle(AppLocalizations.of(context)),
      // 副信息只在桌面悬停面板渲染；移动端无 hover，收起态不铺文字。
      subtitle: _formatReleaseDate(item.video.releaseDate),
      onTap: selectionAwareTap(
        item.video.id,
        () => _openMemberActions(context, item),
      ),
      menuKey: Key('${widget.keyPrefix}-grid-menu-${item.video.id}'),
      onPlay: _isMobile
          ? null
          : () => _playSingle(
              context,
              item.video.id,
              item.video.displayTitle(AppLocalizations.of(context)),
            ),
      playButtonKey: Key('${widget.keyPrefix}-grid-play-${item.video.id}'),
      onThumbnails: _isMobile ? null : () => _openThumbnails(item),
      thumbnailsButtonKey: Key(
        '${widget.keyPrefix}-grid-thumbnails-${item.video.id}',
      ),
      onAddToCollection: _isMobile ? null : () => _addToOtherCollection(item),
      addToCollectionButtonKey: Key(
        '${widget.keyPrefix}-grid-add-collection-${item.video.id}',
      ),
      onRemove: _isMobile ? null : () => _removeVideo(item.video.id),
      removeButtonKey: Key('${widget.keyPrefix}-grid-remove-${item.video.id}'),
      onDelete: _isMobile ? null : () => _deleteVideo(item.video.id),
      deleteButtonKey: Key('${widget.keyPrefix}-grid-delete-${item.video.id}'),
      expandToParent: true,
      selectionMode: selectionMode,
      isSelected: isSelected(item.video.id),
    );
  }

  // --------------------------------------------------------- 单条动作

  void _openMemberActions(BuildContext context, VideoCollectionItemDto item) {
    final video = item.video;
    final otherCollections = video.collections
        .where((ref) => ref.id != widget.collectionId)
        .toList(growable: false);
    if (_isMobile) {
      showMobileVideoActionsSheet(
        context,
        video: video,
        onPlay: () => _playSingle(
          context,
          video.id,
          video.displayTitle(AppLocalizations.of(context)),
        ),
        onThumbnails: () => MobileVideoThumbnailRouteData(
          videoId: video.id,
        ).push<void>(context),
        onRemoveFromCollection: () => _removeVideo(video.id),
        onDelete: () => _deleteVideo(video.id),
        collections: otherCollections,
        onCollectionTap: (ref) => MobileVideoCollectionDetailRouteData(
          collectionId: ref.id,
        ).push(context),
      );
      return;
    }
    showDesktopVideoActionsDialog(
      context,
      video: video,
      onPlay: () => _playSingle(
        context,
        video.id,
        video.displayTitle(AppLocalizations.of(context)),
      ),
      onThumbnails: () => _openThumbnails(item),
      onRemoveFromCollection: () => _removeVideo(video.id),
      onDelete: () => _deleteVideo(video.id),
      collections: otherCollections,
      onCollectionTap: (ref) =>
          context.pushDesktopVideoCollectionDetail(collectionId: ref.id),
    );
  }

  Future<void> _playSingle(
    BuildContext context,
    int videoId,
    String title,
  ) async {
    if (await tryLaunchExternalVideoPlayback(
      context,
      videoId: videoId,
      title: title,
    )) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    if (_isMobile) {
      await MobileVideoPlayerRouteData(videoId: videoId).push<void>(context);
      return;
    }
    context.pushDesktopVideoPlayer(videoId: videoId);
  }

  Future<void> _removeVideo(int videoId) async {
    final error = await ref.read(_providerRef.notifier).removeVideo(videoId);
    if (!mounted) {
      return;
    }
    if (error == null) {
      // 合集封面/计数可能变化，广播给列表页的合集横滑区。
      _mutationBroadcaster.reportCollectionMembershipChanged(
        videoId: videoId,
        collectionId: widget.collectionId,
      );
    }
    showToast(
      error ?? AppLocalizations.of(context).videoRemovedFromCollection,
      tone: error == null ? AppToastTone.success : AppToastTone.error,
    );
  }

  /// 彻底删除视频本体（含文件，不可恢复）：先确认，再走 notifier 乐观删除并广播
  /// [VideoMutationEvents.reportDeleted]，让列表页网格精准移除、合集横滑区刷新。
  Future<void> _deleteVideo(int videoId) async {
    final l10n = AppLocalizations.of(context);
    final items =
        ref.read(_providerRef).value?.items ?? const <VideoCollectionItemDto>[];
    var title = '';
    for (final item in items) {
      if (item.video.id == videoId) {
        title = item.video.preferredTitle.trim();
        break;
      }
    }
    final label = title.isEmpty ? l10n.videoGenericVideo : '“$title”';
    final notifier = ref.read(_providerRef.notifier);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoDeleteTitle,
      message: l10n.videoDeleteConfirmMessage(label),
      danger: true,
      confirmLabel: l10n.commonDelete,
      confirmKey: Key('${widget.keyPrefix}-delete-confirm-button'),
      dialogKey: _isMobile ? Key('${widget.keyPrefix}-delete-drawer') : null,
      onConfirm: () => notifier.deleteVideo(videoId),
      failureFallback: l10n.videoDeleteFailed,
    );
    if (!mounted || !confirmed) {
      return;
    }
    _mutationBroadcaster.reportDeleted(videoId);
    showToast(l10n.videoDeletedToast, tone: AppToastTone.success);
  }

  /// 跳转到该视频的缩略图页（桌面悬停动作）。
  void _openThumbnails(VideoCollectionItemDto item) {
    context.pushDesktopVideoThumbnails(videoId: item.video.id);
  }

  /// 单卡「加入合集」：把该视频加入其它合集（排除当前合集），成功后广播刷新
  /// 目标合集的封面 / 计数。
  Future<void> _addToOtherCollection(VideoCollectionItemDto item) async {
    final l10n = AppLocalizations.of(context);
    final target = await showPickVideoCollectionDialog(
      context,
      presentation: _isMobile
          ? PickVideoCollectionPresentation.bottomDrawer
          : PickVideoCollectionPresentation.dialog,
      excludedCollectionId: widget.collectionId,
    );
    if (!mounted || target == null) {
      return;
    }
    try {
      await ref
          .read(videoCollectionsApiProvider)
          .addVideoToCollection(
            collectionId: target.id,
            videoItemId: item.video.id,
          );
      if (!mounted) {
        return;
      }
      _mutationBroadcaster.reportCollectionMembershipChanged(
        videoId: item.video.id,
        collectionId: target.id,
      );
      showToast(
        l10n.videoAddedToCollection(target.name),
        tone: AppToastTone.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      showToast(
        apiErrorMessage(
          error,
          fallback: l10n.videoAddToCollectionFailed,
          l10n: l10n,
        ),
        tone: AppToastTone.error,
      );
    }
  }

  Future<void> _playFrom(int index) async {
    final state = ref.read(_providerRef).value;
    if (state == null) {
      return;
    }
    final handoff = ref.read(collectionPlaybackHandoffProvider);
    final sort = state.sort.apiValue;
    // 把当前已排序、带播放地址的成员交给连播页直接用，免其二次全量拉取。
    handoff.offerVideoItems(
      collectionId: widget.collectionId,
      sort: sort,
      items: state.items,
    );
    if (_isMobile) {
      MobileVideoCollectionPlayRouteData(
        collectionId: widget.collectionId,
        startIndex: index,
        // 移动端详情页按手动顺序展示（sort 为 null），连播顺序与之一致。
        sort: sort,
      ).push(context);
      return;
    }
    context.pushDesktopVideoCollectionPlay(
      collectionId: widget.collectionId,
      startIndex: index,
      sort: sort,
    );
  }

  // --------------------------------------------------------- 选择 / 批量

  List<VideoCollectionItemDto> _selectedItems(
    VideoCollectionDetailState state,
  ) => state.items
      .where((it) => isSelected(it.video.id))
      .toList(growable: false);

  Future<void> _batchAddToOtherCollection(
    VideoCollectionDetailState state,
  ) async {
    final selected = _selectedItems(state);
    if (selected.isEmpty) {
      return;
    }
    final target = await showPickVideoCollectionDialog(
      context,
      presentation: _isMobile
          ? PickVideoCollectionPresentation.bottomDrawer
          : PickVideoCollectionPresentation.dialog,
      excludedCollectionId: widget.collectionId,
    );
    if (!mounted || target == null) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.videoCollectionAdd,
      targetCollectionId: target.id,
      ids: selected.map((item) => item.video.id).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _batchRemove(VideoCollectionDetailState state) async {
    final selected = _selectedItems(state);
    if (selected.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoRemoveFromCollectionTitle,
      message: l10n.videoBatchRemoveConfirmMessage(selected.length),
      danger: true,
      confirmLabel: _isMobile ? l10n.videoRemove : l10n.videoConfirm,
      confirmKey: _batchConfirmKey('remove'),
      dialogKey: _isMobile
          ? Key('${widget.keyPrefix}-batch-remove-drawer')
          : null,
      failureFallback: l10n.videoDeleteFailed,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.videoCollectionRemove,
      targetCollectionId: widget.collectionId,
      ids: selected.map((item) => item.video.id).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  Future<void> _batchDelete(VideoCollectionDetailState state) async {
    final selected = _selectedItems(state);
    if (selected.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.videoDeleteTitle,
      message: l10n.videoBatchDeleteConfirmMessage(selected.length),
      danger: true,
      confirmLabel: _isMobile ? l10n.commonDelete : l10n.videoConfirm,
      confirmKey: _batchConfirmKey('delete'),
      dialogKey: _isMobile
          ? Key('${widget.keyPrefix}-batch-delete-drawer')
          : null,
      failureFallback: l10n.videoDeleteFailed,
    );
    if (!mounted || !confirmed) {
      return;
    }
    final submitted = await submitBatchOperation(
      context,
      ref,
      operation: BatchOperationType.videoDelete,
      ids: selected.map((item) => item.video.id).toList(growable: false),
    );
    if (!mounted) {
      return;
    }
    if (submitted) exitSelection();
  }

  /// 批量确认按钮 Key：桌面两端共用 `$keyPrefix-batch-confirm-button`，
  /// 移动端按操作区分（remove / delete）。
  Key _batchConfirmKey(String op) {
    if (_isMobile) {
      return Key('${widget.keyPrefix}-batch-$op-confirm-button');
    }
    return Key('${widget.keyPrefix}-batch-confirm-button');
  }
}

double _resolveCoverAspect(int? width, int? height) {
  if (width != null && height != null && width > 0 && height > 0) {
    return width / height;
  }
  return 16 / 9;
}

/// 发布日期文案；为空返回 `null`（不展示该行）。
String? _formatReleaseDate(DateTime? value) {
  if (value == null) {
    return null;
  }
  return DateFormat('yyyy-MM-dd').format(value.toLocal());
}
