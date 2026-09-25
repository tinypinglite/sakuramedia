import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_filter_sections.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_summary_grid.dart';

/// 视频列表「排序条 + 总数 + 网格 + 分页底栏」的 Sliver 呈现层。
///
/// 与 `MovieSummaryListContent` 平行，但去掉订阅/合集类型变更联动，主键为 `int id`。
/// 标签/人物筛选面板由外层页面承载（见 `desktop_video_list_page`），本组件只负责
/// 列表本体与排序即时切换。
class VideoListContent extends StatelessWidget {
  const VideoListContent({
    super.key,
    required this.paged,
    required this.headerKey,
    required this.isInitialLoading,
    required this.initialErrorMessage,
    required this.filterState,
    required this.onFilterChanged,
    required this.onLoadMore,
    required this.onRetryFilter,
    required this.onVideoTap,
    this.onVideoPlay,
    this.onVideoThumbnails,
    this.onVideoAddToCollection,
    this.onVideoDelete,
    this.selectionMode = false,
    this.selectedIds = const <int>{},
    this.onVideoToggleSelect,
    this.selectionHeaderBuilder,
    this.headerActionsBuilder,
    this.sectionSpacing = 0,
    this.contentKey,
    this.totalKey,
    this.emptyMessage = '暂无视频数据',
  });

  final PagedListState<VideoItemListItemDto> paged;
  final GlobalKey headerKey;
  final bool isInitialLoading;
  final String? initialErrorMessage;
  final VideoFilterState filterState;
  final ValueChanged<VideoFilterState> onFilterChanged;
  final VoidCallback onLoadMore;
  final VoidCallback onRetryFilter;
  final ValueChanged<VideoItemListItemDto> onVideoTap;

  /// 悬停面板播放键的回调；为 `null` 时卡片不显示播放键。
  final ValueChanged<VideoItemListItemDto>? onVideoPlay;

  /// 悬停面板「缩略图」动作；为 `null` 时卡片不显示。
  final ValueChanged<VideoItemListItemDto>? onVideoThumbnails;

  /// 悬停面板「加入合集」动作；为 `null` 时卡片不显示。
  final ValueChanged<VideoItemListItemDto>? onVideoAddToCollection;

  /// 悬停面板「删除」动作；为 `null` 时卡片不显示。
  final ValueChanged<VideoItemListItemDto>? onVideoDelete;

  /// 选择模式：网格切换为多选交互。
  final bool selectionMode;

  /// 已选视频 id 集合。
  final Set<int> selectedIds;

  /// 选择模式下切换某个视频选中态的回调。
  final ValueChanged<VideoItemListItemDto>? onVideoToggleSelect;

  /// 多选态**整条顶栏**的替代内容（通常是 `AppSelectionHeaderToolbar`）。
  ///
  /// 多选是原地改写这一行，不在筛选行下面另起一行——另起一行会让整页内容上下
  /// 跳动。返回 `null` 时退回常规顶栏。
  ///
  /// 用 builder 而非现成 widget，使其在列表分页加载后能拿到最新 items
  /// （决定「全选」状态）。
  final Widget? Function(BuildContext context)? selectionHeaderBuilder;

  /// 常规态顶栏右侧操作槽（如「选择」入口）。返回 `null` 不渲染。
  /// 用 builder 让分页状态变化时拿到最新 items。
  final Widget? Function(BuildContext context)? headerActionsBuilder;

  final double sectionSpacing;
  final Key? contentKey;
  final Key? totalKey;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final showFooter =
        paged.items.isNotEmpty &&
        (paged.isLoadingMore || paged.loadMoreErrorMessage != null);
    final selectionHeader = selectionMode
        ? selectionHeaderBuilder?.call(context)
        : null;
    final actions = headerActionsBuilder?.call(context);
    return SliverMainAxisGroup(
      key: contentKey,
      slivers: [
        AppPinnedListHeader(
          key: headerKey,
          color: context.appColors.surfaceElevated,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 桌面与移动共用同一条顶栏：筛选入口 + 只读信息 + 操作。
              // 差别只在筛选面板的容器——桌面就地浮层，移动底部抽屉。
              selectionHeader ??
                  AppListHeader(
                    filterButtonKey: const Key('videos-filter-trigger'),
                    filterLabel: filterState.sortField.label,
                    filterPanelKey: const Key('videos-filter-panel'),
                    filterPanelExtraWidth: 180,
                    filterPanelBuilder: (_) => VideoFilterSectionGroup(
                      filterState: filterState,
                      onChanged: onFilterChanged,
                    ),
                    filterPanelFooter: AppFilterPanelFooter(
                      isDefault: filterState.isDefault,
                      onReset: () => onFilterChanged(VideoFilterState.initial),
                    ),
                    filterUpdate: paged.filterUpdate,
                    hasPreviousFilterItems: paged.items.isNotEmpty,
                    onRetryFilter: onRetryFilter,
                    informationSlots: [
                      AppListHeaderInfo(
                        key: totalKey ?? const Key('videos-page-total'),
                        label: '${paged.total} 个',
                      ),
                    ],
                    actionSlots: [if (actions != null) actions],
                  ),
              SizedBox(height: sectionSpacing),
            ],
          ),
        ),
        if (!paged.filterUpdate.hasFailed || paged.items.isNotEmpty)
          AppSkeletonizer.sliver(
            enabled: isInitialLoading,
            child: VideoSummarySliver(
              items: isInitialLoading
                  ? videoSummaryPlaceholders(count: 18)
                  : paged.items,
              errorMessage: initialErrorMessage,
              onVideoTap: onVideoTap,
              onVideoPlay: onVideoPlay,
              onVideoThumbnails: onVideoThumbnails,
              onVideoAddToCollection: onVideoAddToCollection,
              onVideoDelete: onVideoDelete,
              selectionMode: selectionMode,
              selectedIds: selectedIds,
              onVideoToggleSelect: onVideoToggleSelect,
              emptyMessage: emptyMessage,
            ),
          ),
        if (showFooter)
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: context.appSpacing.md),
              child: AppPagedLoadMoreFooter(
                isLoading: paged.isLoadingMore,
                errorMessage: paged.loadMoreErrorMessage,
                onRetry: onLoadMore,
              ),
            ),
          ),
      ],
    );
  }
}
