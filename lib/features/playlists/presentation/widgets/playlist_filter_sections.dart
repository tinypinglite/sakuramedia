import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/playlists/presentation/controllers/playlist_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';
import 'package:sakuramedia/widgets/domain/tags/app_tag_match_mode_toggle.dart';
import 'package:sakuramedia/widgets/domain/tags/media_tag_filter_section.dart';

/// 普通播放列表和智能播放列表共用的临时筛选面板。
///
/// 桌面玻璃浮层和移动端底部抽屉都渲染这个组件，避免两端筛选维度分叉。
class PlaylistFilterSectionGroup extends StatelessWidget {
  const PlaylistFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.onChanged,
    this.tagSection,
  });

  final PlaylistFilterState filterState;
  final ValueChanged<PlaylistFilterState> onChanged;

  /// 目录标签选择分节；调用方没有标签选择能力时不渲染。
  final Widget? tagSection;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final yearOptions = buildDefaultMovieFilterYearOptions();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlaylistMultiChoiceSection<MovieStatusFilter>(
          title: l10n.widgetMovieFilterStatusTitle,
          values: MovieStatusFilter.values
              .where((value) => value != MovieStatusFilter.all)
              .toList(growable: false),
          selected: filterState.statuses,
          matchMode: filterState.statusMatch,
          labelBuilder: (value) => value.labelWith(l10n),
          keyBuilder: (value) => Key('playlist-filter-status-${value.name}'),
          allKey: const Key('playlist-filter-status-all'),
          matchToggleKeyPrefix: 'playlist-filter-status-match',
          onChanged: (values) =>
              onChanged(filterState.copyWith(statuses: values)),
          onMatchModeChanged: (value) =>
              onChanged(filterState.copyWith(statusMatch: value)),
        ),
        SizedBox(height: spacing.lg),
        _PlaylistMultiChoiceSection<MovieWatchStatusFilter>(
          title: l10n.movieFilterWatchStatusTitle,
          values: MovieWatchStatusFilter.values
              .where((value) => value != MovieWatchStatusFilter.all)
              .toList(growable: false),
          selected: filterState.watchStatuses,
          matchMode: filterState.watchMatch,
          labelBuilder: (value) => value.labelWith(l10n),
          keyBuilder: (value) =>
              Key('playlist-filter-watch-status-${value.name}'),
          allKey: const Key('playlist-filter-watch-status-all'),
          matchToggleKeyPrefix: 'playlist-filter-watch-match',
          onChanged: (values) =>
              onChanged(filterState.copyWith(watchStatuses: values)),
          onMatchModeChanged: (value) =>
              onChanged(filterState.copyWith(watchMatch: value)),
        ),
        SizedBox(height: spacing.lg),
        _PlaylistMultiChoiceSection<PlaylistResolutionFilter>(
          title: l10n.playlistFilterResolution,
          values: PlaylistResolutionFilter.values,
          selected: filterState.resolutions,
          labelBuilder: (value) => value.label,
          keyBuilder: (value) =>
              Key('playlist-filter-resolution-${value.apiValue}'),
          allKey: const Key('playlist-filter-resolution-all'),
          onChanged: (values) =>
              onChanged(filterState.copyWith(resolutions: values)),
        ),
        SizedBox(height: spacing.lg),
        MovieYearFilterSection(
          options: yearOptions,
          selectedYears: filterState.years,
          isLoading: false,
          errorMessage: null,
          onRetry: null,
          onChanged: (value) => onChanged(filterState.copyWith(years: value)),
        ),
        if (tagSection != null) ...[SizedBox(height: spacing.lg), tagSection!],
        SizedBox(height: spacing.lg),
        MediaTagFilterSection(
          mediaTagIds: filterState.mediaTagIds,
          mediaTagMatch: filterState.mediaTagMatch,
          onChanged: (ids, matchMode) => onChanged(
            filterState.copyWith(mediaTagIds: ids, mediaTagMatch: matchMode),
          ),
        ),
      ],
    );
  }
}

class _PlaylistMultiChoiceSection<T> extends StatelessWidget {
  const _PlaylistMultiChoiceSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.keyBuilder,
    required this.allKey,
    required this.onChanged,
    this.matchMode,
    this.matchToggleKeyPrefix,
    this.onMatchModeChanged,
  });

  final String title;
  final List<T> values;
  final Set<T> selected;
  final String Function(T value) labelBuilder;
  final Key Function(T value) keyBuilder;
  final Key allKey;
  final ValueChanged<Set<T>> onChanged;
  final TagMatchMode? matchMode;
  final String? matchToggleKeyPrefix;
  final ValueChanged<TagMatchMode>? onMatchModeChanged;

  void _toggle(T value) {
    final next = Set<T>.of(selected);
    if (!next.remove(value)) {
      next.add(value);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final canChangeMatchMode =
        selected.length > 1 &&
        matchMode != null &&
        matchToggleKeyPrefix != null &&
        onMatchModeChanged != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.secondary,
                ),
              ),
            ),
            if (canChangeMatchMode)
              AppTagMatchModeToggle(
                matchMode: matchMode!,
                buttonKeyPrefix: matchToggleKeyPrefix!,
                onChanged: onMatchModeChanged!,
              ),
          ],
        ),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            AppFilterChip(
              key: allKey,
              label: l10n.playlistFilterAll,
              selected: selected.isEmpty,
              onPressed: selected.isEmpty ? null : () => onChanged(<T>{}),
            ),
            for (final value in values)
              AppFilterChip(
                key: keyBuilder(value),
                label: labelBuilder(value),
                selected: selected.contains(value),
                onPressed: () => _toggle(value),
              ),
          ],
        ),
      ],
    );
  }
}
