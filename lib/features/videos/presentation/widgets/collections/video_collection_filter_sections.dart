import 'package:flutter/material.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

/// 合集成员排序的入口摘要文案：`null` 表示手动顺序（后端 `position:asc`）。
String videoCollectionSortLabel(VideoSortField? field) =>
    field?.label ?? '手动顺序';

/// 视频合集详情筛选所有 section 的纵向 Column：排序方式 + 升降序。
///
/// 桌面 `AppListHeader` 的就地浮层 panel 和移动
/// [showMobileVideoCollectionFilterDrawer] 都用它，避免双份维护。分节复用影片侧的
/// `MovieFilterChoiceSection`——两边 chip 的观感必须一致。
///
/// 「手动顺序」固定升序，选中时**隐藏方向分节**（沿用原内联排序条的语义）。
class VideoCollectionFilterSectionGroup extends StatelessWidget {
  const VideoCollectionFilterSectionGroup({
    super.key,
    required this.sortField,
    required this.sortDirection,
    required this.onChanged,
  });

  /// 当前排序字段；为 `null` 表示手动顺序（position）。
  final VideoSortField? sortField;
  final SortDirection sortDirection;

  /// 排序变化回调：[field] 为 `null` 表示切回手动顺序；[direction] 为 `null`
  /// 表示沿用当前方向。
  final void Function({
    required VideoSortField? field,
    SortDirection? direction,
  })
  onChanged;

  @override
  Widget build(BuildContext context) {
    final isManual = sortField == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieFilterChoiceSection<VideoSortField?>(
          title: '排序方式',
          options: <VideoSortField?>[null, ...VideoSortField.values],
          selectedValue: sortField,
          optionKeyBuilder:
              (value) => Key(
                'video-collection-sort-${value?.apiValue ?? 'manual'}',
              ),
          labelBuilder: videoCollectionSortLabel,
          onSelected: (value) => onChanged(field: value),
        ),
        // 手动顺序固定升序，隐藏方向切换；其余字段可切升降序。
        if (!isManual) ...[
          SizedBox(height: context.appSpacing.lg),
          MovieFilterChoiceSection<SortDirection>(
            title: '升降序',
            options: SortDirection.values,
            selectedValue: sortDirection,
            optionKeyBuilder:
                (value) => Key(
                  'video-collection-sort-direction-'
                  '${value == SortDirection.desc ? 'desc' : 'asc'}',
                ),
            labelBuilder: (value) => value == SortDirection.desc ? '降序' : '升序',
            onSelected:
                (value) => onChanged(field: sortField, direction: value),
          ),
        ],
      ],
    );
  }
}

/// 弹出移动端视频合集排序底部抽屉。内容与桌面 `AppListHeader` 的就地浮层面板
/// **完全一致**（同一个 [VideoCollectionFilterSectionGroup]），**即时生效**。
///
/// 排序是必选其一、没有「恢复默认」语义，故不带 footer——对齐榜单 / 热评 / 时刻。
Future<void> showMobileVideoCollectionFilterDrawer(
  BuildContext context, {
  required VideoSortField? sortField,
  required SortDirection sortDirection,
  required void Function({
    required VideoSortField? field,
    SortDirection? direction,
  })
  onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-video-collection-sort-drawer'),
    maxHeightFactor: 0.6,
    builder:
        (sheetContext) => _MobileVideoCollectionFilterDrawerContent(
          sortField: sortField,
          sortDirection: sortDirection,
          onChanged: onChanged,
        ),
  );
}

class _MobileVideoCollectionFilterDrawerContent extends StatefulWidget {
  const _MobileVideoCollectionFilterDrawerContent({
    required this.sortField,
    required this.sortDirection,
    required this.onChanged,
  });

  final VideoSortField? sortField;
  final SortDirection sortDirection;
  final void Function({
    required VideoSortField? field,
    SortDirection? direction,
  })
  onChanged;

  @override
  State<_MobileVideoCollectionFilterDrawerContent> createState() =>
      _MobileVideoCollectionFilterDrawerContentState();
}

class _MobileVideoCollectionFilterDrawerContentState
    extends State<_MobileVideoCollectionFilterDrawerContent> {
  late VideoSortField? _field;
  late SortDirection _direction;

  @override
  void initState() {
    super.initState();
    _field = widget.sortField;
    _direction = widget.sortDirection;
  }

  /// 就地反映 + 即时生效，见 movie_filter_drawer 的同名方法。
  void _apply({required VideoSortField? field, SortDirection? direction}) {
    setState(() {
      _field = field;
      if (direction != null) {
        _direction = direction;
      }
    });
    widget.onChanged(field: field, direction: direction);
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-video-collection-sort-scroll-view'),
      child: VideoCollectionFilterSectionGroup(
        sortField: _field,
        sortDirection: _direction,
        onChanged: _apply,
      ),
    );
  }
}
