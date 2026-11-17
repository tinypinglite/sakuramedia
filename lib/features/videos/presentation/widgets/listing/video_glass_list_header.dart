import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/presentation/providers/paged_async_notifier.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/features/videos/presentation/widgets/listing/video_glass_list_popover.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_filter_popover.dart';
import 'package:sakuramedia/widgets/domain/videos/video_sort_menu_button.dart';

/// 桌面视频列表的玻璃控制条。
class VideoGlassListHeader extends StatelessWidget {
  const VideoGlassListHeader({
    super.key,
    required this.filterState,
    required this.total,
    required this.filterUpdate,
    required this.hasPreviousFilterItems,
    required this.onFilterChanged,
    required this.onRetryFilter,
    this.onEnterSelection,
    this.selectionHeader,
    this.totalKey,
  });

  final VideoFilterState filterState;
  final int total;
  final FilterUpdateState filterUpdate;
  final bool hasPreviousFilterItems;
  final ValueChanged<VideoFilterState> onFilterChanged;
  final VoidCallback onRetryFilter;
  final VoidCallback? onEnterSelection;
  final Widget? selectionHeader;
  final Key? totalKey;

  @override
  Widget build(BuildContext context) {
    final selection = selectionHeader;
    if (selection != null) {
      return selection;
    }

    final l10n = AppLocalizations.of(context);
    final reset = () => onFilterChanged(filterState.resetFilters());
    return AppGlassListHeader(
      leading: AppGlassFilterPopover(
        panelKey: const Key('videos-filter-popover'),
        isDefault: !filterState.hasActiveFilters,
        onReset: reset,
        resetKey: const Key('videos-filter-reset'),
        triggerKey: const Key('videos-filter-trigger'),
        label: filterState.triggerLabel(l10n),
        info: <Widget>[
          AppGlassHeaderText(
            key: totalKey ?? const Key('videos-page-total'),
            label: l10n.videoTotalCount(total),
          ),
        ],
        panelBuilder: (context) => VideoGlassFilterPopoverContent(
          filterState: filterState,
          onChanged: onFilterChanged,
        ),
      ),
      trailing: AppGlassHeaderGroup(
        children: <Widget>[
          VideoSortMenuButton(
            triggerKey: const Key('videos-sort-trigger'),
            panelKey: const Key('videos-sort-popover'),
            filterState: filterState,
            onChanged: onFilterChanged,
            glassGrouped: true,
            fieldControlKey: const Key('videos-sort-field'),
            directionControlKey: const Key('videos-sort-direction'),
          ),
          if (onEnterSelection != null)
            AppGlassHeaderButton(
              key: const Key('videos-enter-selection-button'),
              icon: Icons.check_circle_outline,
              label: l10n.baseSelect,
              onTap: onEnterSelection!,
            ),
        ],
      ),
      filterUpdate: filterUpdate,
      hasPreviousFilterItems: hasPreviousFilterItems,
      onRetryFilter: onRetryFilter,
    );
  }
}
