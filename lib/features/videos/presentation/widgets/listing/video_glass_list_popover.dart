import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';

/// 桌面视频列表筛选弹层内容。
class VideoGlassFilterPopoverContent extends StatelessWidget {
  const VideoGlassFilterPopoverContent({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final VideoFilterState filterState;
  final ValueChanged<VideoFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFilterChoiceSection<bool>(
      title: l10n.videoFilterSectionCollectionOwnership,
      controlKey: const Key('videos-filter-collection'),
      items: <AppSegmentedItem<bool>>[
        AppSegmentedItem(value: false, label: l10n.videoFilterAll),
        AppSegmentedItem(value: true, label: l10n.videoFilterNotInCollection),
      ],
      selected: filterState.uncollected,
      onChanged: (uncollected) =>
          onChanged(filterState.copyWith(uncollected: uncollected)),
    );
  }
}
