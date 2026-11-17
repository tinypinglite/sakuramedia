import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/widgets/playlist_filter_sections.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

/// 弹出移动端播放列表影片筛选底部抽屉。
///
/// 内容与桌面玻璃筛选浮层面板**完全一致**（同一个
/// [PlaylistFilterSectionGroup]），行为也一致：即时生效、重置在 footer 里。
/// 两端只有外层容器不同。
Future<void> showMobilePlaylistFilterDrawer(
  BuildContext context, {
  required PlaylistFilterState current,
  required ValueChanged<PlaylistFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-playlist-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (sheetContext) => AppMobileFilterDrawer<PlaylistFilterState>(
      current: current,
      // 重置只清筛选条件，保留排序入口选择的排序。
      initial: current.resetFilters(),
      onChanged: onChanged,
      isDefault: (value) => !value.hasActiveFilters,
      scrollViewKey: const Key('mobile-playlist-filter-scroll-view'),
      contentBuilder: (context, local, onApply) =>
          PlaylistFilterSectionGroup(filterState: local, onChanged: onApply),
    ),
  );
}
