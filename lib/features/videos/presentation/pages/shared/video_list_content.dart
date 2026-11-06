import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_pinned_list_header.dart';
import 'package:sakuramedia/features/videos/data/dto/video_item_list_item_dto.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/providers/video_summary_provider.dart';
import 'package:sakuramedia/features/videos/presentation/video_placeholders.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_view_snapshot.dart';
import 'package:sakuramedia/features/shared/presentation/widgets/paged_load_more_footer_sliver.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_glass_list_header.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_summary_grid.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';

/// 视频列表「排序条 + 总数 + 网格 + 分页底栏」的 Sliver 呈现层。
///
/// 与 `MovieSummaryListContent` 平行，但去掉订阅/合集类型变更联动，主键为 `int id`。
/// 标签/人物筛选面板由外层页面承载（见 `desktop_video_list_page`），本组件只负责
/// 列表本体与排序即时切换。
class VideoListContent extends StatelessWidget {
  const VideoListContent({
    super.key,
    required this.paged,
    required this.videoProvider,
    required this.headerKey,
    required this.initialErrorMessage,
    required this.filterState,
    required this.onFilterChanged,
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
    this.onEnterSelection,
    this.before = const <Widget>[],
    this.sectionSpacing = 0,
    this.contentKey,
    this.totalKey,
    this.emptyMessage,
  });

  final PagedViewSnapshot<VideoItemListItemDto> paged;
  final VideoSummaryProvider videoProvider;
  final GlobalKey headerKey;
  final String? initialErrorMessage;
  final VideoFilterState filterState;
  final ValueChanged<VideoFilterState> onFilterChanged;
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

  /// 多选态**整条顶栏**的替代内容。
  ///
  /// 多选是原地改写这一行，不在筛选行下面另起一行——另起一行会让整页内容上下
  /// 跳动。返回 `null` 时退回常规顶栏。
  ///
  /// 用 builder 而非现成 widget，使其在列表分页加载后能拿到最新 items
  /// （决定「全选」状态）。
  final Widget? Function(BuildContext context)? selectionHeaderBuilder;

  /// 进入多选的回调；列表为空时由 [VideoListContent] 自动隐藏入口。
  final VoidCallback? onEnterSelection;

  /// 吸顶筛选条上方的 sliver 内容，与列表一起参与控制栏前后裁剪。
  final List<Widget> before;

  final double sectionSpacing;

  final Key? contentKey;
  final Key? totalKey;

  /// 空态文案；为 `null` 时用语言包的默认文案。
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectionHeader = selectionMode
        ? selectionHeaderBuilder?.call(context)
        : null;
    final enterSelection = !selectionMode && paged.items.isNotEmpty
        ? onEnterSelection
        : null;
    return AppPinnedSliverSection(
      key: contentKey,
      headerKey: headerKey,
      before: before,
      header: VideoGlassListHeader(
        filterState: filterState,
        total: paged.total,
        filterUpdate: paged.filterUpdate,
        hasPreviousFilterItems: paged.items.isNotEmpty,
        onFilterChanged: onFilterChanged,
        onRetryFilter: onRetryFilter,
        onEnterSelection: enterSelection,
        selectionHeader: selectionHeader,
        totalKey: totalKey,
      ),
      headerBottomSpacing: sectionSpacing,
      after: <Widget>[
        if (!paged.filterUpdate.hasFailed || paged.items.isNotEmpty)
          AppSkeletonizer.sliver(
            enabled: paged.isInitialLoading,
            child: VideoSummarySliver(
              items: paged.isInitialLoading
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
              emptyMessage: emptyMessage ?? l10n.videoEmptyList,
            ),
          ),
        // loadMore 页脚独立订阅：翻页 loading / 失败只重建页脚。
        PagedLoadMoreFooterSliver(
          watchFooter: (ref) => ref.watch(
            videoProvider.select(
              (s) => pagedLoadMoreFooterSnapshot(s.value?.paged),
            ),
          ),
          onLoadMore: (ref) =>
              unawaited(ref.read(videoProvider.notifier).loadMore()),
        ),
      ],
    );
  }
}
