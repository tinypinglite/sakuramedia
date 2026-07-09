import 'package:flutter/material.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_sort.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranking_filter_sections.dart';
import 'package:sakuramedia/widgets/base/overlays/app_filter_popover.dart';

class RankingFilterToolbar extends StatelessWidget {
  const RankingFilterToolbar({
    super.key,
    required this.sources,
    required this.selectedSource,
    required this.boards,
    required this.selectedBoard,
    required this.selectedPeriod,
    required this.onSourceChanged,
    required this.onBoardChanged,
    required this.onPeriodChanged,
    required this.isLoading,
    required this.selectedSortField,
    required this.selectedSortDirection,
    required this.onSortChanged,
  });

  final List<RankingSourceDto> sources;
  final RankingSourceDto? selectedSource;
  final List<RankingBoardDto> boards;
  final RankingBoardDto? selectedBoard;
  final String? selectedPeriod;
  final ValueChanged<RankingSourceDto> onSourceChanged;
  final ValueChanged<RankingBoardDto> onBoardChanged;
  final ValueChanged<String> onPeriodChanged;
  final bool isLoading;
  final RankingSortField? selectedSortField;
  final SortDirection selectedSortDirection;
  final void Function(RankingSortField? field, SortDirection direction)
  onSortChanged;

  String _buildTriggerLabel() {
    final sourceLabel = selectedSource?.name ?? '全部来源';
    final boardLabel = selectedBoard?.name ?? '全部榜单';
    final periodLabel = selectedPeriod == null
        ? '默认周期'
        : rankingPeriodLabel(selectedPeriod!);
    return '$sourceLabel / $boardLabel / $periodLabel';
  }

  @override
  Widget build(BuildContext context) {
    return AppFilterPopover(
      triggerLabel: _buildTriggerLabel(),
      labelKey: const Key('rankings-filter-trigger-label'),
      panelKey: const Key('rankings-filter-panel'),
      enabled: !isLoading,
      panelExtraWidth: 520,
      initialTriggerSize: const Size(220, 36),
      panelBuilder: (_) => RankingFilterSectionGroup(
        sources: sources,
        selectedSource: selectedSource,
        boards: boards,
        selectedBoard: selectedBoard,
        selectedPeriod: selectedPeriod,
        onSourceChanged: onSourceChanged,
        onBoardChanged: onBoardChanged,
        onPeriodChanged: onPeriodChanged,
        selectedSortField: selectedSortField,
        selectedSortDirection: selectedSortDirection,
        onSortChanged: onSortChanged,
      ),
    );
  }
}
