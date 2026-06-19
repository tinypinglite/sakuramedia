import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/data/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/paged_video_summary_controller.dart';
import 'package:sakuramedia/features/videos/presentation/video_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_filter_total_header.dart';
import 'package:sakuramedia/widgets/app_paged_load_more_footer.dart';
import 'package:sakuramedia/widgets/videos/video_filter_toolbar.dart';
import 'package:sakuramedia/widgets/videos/video_summary_grid.dart';

/// 视频列表「排序条 + 总数 + 网格 + 分页底栏」的呈现层。
///
/// 与 `MovieListContent` 平行，但去掉订阅/合集类型变更联动，主键为 `int id`。
/// 标签/人物筛选面板由外层页面承载（见 `desktop_video_list_page`），本组件只负责
/// 列表本体与排序即时切换。
class VideoListContent extends StatelessWidget {
  const VideoListContent({
    super.key,
    required this.controller,
    required this.filterState,
    required this.onFilterChanged,
    required this.onVideoTap,
    this.onVideoAddToCollection,
    this.onVideoDelete,
    this.selectionMode = false,
    this.selectedIds = const <int>{},
    this.onVideoToggleSelect,
    this.headerTrailingBuilder,
    this.headerInlineTrailingBuilder,
    this.sectionSpacing = 0,
    this.contentKey,
    this.totalKey,
    this.emptyMessage = '暂无视频数据',
  });

  final PagedVideoSummaryController controller;
  final VideoFilterState filterState;
  final ValueChanged<VideoFilterState> onFilterChanged;
  final ValueChanged<VideoItemListItemDto> onVideoTap;
  final ValueChanged<VideoItemListItemDto>? onVideoAddToCollection;
  final ValueChanged<VideoItemListItemDto>? onVideoDelete;

  /// 选择模式：网格切换为多选交互。
  final bool selectionMode;

  /// 已选视频 id 集合。
  final Set<int> selectedIds;

  /// 选择模式下切换某个视频选中态的回调。
  final ValueChanged<VideoItemListItemDto>? onVideoToggleSelect;

  /// 总数行下方的尾随区域（如批量操作栏）。返回 `null` 不渲染（也不留间距）。
  ///
  /// 用 builder 而非现成 widget，使其在列表分页加载（controller 变化）后能拿到
  /// 最新的 `controller.items`（决定可见性与「全选」状态）。
  final Widget? Function(BuildContext context)? headerTrailingBuilder;

  /// 总数（「N 个」）右侧、同一行的尾随区域（如「选择」入口）。返回 `null` 不渲染。
  /// 用 builder 让 controller 变化时拿到最新 `controller.items`。
  final Widget? Function(BuildContext context)? headerInlineTrailingBuilder;

  final double sectionSpacing;
  final Key? contentKey;
  final Key? totalKey;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final showFooter = controller.items.isNotEmpty &&
            (controller.isLoadingMore || controller.loadMoreErrorMessage != null);
        final inlineTrailing = headerInlineTrailingBuilder?.call(context);
        final trailingBelow = headerTrailingBuilder?.call(context);
        return Column(
          key: contentKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppFilterTotalHeader(
              leading: VideoFilterToolbar(
                filterState: filterState,
                onChanged: onFilterChanged,
              ),
              totalText: '${controller.total} 个',
              totalKey: totalKey ?? const Key('videos-page-total'),
              trailing: inlineTrailing,
            ),
            if (trailingBelow != null) ...[
              SizedBox(height: context.appSpacing.sm),
              trailingBelow,
            ],
            SizedBox(height: sectionSpacing),
            VideoSummaryGrid(
              items: controller.items,
              isLoading: controller.isInitialLoading,
              errorMessage: controller.initialErrorMessage,
              onVideoTap: onVideoTap,
              onVideoAddToCollection: onVideoAddToCollection,
              onVideoDelete: onVideoDelete,
              selectionMode: selectionMode,
              selectedIds: selectedIds,
              onVideoToggleSelect: onVideoToggleSelect,
              emptyMessage: emptyMessage,
            ),
            if (showFooter) ...[
              SizedBox(height: context.appSpacing.md),
              AppPagedLoadMoreFooter(
                isLoading: controller.isLoadingMore,
                errorMessage: controller.loadMoreErrorMessage,
                onRetry: controller.loadMore,
              ),
            ],
          ],
        );
      },
    );
  }
}
