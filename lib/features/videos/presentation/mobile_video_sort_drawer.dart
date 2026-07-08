import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/navigation/app_mobile_filter_drawer_scaffold.dart';

/// 弹出视频排序底部抽屉，确定才生效。
///
/// 返回 `null` 表示取消（左滑/未点确定）；非空时调用方应 apply。
Future<VideoFilterState?> showMobileVideoSortDrawer(
  BuildContext context, {
  required VideoFilterState current,
}) {
  return showAppBottomDrawer<VideoFilterState>(
    context: context,
    drawerKey: const Key('mobile-pornbox-sort-drawer'),
    maxHeightFactor: 0.55,
    builder: (sheetContext) =>
        _MobileVideoSortDrawerContent(current: current),
  );
}

class _MobileVideoSortDrawerContent extends StatefulWidget {
  const _MobileVideoSortDrawerContent({required this.current});

  final VideoFilterState current;

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

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      title: '排序',
      resetButtonKey: const Key('mobile-pornbox-sort-drawer-reset'),
      confirmButtonKey: const Key('mobile-pornbox-sort-drawer-confirm'),
      onReset: _local.isDefault
          ? null
          : () => setState(() => _local = VideoFilterState.initial),
      onConfirm: () => Navigator.of(context).pop(_local),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MovieFilterChoiceSection<VideoSortField>(
            title: '排序字段',
            options: VideoSortField.values,
            selectedValue: _local.sortField,
            labelBuilder: (field) => field.label,
            onSelected: (field) =>
                setState(() => _local = _local.copyWith(sortField: field)),
          ),
          SizedBox(height: context.appSpacing.lg),
          MovieFilterChoiceSection<SortDirection>(
            title: '升降序',
            options: SortDirection.values,
            selectedValue: _local.sortDirection,
            labelBuilder: (dir) =>
                dir == SortDirection.desc ? '降序' : '升序',
            onSelected: (dir) => setState(
              () => _local = _local.copyWith(sortDirection: dir),
            ),
          ),
        ],
      ),
    );
  }
}
