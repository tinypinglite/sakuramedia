import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';

bool ratedMovieFilterIsDefault(MovieFilterState filter) {
  return filter.status == MovieStatusFilter.all &&
      filter.collectionType == MovieCollectionTypeFilter.all &&
      filter.numberSource == MovieNumberSourceFilter.all;
}

MovieFilterState ratedMovieFilterReset(MovieFilterState filter) {
  return filter.copyWith(
    status: MovieStatusFilter.all,
    collectionType: MovieCollectionTypeFilter.all,
    numberSource: MovieNumberSourceFilter.all,
  );
}

String ratedMovieFilterLabel(MovieFilterState filter, AppLocalizations l10n) {
  final labels = <String>[
    if (filter.status != MovieStatusFilter.all) filter.status.labelWith(l10n),
    if (filter.collectionType != MovieCollectionTypeFilter.all)
      filter.collectionType.labelWith(l10n),
    if (filter.numberSource != MovieNumberSourceFilter.all)
      filter.numberSource.labelWith(l10n),
  ];
  return labels.isEmpty ? l10n.widgetMovieFilterAll : labels.join(' · ');
}

class RatedMovieFilterSections extends StatelessWidget {
  const RatedMovieFilterSections({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterOptionSection<MovieStatusFilter>(
          title: l10n.widgetMovieFilterStatusTitle,
          options: MovieStatusFilter.values,
          selectedValue: filterState.status,
          labelBuilder: (value) => value.labelWith(l10n),
          optionKeyBuilder: (value) =>
              Key('rated-movies-filter-status-${value.apiValue}'),
          onSelected: (value) => onChanged(filterState.copyWith(status: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterOptionSection<MovieCollectionTypeFilter>(
          title: l10n.widgetMovieFilterCollectionTypeTitle,
          options: MovieCollectionTypeFilter.values,
          selectedValue: filterState.collectionType,
          labelBuilder: (value) => value.labelWith(l10n),
          optionKeyBuilder: (value) =>
              Key('rated-movies-filter-collection-${value.apiValue}'),
          onSelected: (value) =>
              onChanged(filterState.copyWith(collectionType: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterOptionSection<MovieNumberSourceFilter>(
          title: l10n.widgetMovieFilterNumberSourceTitle,
          options: MovieNumberSourceFilter.values,
          selectedValue: filterState.numberSource,
          labelBuilder: (value) => value.labelWith(l10n),
          optionKeyBuilder: (value) =>
              Key('rated-movies-filter-number-source-${value.apiValue}'),
          onSelected: (value) =>
              onChanged(filterState.copyWith(numberSource: value)),
        ),
      ],
    );
  }
}

Future<void> showMobileRatedMoviesFilterDrawer(
  BuildContext context, {
  required MovieFilterState current,
  required ValueChanged<MovieFilterState> onChanged,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-rated-movies-filter-drawer'),
    maxHeightFactor: 0.5,
    builder: (_) => AppMobileFilterDrawer<MovieFilterState>(
      current: current,
      initial: ratedMovieFilterReset(current),
      onChanged: onChanged,
      isDefault: ratedMovieFilterIsDefault,
      scrollViewKey: const Key('mobile-rated-movies-filter-scroll-view'),
      contentBuilder: (context, local, onApply) =>
          RatedMovieFilterSections(filterState: local, onChanged: onApply),
    ),
  );
}
