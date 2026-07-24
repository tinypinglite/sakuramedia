import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';

/// 弹出视频排序底部抽屉。**即时生效**，语义同 `showMobileMovieFilterDrawer`。
Future<void> showMobileVideoSortDrawer(
  BuildContext context, {
  required VideoFilterState current,
  required ValueChanged<VideoFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-pornbox-sort-drawer'),
    maxHeightFactor: 0.55,
    builder:
        (sheetContext) => _MobileVideoSortDrawerContent(
          current: current,
          onChanged: onChanged,
        ),
  );
}

class _MobileVideoSortDrawerContent extends StatefulWidget {
  const _MobileVideoSortDrawerContent({
    required this.current,
    required this.onChanged,
  });

  final VideoFilterState current;
  final ValueChanged<VideoFilterState> onChanged;

  @override
  State<_MobileVideoSortDrawerContent> createState() =>
      _MobileVideoSortDrawerContentState();
}

class _MobileVideoSortDrawerContentState
    extends State<_MobileVideoSortDrawerContent> {
  late VideoFilterState _local;

  @override
  void initState() {
    super.initState();
    _local = widget.current;
  }

  /// 就地反映 + 即时生效，见 movie_filter_drawer 的同名方法。
  void _apply(VideoFilterState next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-pornbox-sort-scroll-view'),
      footer: AppFilterPanelFooter(
        isDefault: _local.isDefault,
        onReset: () => _apply(VideoFilterState.initial),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MovieFilterChoiceSection<VideoSortField>(
            title: '排序字段',
            options: VideoSortField.values,
            selectedValue: _local.sortField,
            labelBuilder: (field) => field.label,
            onSelected: (field) => _apply(_local.copyWith(sortField: field)),
          ),
          SizedBox(height: context.appSpacing.lg),
          MovieFilterChoiceSection<SortDirection>(
            title: '升降序',
            options: SortDirection.values,
            selectedValue: _local.sortDirection,
            labelBuilder: (dir) => dir == SortDirection.desc ? '降序' : '升序',
            onSelected: (dir) => _apply(_local.copyWith(sortDirection: dir)),
          ),
        ],
      ),
    );
  }
}
