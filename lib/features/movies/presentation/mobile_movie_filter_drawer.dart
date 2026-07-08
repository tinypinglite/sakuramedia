import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/movie_filter_state.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/navigation/app_mobile_filter_drawer_scaffold.dart';

/// 弹出移动端影片筛选底部抽屉，确定才生效。
///
/// 返回 `null` 表示取消（用户左滑关闭或没点确定）；返回值非空时调用方应 apply。
Future<MovieFilterState?> showMobileMovieFilterDrawer(
  BuildContext context, {
  required MovieFilterState current,
  List<MovieFilterYearOption> yearOptions = const <MovieFilterYearOption>[],
  bool isYearOptionsLoading = false,
  String? yearOptionsErrorMessage,
  VoidCallback? onYearOptionsRetry,
}) {
  return showAppBottomDrawer<MovieFilterState>(
    context: context,
    drawerKey: const Key('mobile-movies-filter-drawer'),
    maxHeightFactor: 0.6,
    builder:
        (sheetContext) => _MobileMovieFilterDrawerContent(
          current: current,
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
    required this.yearOptions,
    required this.isYearOptionsLoading,
    required this.yearOptionsErrorMessage,
    required this.onYearOptionsRetry,
  });

  final MovieFilterState current;
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

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      title: '筛选',
      resetButtonKey: const Key('mobile-movies-filter-drawer-reset'),
      confirmButtonKey: const Key('mobile-movies-filter-drawer-confirm'),
      onReset:
          _local.isDefault
              ? null
              : () => setState(() => _local = MovieFilterState.initial),
      onConfirm: () => Navigator.of(context).pop(_local),
      child: MovieFilterSectionGroup(
        filterState: _local,
        onChanged: (next) => setState(() => _local = next),
        yearOptions: widget.yearOptions,
        isYearOptionsLoading: widget.isYearOptionsLoading,
        yearOptionsErrorMessage: widget.yearOptionsErrorMessage,
        onYearOptionsRetry: widget.onYearOptionsRetry,
      ),
    );
  }
}
