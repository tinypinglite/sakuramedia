import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_state.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranking_filter_sections.dart';
import 'package:sakuramedia/features/shared/data/movie_interaction_filter.dart';

/// 榜单筛选的四个动作。桌面浮层和移动抽屉共用同一组入口，避免各自
/// 直接读 provider 后再补一遍相同的同值守卫。
typedef RankingsFilterActions = ({
  ValueChanged<RankingSourceDto> selectSource,
  ValueChanged<RankingBoardDto> selectBoard,
  ValueChanged<String> selectPeriod,
  ValueChanged<MovieInteractionFilter> selectInteraction,
});

/// 榜单筛选面板。只负责把 [RankingFilterState] 映射到共享 section，
/// 容器差异由桌面浮层 / 移动抽屉各自决定。
class RankingsFilterPanel extends StatelessWidget {
  const RankingsFilterPanel({
    super.key,
    required this.filters,
    required this.actions,
    this.sectionKeys,
  });

  final RankingFilterState filters;
  final RankingsFilterActions actions;
  final RankingFilterSectionKeys? sectionKeys;

  @override
  Widget build(BuildContext context) {
    return RankingFilterSectionGroup(
      sources: filters.sources,
      selectedSource: filters.selectedSource,
      boards: filters.boards,
      selectedBoard: filters.selectedBoard,
      selectedPeriod: filters.selectedPeriod,
      isBoardLoading: filters.isLoading,
      onSourceChanged: actions.selectSource,
      onBoardChanged: actions.selectBoard,
      onPeriodChanged: actions.selectPeriod,
      interaction: filters.interaction,
      onInteractionChanged: actions.selectInteraction,
      sectionKeys: sectionKeys,
    );
  }
}
