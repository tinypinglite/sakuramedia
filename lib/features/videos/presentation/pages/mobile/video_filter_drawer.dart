import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_glass_list_popover.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_modal_glass_surface.dart';

/// 弹出视频筛选底部抽屉。内容与桌面玻璃筛选浮层**完全一致**
/// （同一个 `VideoGlassFilterPopoverContent`），**即时生效**，语义同
/// `showMobileMovieFilterDrawer`。
Future<void> showMobileVideoFilterDrawer(
  BuildContext context, {
  required VideoFilterState current,
  required ValueChanged<VideoFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-pornbox-filter-drawer'),
    maxHeightFactor: 0.55,
    glassStrength: AppModalGlassStrength.solid,
    builder: (sheetContext) => AppMobileFilterDrawer<VideoFilterState>(
      current: current,
      // 重置只清筛选条件，保留排序入口选择的排序。
      initial: current.resetFilters(),
      onChanged: onChanged,
      isDefault: (value) => !value.hasActiveFilters,
      scrollViewKey: const Key('mobile-pornbox-filter-scroll-view'),
      contentBuilder: (context, local, onApply) =>
          VideoGlassFilterPopoverContent(
            filterState: local,
            onChanged: onApply,
          ),
    ),
  );
}
