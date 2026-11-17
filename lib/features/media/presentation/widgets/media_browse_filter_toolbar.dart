import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';

/// 面板内的分节 Column：归属 / 媒体库 / 缩略图。
///
/// 桌面玻璃弹层和移动玻璃抽屉共用同一套中性分段控件；
/// 排序不在筛选面板里，见 `MediaSortMenuButton`。
class MediaBrowseFilterSectionGroup extends StatelessWidget {
  const MediaBrowseFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.libraries,
    required this.onChanged,
  });

  final MediaBrowseFilterState filterState;
  final List<MediaLibraryDto> libraries;
  final ValueChanged<MediaBrowseFilterState> onChanged;

  static List<_KindOption> _kindOptions(AppLocalizations l10n) => [
    _KindOption(
      label: l10n.mediaListFilterAll,
      kind: null,
      itemKey: Key('media-kind-all'),
    ),
    _KindOption(
      label: l10n.mediaListKindJav,
      kind: MediaListItemKind.jav,
      itemKey: Key('media-kind-jav'),
    ),
    _KindOption(
      label: MediaListItemKind.video.labelWith(l10n: l10n),
      kind: MediaListItemKind.video,
      itemKey: Key('media-kind-video'),
    ),
  ];

  static const List<MediaBrowseThumbnailGenerationFilter?>
  _thumbnailGenerationOrder = [
    null,
    MediaBrowseThumbnailGenerationFilter.pending,
    MediaBrowseThumbnailGenerationFilter.retryWait,
    MediaBrowseThumbnailGenerationFilter.terminal,
    MediaBrowseThumbnailGenerationFilter.succeeded,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.appSpacing;
    final selectedLibraryId =
        libraries.any((library) => library.id == filterState.libraryId)
        ? filterState.libraryId
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterChoiceSection<MediaBrowseKindFilter?>(
          title: l10n.mediaListFilterSectionSource,
          controlKey: const Key('media-kind-filter-control'),
          items: [
            for (final option in _kindOptions(l10n))
              AppSegmentedItem<MediaBrowseKindFilter?>(
                key: option.itemKey,
                label: option.label,
                value: option.kind,
              ),
          ],
          selected: filterState.kind,
          onChanged: (value) => onChanged(
            filterState.copyWith(kind: value, resetKind: value == null),
          ),
        ),
        SizedBox(height: spacing.lg),
        AppFilterChoiceSection<int?>(
          title: l10n.mediaListFilterSectionLibrary,
          controlKey: const Key('media-library-filter-control'),
          items: [
            AppSegmentedItem<int?>(
              value: null,
              label: l10n.mediaListFilterAllLibraries,
              key: const Key('media-library-filter-all'),
            ),
            for (final library in libraries)
              AppSegmentedItem<int?>(
                value: library.id,
                label: library.name,
                key: Key('media-library-filter-${library.id}'),
              ),
          ],
          selected: selectedLibraryId,
          onChanged: (value) =>
              onChanged(filterState.copyWith(libraryId: value)),
        ),
        SizedBox(height: spacing.lg),
        AppFilterChoiceSection<MediaBrowseThumbnailGenerationFilter?>(
          title: l10n.mediaListFilterSectionThumbnail,
          controlKey: const Key('media-thumbnail-generation-filter-control'),
          items: [
            for (final filter in _thumbnailGenerationOrder)
              AppSegmentedItem<MediaBrowseThumbnailGenerationFilter?>(
                value: filter,
                label: filter?.labelWith(l10n: l10n) ?? l10n.mediaListFilterAll,
                key: Key(
                  'media-thumbnail-generation-filter-${filter?.name ?? 'all'}',
                ),
              ),
          ],
          selected: filterState.thumbnailGenerationState,
          onChanged: (value) =>
              onChanged(filterState.copyWith(thumbnailGenerationState: value)),
        ),
      ],
    );
  }
}

class _KindOption {
  const _KindOption({
    required this.label,
    required this.kind,
    required this.itemKey,
  });
  final String label;
  final MediaBrowseKindFilter kind;
  final Key itemKey;
}
