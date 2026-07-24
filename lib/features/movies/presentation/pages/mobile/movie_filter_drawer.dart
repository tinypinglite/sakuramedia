import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

/// 弹出移动端影片筛选底部抽屉。
///
/// 内容与桌面 `MovieFilterToolbar` 的浮层面板**完全一致**（同一个
/// [MovieFilterSectionGroup] + 同一个 [AppFilterPanelFooter]），行为也一致：
/// 即时生效、重置在 footer 里。两端只有外层容器不同。
Future<void> showMobileMovieFilterDrawer(
  BuildContext context, {
  required MovieFilterState current,
  required ValueChanged<MovieFilterState> onChanged,
  List<MovieFilterYearOption> yearOptions = const <MovieFilterYearOption>[],
  bool isYearOptionsLoading = false,
  String? yearOptionsErrorMessage,
  VoidCallback? onYearOptionsRetry,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-movies-filter-drawer'),
    maxHeightFactor: 0.6,
    builder:
        (sheetContext) => _MobileMovieFilterDrawerContent(
          current: current,
          onChanged: onChanged,
          yearOptions: yearOptions,
          isYearOptionsLoading: isYearOptionsLoading,
          yearOptionsErrorMessage: yearOptionsErrorMessage,
          onYearOptionsRetry: onYearOptionsRetry,
        ),
  );
}

class _MobileMovieFilterDrawerContent extends StatefulWidget {
  const _MobileMovieFilterDrawerContent({
    required this.current,
    required this.onChanged,
    required this.yearOptions,
    required this.isYearOptionsLoading,
    required this.yearOptionsErrorMessage,
    required this.onYearOptionsRetry,
  });

  final MovieFilterState current;
  final ValueChanged<MovieFilterState> onChanged;
  final List<MovieFilterYearOption> yearOptions;
  final bool isYearOptionsLoading;
  final String? yearOptionsErrorMessage;
  final VoidCallback? onYearOptionsRetry;

  @override
  State<_MobileMovieFilterDrawerContent> createState() =>
      _MobileMovieFilterDrawerContentState();
}

class _MobileMovieFilterDrawerContentState
    extends State<_MobileMovieFilterDrawerContent> {
  late MovieFilterState _local;

  @override
  void initState() {
    super.initState();
    _local = widget.current;
  }

  /// 就地反映选中态 + 即时向外应用——不是「等确定的草稿」。
  void _apply(MovieFilterState next) {
    setState(() => _local = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      scrollViewKey: const Key('mobile-movies-filter-scroll-view'),
      footer: AppFilterPanelFooter(
        isDefault: _local.isDefault,
        onReset: () => _apply(MovieFilterState.initial),
      ),
      child: MovieFilterSectionGroup(
        filterState: _local,
        onChanged: _apply,
        yearOptions: widget.yearOptions,
        isYearOptionsLoading: widget.isYearOptionsLoading,
        yearOptionsErrorMessage: widget.yearOptionsErrorMessage,
        onYearOptionsRetry: widget.onYearOptionsRetry,
      ),
    );
  }
}
