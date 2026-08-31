import 'package:flutter/material.dart';
import 'package:sakuramedia/features/hot_reviews/data/hot_review_period.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

/// 热评筛选所有 section 的纵向 Column（当前只有「周期」一维）。
///
/// 桌面 `AppListHeader` 的就地浮层 panel 和移动 [showMobileHotReviewFilterDrawer]
/// 都用它，避免双份维护。分节复用影片侧的 `MovieFilterChoiceSection`——两边 chip
/// 的观感必须一致。
class HotReviewFilterSectionGroup extends StatelessWidget {
  const HotReviewFilterSectionGroup({
    super.key,
    required this.period,
    required this.onChanged,
  });

  final HotReviewPeriod period;
  final ValueChanged<HotReviewPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieFilterChoiceSection<HotReviewPeriod>(
          title: '周期',
          options: HotReviewPeriod.values,
          selectedValue: period,
          optionKeyBuilder:
              (value) => Key('hot-reviews-filter-period-${value.apiValue}'),
          labelBuilder: (value) => value.label,
          onSelected: onChanged,
        ),
      ],
    );
  }
}

/// 弹出移动端热评筛选底部抽屉。内容与桌面 `AppListHeader` 的就地浮层面板**完全
/// 一致**（同一个 [HotReviewFilterSectionGroup]），**即时生效**。
///
/// 周期是五选一、没有「恢复默认」语义，故不带 footer——对齐榜单筛选抽屉。
Future<void> showMobileHotReviewFilterDrawer(
  BuildContext context, {
  required HotReviewPeriod current,
  required ValueChanged<HotReviewPeriod> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-hot-reviews-filter-drawer'),
    maxHeightFactor: 0.6,
    builder:
        (sheetContext) => _MobileHotReviewFilterDrawerContent(
          current: current,
          onChanged: onChanged,
        ),
  );
}

class _MobileHotReviewFilterDrawerContent extends StatefulWidget {
  const _MobileHotReviewFilterDrawerContent({
    required this.current,
    required this.onChanged,
  });

  final HotReviewPeriod current;
  final ValueChanged<HotReviewPeriod> onChanged;

  @override
  State<_MobileHotReviewFilterDrawerContent> createState() =>
      _MobileHotReviewFilterDrawerContentState();
}

class _MobileHotReviewFilterDrawerContentState
    extends State<_MobileHotReviewFilterDrawerContent> {
  late HotReviewPeriod _local;

  @override
  void initState() {
    super.initState();
    _local = widget.current;
  }

  /// 就地反映 + 即时生效，见 movie_filter_drawer 的同名方法。
  void _apply(HotReviewPeriod next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-hot-reviews-filter-scroll-view'),
      child: HotReviewFilterSectionGroup(period: _local, onChanged: _apply),
    );
  }
}
