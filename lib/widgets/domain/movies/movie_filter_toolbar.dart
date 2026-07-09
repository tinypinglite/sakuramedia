import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
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
    final isPreset = MovieFilterPreset.values.any(filterState.matchesPreset);
    final isCustom = !isDefault && !isPreset;

    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      children: [
        AppFilterPopover(
          triggerLabel: filterState.triggerLabel,
          labelKey: const Key('movies-filter-trigger-label'),
          panelKey: const Key('movies-filter-panel'),
          scrollViewKey: const Key('movies-filter-scroll-view'),
          isSelected: isDefault || isCustom,
          highlightWhenOpen: false,
          panelExtraWidth: 260,
          onOpened: onOpened,
          panelBuilder: (_) => MovieFilterSectionGroup(
            filterState: filterState,
            onChanged: onChanged,
            yearOptions: yearOptions,
            isYearOptionsLoading: isYearOptionsLoading,
            yearOptionsErrorMessage: yearOptionsErrorMessage,
            onYearOptionsRetry: onYearOptionsRetry,
          ),
          footer: AppFilterPanelFooter(
            isDefault: isDefault,
            onReset: onReset,
          ),
        ),
        for (final preset in MovieFilterPreset.values)
          AppTextButton(
            key: Key('movies-filter-preset-${preset.key}'),
            label: preset.label,
            size: AppTextButtonSize.small,
            isSelected: filterState.matchesPreset(preset),
            onPressed: () => onChanged(preset.filterState),
          ),
      ],
    );
  }
}
