import 'package:flutter/material.dart';
import 'package:sakuramedia/features/moments/presentation/paged_moment_controller.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

/// 时刻筛选所有 section 的纵向 Column：内容类型 + 排序。
///
/// 桌面 `AppListHeader` 的就地浮层 panel 和移动 [showMobileMomentFilterDrawer]
/// 都用它，避免双份维护。分节复用影片侧的 `MovieFilterChoiceSection`——两边 chip
/// 的观感必须一致。
///
/// [keyPrefix] 让同一组分节在桌面 / 移动两个入口下产生不同的测试锚点。
class MomentFilterSectionGroup extends StatelessWidget {
  const MomentFilterSectionGroup({
    super.key,
    required this.kindFilter,
    required this.sortOrder,
    required this.onKindChanged,
    required this.onSortChanged,
    this.keyPrefix = 'moments',
  });

  final MomentKindFilter kindFilter;
  final MomentSortOrder sortOrder;
  final ValueChanged<MomentKindFilter> onKindChanged;
  final ValueChanged<MomentSortOrder> onSortChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieFilterChoiceSection<MomentKindFilter>(
          title: '内容类型',
          options: MomentKindFilter.values,
          selectedValue: kindFilter,
          optionKeyBuilder: (value) => Key('$keyPrefix-kind-${value.apiValue}'),
          labelBuilder: (value) => value.label,
          onSelected: onKindChanged,
        ),
        SizedBox(height: context.appSpacing.lg),
        MovieFilterChoiceSection<MomentSortOrder>(
          title: '排序',
          options: MomentSortOrder.values,
          selectedValue: sortOrder,
          optionKeyBuilder:
              (value) => Key(
                '$keyPrefix-sort-'
                '${value == MomentSortOrder.latest ? 'latest' : 'earliest'}',
              ),
          labelBuilder: (value) => value.label,
          onSelected: onSortChanged,
        ),
      ],
    );
  }
}

/// 弹出移动端时刻筛选底部抽屉。内容与桌面 `AppListHeader` 的就地浮层面板**完全
/// 一致**（同一个 [MomentFilterSectionGroup]），**即时生效**。
///
/// 类型与排序都是必选其一、没有「恢复默认」语义，故不带 footer——对齐榜单 / 热评。
Future<void> showMobileMomentFilterDrawer(
  BuildContext context, {
  required MomentKindFilter kindFilter,
  required MomentSortOrder sortOrder,
  required ValueChanged<MomentKindFilter> onKindChanged,
  required ValueChanged<MomentSortOrder> onSortChanged,
  String keyPrefix = 'mobile-moments',
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-moments-filter-drawer'),
    maxHeightFactor: 0.6,
    builder:
        (sheetContext) => _MobileMomentFilterDrawerContent(
          kindFilter: kindFilter,
          sortOrder: sortOrder,
          onKindChanged: onKindChanged,
          onSortChanged: onSortChanged,
          keyPrefix: keyPrefix,
        ),
  );
}

class _MobileMomentFilterDrawerContent extends StatefulWidget {
  const _MobileMomentFilterDrawerContent({
    required this.kindFilter,
    required this.sortOrder,
    required this.onKindChanged,
    required this.onSortChanged,
    required this.keyPrefix,
  });

  final MomentKindFilter kindFilter;
  final MomentSortOrder sortOrder;
  final ValueChanged<MomentKindFilter> onKindChanged;
  final ValueChanged<MomentSortOrder> onSortChanged;
  final String keyPrefix;

  @override
  State<_MobileMomentFilterDrawerContent> createState() =>
      _MobileMomentFilterDrawerContentState();
}

class _MobileMomentFilterDrawerContentState
    extends State<_MobileMomentFilterDrawerContent> {
  late MomentKindFilter _kind;
  late MomentSortOrder _sort;

  @override
  void initState() {
    super.initState();
    _kind = widget.kindFilter;
    _sort = widget.sortOrder;
  }

  /// 就地反映 + 即时生效，见 movie_filter_drawer 的同名方法。
  void _applyKind(MomentKindFilter next) {
    setState(() => _kind = next);
    widget.onKindChanged(next);
  }

  void _applySort(MomentSortOrder next) {
    setState(() => _sort = next);
    widget.onSortChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-moments-filter-scroll-view'),
      child: MomentFilterSectionGroup(
        kindFilter: _kind,
        sortOrder: _sort,
        onKindChanged: _applyKind,
        onSortChanged: _applySort,
        keyPrefix: widget.keyPrefix,
      ),
    );
  }
}
