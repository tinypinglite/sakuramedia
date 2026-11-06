import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/videos/presentation/controllers/listing/video_filter_state.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';

/// 视频列表筛选所有 section 的纵向 Column。
///
/// 桌面玻璃筛选浮层和移动筛选抽屉都用它，避免双份维护。
/// 底栏/重置按钮由调用方自己附加。排序不在筛选面板里，见
/// `VideoSortMenuButton`。
class VideoFilterSectionGroup extends StatelessWidget {
  const VideoFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final VideoFilterState filterState;
  final ValueChanged<VideoFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterOptionSection<bool>(
          title: l10n.videoFilterSectionCollection,
          options: const <bool>[false, true],
          selectedValue: filterState.uncollected,
          optionKeyBuilder: (uncollected) => Key(
            uncollected
                ? 'videos-filter-collection-uncollected'
                : 'videos-filter-collection-all',
          ),
          labelBuilder: (uncollected) => uncollected
              ? l10n.videoFilterNotInCollection
              : l10n.videoFilterAll,
          onSelected: (uncollected) =>
              onChanged(filterState.copyWith(uncollected: uncollected)),
        ),
      ],
    );
  }
}
