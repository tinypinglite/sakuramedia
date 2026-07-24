import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

class MovieFilterToolbar extends StatelessWidget {
  const MovieFilterToolbar({
    super.key,
    required this.filterState,
    required this.onChanged,
    required this.onReset,
    this.yearOptions = const <MovieFilterYearOption>[],
    this.isYearOptionsLoading = false,
    this.yearOptionsErrorMessage,
    this.onYearOptionsRetry,
    this.onOpened,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onChanged;
  final VoidCallback onReset;
  final List<MovieFilterYearOption> yearOptions;
  final bool isYearOptionsLoading;
  final String? yearOptionsErrorMessage;
  final VoidCallback? onYearOptionsRetry;
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    final isDefault = filterState.isDefault;

    // 曾经在 popover 旁边平铺过「最新订阅 / 最新入库」两个预设按钮，已删除：
    // 移动端顶栏没有这排按钮的位置，两端对齐后预设一律走面板内的筛选项。
    return AppFilterPopover(
      triggerLabel: filterState.triggerLabel,
      labelKey: const Key('movies-filter-trigger-label'),
      panelKey: const Key('movies-filter-panel'),
      scrollViewKey: const Key('movies-filter-scroll-view'),
      isSelected: !isDefault,
      highlightWhenOpen: false,
      panelExtraWidth: 260,
      onOpened: onOpened,
      panelBuilder:
          (_) => MovieFilterSectionGroup(
            filterState: filterState,
            onChanged: onChanged,
            yearOptions: yearOptions,
            isYearOptionsLoading: isYearOptionsLoading,
            yearOptionsErrorMessage: yearOptionsErrorMessage,
            onYearOptionsRetry: onYearOptionsRetry,
          ),
      footer: AppFilterPanelFooter(isDefault: isDefault, onReset: onReset),
    );
  }
}
