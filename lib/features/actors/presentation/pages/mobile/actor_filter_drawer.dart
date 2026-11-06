import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/domain/actors/actor_filter_sections.dart';

/// 弹出移动端演员筛选底部抽屉。内容与行为对齐桌面女优页玻璃筛选浮层
/// 浮层面板（同一个 `ActorFilterSectionGroup`），见 `showMobileMovieFilterDrawer`
/// 的说明。
Future<void> showMobileActorFilterDrawer(
  BuildContext context, {
  required ActorFilterState current,
  required ValueChanged<ActorFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-actors-filter-drawer'),
    maxHeightFactor: 0.85,
    builder: (sheetContext) => AppMobileFilterDrawer<ActorFilterState>(
      current: current,
      // 重置只清筛选条件，保留排序入口选择的排序。
      initial: current.resetFilters(),
      onChanged: onChanged,
      isDefault: (value) => !value.hasActiveFilters,
      scrollViewKey: const Key('mobile-actors-filter-scroll-view'),
      contentBuilder: (context, local, onApply) =>
          ActorFilterSectionGroup(filterState: local, onChanged: onApply),
    ),
  );
}
