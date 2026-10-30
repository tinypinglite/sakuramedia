import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/configuration/data/dto/media_library_dto.dart';
import 'package:sakuramedia/features/media/data/media_list_item_dto.dart';
import 'package:sakuramedia/features/media/presentation/media_browse_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/navigation/app_filter_entry_button.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart'
    show AppFilterPanelFooter, AppFilterPopover, AppFilterPopoverAlignment;
import 'package:sakuramedia/widgets/domain/media/media_sort_menu_button.dart';

/// 「媒体管理」筛选工具栏：仿 `MovieFilterToolbar` 的 popover 触发按钮 +
/// 内部分节面板 + 底部重置。
///
/// 归属 / 所属媒体库 / 缩略图状态 / 排序方式全部通过 chip 选择，
/// 避免多项状态挤在下拉里。
class MediaBrowseFilterToolbar extends StatelessWidget {
  const MediaBrowseFilterToolbar({
    super.key,
    required this.filterState,
    required this.libraries,
    required this.onChanged,
    required this.onReset,
  });

  final MediaBrowseFilterState filterState;
  final List<MediaLibraryDto> libraries;
  final ValueChanged<MediaBrowseFilterState> onChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: context.appComponentTokens.mobileTopTabHeight,
          child: AppFilterPopover(
            triggerLabel: filterState.triggerLabel(l10n),
            panelKey: const Key('media-management-filter-panel'),
            scrollViewKey: const Key('media-management-filter-scroll-view'),
            panelExtraWidth: 240,
            // 面板 trigger 位于 leading 最左端，向右延伸自然填入内容区、
            // 不会反过来遮挡左侧配置分类栏。
            alignment: AppFilterPopoverAlignment.leftAlignedToTrigger,
            triggerBuilder: (context, isOpen, toggle) => AppFilterEntryButton(
              key: const Key('media-management-filter-trigger'),
              icon: Icons.tune_rounded,
              label: filterState.triggerLabel(l10n),
              tooltip: l10n.mediaListFilterTooltip,
              trailingIcon: isOpen
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              onTap: toggle,
            ),
            panelBuilder: (_) => MediaBrowseFilterSectionGroup(
              filterState: filterState,
              libraries: libraries,
              onChanged: onChanged,
            ),
            footer: AppFilterPanelFooter(
              isDefault: !filterState.hasActiveFilters,
              onReset: onReset,
            ),
          ),
        ),
        SizedBox(width: context.appSpacing.xs),
        SizedBox(
          height: context.appComponentTokens.mobileTopTabHeight,
          child: MediaSortMenuButton(
            triggerKey: const Key('media-management-sort-trigger'),
            panelKey: const Key('media-management-sort-panel'),
            filterState: filterState,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// 面板内的分节 Column：归属 / 媒体库 / 缩略图，各自 chip 选择。
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(text: l10n.mediaListFilterSectionSource),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            for (final option in _kindOptions(l10n))
              AppTextButton(
                key: option.itemKey,
                label: option.label,
                size: AppTextButtonSize.xSmall,
                isSelected: filterState.kind == option.kind,
                onPressed: () => onChanged(
                  filterState.copyWith(
                    kind: option.kind,
                    resetKind: option.kind == null,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.lg),
        _SectionTitle(text: l10n.mediaListFilterSectionLibrary),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            AppTextButton(
              key: const Key('media-library-filter-all'),
              label: l10n.mediaListFilterAllLibraries,
              size: AppTextButtonSize.xSmall,
              isSelected: filterState.libraryId == null,
              onPressed: () => onChanged(filterState.copyWith(libraryId: null)),
            ),
            for (final library in libraries)
              AppTextButton(
                key: Key('media-library-filter-${library.id}'),
                label: library.name,
                size: AppTextButtonSize.xSmall,
                isSelected: filterState.libraryId == library.id,
                onPressed: () =>
                    onChanged(filterState.copyWith(libraryId: library.id)),
              ),
          ],
        ),
        SizedBox(height: spacing.lg),
        _SectionTitle(text: l10n.mediaListFilterSectionThumbnail),
        SizedBox(height: spacing.sm),
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.sm,
          children: [
            for (final filter in _thumbnailGenerationOrder)
              AppTextButton(
                key: Key(
                  'media-thumbnail-generation-filter-${filter?.name ?? 'all'}',
                ),
                label: filter?.labelWith(l10n: l10n) ?? l10n.mediaListFilterAll,
                size: AppTextButtonSize.xSmall,
                isSelected: filterState.thumbnailGenerationState == filter,
                onPressed: () => onChanged(
                  filterState.copyWith(thumbnailGenerationState: filter),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: resolveAppTextStyle(
        context,
        size: AppTextSize.s14,
        weight: AppTextWeight.regular,
        tone: AppTextTone.primary,
      ),
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
