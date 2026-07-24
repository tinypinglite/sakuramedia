import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

/// 视频列表筛选所有 section 的纵向 Column。
///
/// 桌面 `AppListHeader` 的就地浮层 panel 和移动 `MobileVideoSortDrawer` 都用它，
/// 避免双份维护。底栏/重置按钮由调用方自己附加。
///
/// 视频只有排序一维（字段 + 升降序），分节复用影片侧的 `MovieFilterChoiceSection`
/// ——两边 chip 的观感必须一致。
class VideoFilterSectionGroup extends StatelessWidget {
  const VideoFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final VideoFilterState filterState;
  final ValueChanged<VideoFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieFilterChoiceSection<VideoSortField>(
          title: '排序字段',
          options: VideoSortField.values,
          selectedValue: filterState.sortField,
          optionKeyBuilder: (field) => Key('videos-filter-sort-${field.apiValue}'),
          labelBuilder: (field) => field.label,
          onSelected: (field) => onChanged(filterState.copyWith(sortField: field)),
        ),
        SizedBox(height: context.appSpacing.lg),
        MovieFilterChoiceSection<SortDirection>(
          title: '升降序',
          options: SortDirection.values,
          selectedValue: filterState.sortDirection,
          optionKeyBuilder:
              (dir) => Key(
                'videos-filter-sort-direction-'
                '${dir == SortDirection.desc ? 'desc' : 'asc'}',
              ),
          labelBuilder: (dir) => dir == SortDirection.desc ? '降序' : '升序',
          onSelected: (dir) => onChanged(filterState.copyWith(sortDirection: dir)),
        ),
      ],
    );
  }
}
