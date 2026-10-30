import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

/// 弹出移动端影片筛选底部抽屉。
///
/// 内容与桌面 `AppListHeader` 的就地浮层面板**完全一致**（同一个
/// [MovieFilterSectionGroup]），行为也一致：即时生效、重置在 footer 里。
/// 两端只有外层容器不同。
Future<void> showMobileMovieFilterDrawer(
  BuildContext context, {
  required MovieFilterState current,
  required ValueChanged<MovieFilterState> onChanged,
  Widget? tagSection,
  Widget Function(
    BuildContext context,
    MovieFilterState local,
    ValueChanged<MovieFilterState> onApply,
  )?
  mediaTagSectionBuilder,
  bool showActorAgeSection = true,
  ValueListenable<bool>? extraActive,
  VoidCallback? onResetExtra,
  List<MovieFilterYearOption>? yearOptions,
  bool isYearOptionsLoading = false,
  String? yearOptionsErrorMessage,
  VoidCallback? onYearOptionsRetry,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-movies-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (sheetContext) => AppMobileFilterDrawer<MovieFilterState>(
      current: current,
      // 重置只清筛选条件，保留排序入口选择的排序。
      initial: current.resetFilters(),
      onChanged: onChanged,
      isDefault: (value) => !value.hasActiveFilters,
      extraActive: extraActive,
      onExtraReset: onResetExtra,
      scrollViewKey: const Key('mobile-movies-filter-scroll-view'),
      contentBuilder: (context, local, onApply) => MovieFilterSectionGroup(
        filterState: local,
        onChanged: onApply,
        tagSection: tagSection,
        mediaTagSection: mediaTagSectionBuilder?.call(context, local, onApply),
        showActorAgeSection: showActorAgeSection,
        yearOptions: yearOptions,
        isYearOptionsLoading: isYearOptionsLoading,
        yearOptionsErrorMessage: yearOptionsErrorMessage,
        onYearOptionsRetry: onYearOptionsRetry,
      ),
    ),
  );
}
