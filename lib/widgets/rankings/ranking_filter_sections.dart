import 'package:flutter/material.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_sort.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 榜单筛选 section 锚点——chip 点击后定位到对应 section。
enum RankingFilterAnchor { source, board, period, sort }

class RankingFilterSectionKeys {
  RankingFilterSectionKeys({
    GlobalKey? source,
    GlobalKey? board,
    GlobalKey? period,
    GlobalKey? sort,
  })  : source = source ?? GlobalKey(),
        board = board ?? GlobalKey(),
        period = period ?? GlobalKey(),
        sort = sort ?? GlobalKey();

  final GlobalKey source;
  final GlobalKey board;
  final GlobalKey period;
  final GlobalKey sort;

  GlobalKey forAnchor(RankingFilterAnchor anchor) => switch (anchor) {
    RankingFilterAnchor.source => source,
    RankingFilterAnchor.board => board,
    RankingFilterAnchor.period => period,
    RankingFilterAnchor.sort => sort,
  };
}

/// 榜单筛选所有 section 的纵向 Column，桌面 panel 和移动抽屉共用。
///
/// 每个 section 外层 Container 挂有 [sectionKeys] 对应 GlobalKey，
/// 调用方可 `Scrollable.ensureVisible(sectionKeys.forAnchor(anchor).currentContext!)` 滚动定位。
class RankingFilterSectionGroup extends StatelessWidget {
  const RankingFilterSectionGroup({
    super.key,
    required this.sources,
    required this.selectedSource,
    required this.boards,
    required this.selectedBoard,
    required this.selectedPeriod,
    required this.onSourceChanged,
    required this.onBoardChanged,
    required this.onPeriodChanged,
    required this.selectedSortField,
    required this.selectedSortDirection,
    required this.onSortChanged,
    this.sectionKeys,
  });

  final List<RankingSourceDto> sources;
  final RankingSourceDto? selectedSource;
  final List<RankingBoardDto> boards;
  final RankingBoardDto? selectedBoard;
  final String? selectedPeriod;
  final ValueChanged<RankingSourceDto> onSourceChanged;
  final ValueChanged<RankingBoardDto> onBoardChanged;
  final ValueChanged<String> onPeriodChanged;
  final RankingSortField? selectedSortField;
  final SortDirection selectedSortDirection;
  final void Function(RankingSortField? field, SortDirection direction)
      onSortChanged;
  final RankingFilterSectionKeys? sectionKeys;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyedSubtree(
          key: sectionKeys?.source,
          child: RankingFilterChoiceSection<RankingSourceDto>(
            title: '来源',
            options: sources,
            selectedValue: selectedSource,
            optionKeyBuilder:
                (value) => Key('rankings-filter-source-${value.sourceKey}'),
            labelBuilder: (value) => value.name,
            onSelected: onSourceChanged,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        KeyedSubtree(
          key: sectionKeys?.board,
          child: RankingFilterChoiceSection<RankingBoardDto>(
            title: '榜单',
            options: boards,
            selectedValue: selectedBoard,
            optionKeyBuilder:
                (value) => Key('rankings-filter-board-${value.boardKey}'),
            labelBuilder: (value) => value.name,
            onSelected: onBoardChanged,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        KeyedSubtree(
          key: sectionKeys?.period,
          child: RankingFilterChoiceSection<String>(
            title: '周期',
            options: selectedBoard?.supportedPeriods ?? const <String>[],
            selectedValue: selectedPeriod,
            optionKeyBuilder: (value) => Key('rankings-filter-period-$value'),
            labelBuilder: rankingPeriodLabel,
            onSelected: onPeriodChanged,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        KeyedSubtree(
          key: sectionKeys?.sort,
          child: RankingSortSection(
            selectedSortField: selectedSortField,
            selectedSortDirection: selectedSortDirection,
            onSortChanged: onSortChanged,
          ),
        ),
      ],
    );
  }
}

class RankingFilterChoiceSection<T> extends StatelessWidget {
  const RankingFilterChoiceSection({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.optionKeyBuilder,
    required this.labelBuilder,
    required this.onSelected,
  });

  final String title;
  final List<T> options;
  final T? selectedValue;
  final Key Function(T value) optionKeyBuilder;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        Wrap(
          spacing: context.appSpacing.sm,
          runSpacing: context.appSpacing.sm,
          children:
              options
                  .map(
                    (value) => AppTextButton(
                      key: optionKeyBuilder(value),
                      label: labelBuilder(value),
                      size: AppTextButtonSize.xSmall,
                      isSelected: value == selectedValue,
                      onPressed: () => onSelected(value),
                    ),
                  )
                  .toList(growable: false),
        ),
      ],
    );
  }
}

class RankingSortSection extends StatelessWidget {
  const RankingSortSection({
    super.key,
    required this.selectedSortField,
    required this.selectedSortDirection,
    required this.onSortChanged,
  });

  final RankingSortField? selectedSortField;
  final SortDirection selectedSortDirection;
  final void Function(RankingSortField? field, SortDirection direction)
      onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '排序',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        Wrap(
          spacing: context.appSpacing.sm,
          runSpacing: context.appSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppTextButton(
              key: const Key('rankings-filter-sort-default'),
              label: '默认（名次）',
              size: AppTextButtonSize.xSmall,
              isSelected: selectedSortField == null,
              onPressed: () => onSortChanged(null, selectedSortDirection),
            ),
            AppTextButton(
              key: const Key('rankings-filter-sort-heat'),
              label: RankingSortField.heat.label,
              size: AppTextButtonSize.xSmall,
              isSelected: selectedSortField == RankingSortField.heat,
              onPressed: () =>
                  onSortChanged(RankingSortField.heat, selectedSortDirection),
            ),
            if (selectedSortField != null)
              AppTextButton(
                key: const Key('rankings-filter-sort-direction'),
                label: selectedSortDirection.label,
                icon: Icon(
                  selectedSortDirection == SortDirection.desc
                      ? Icons.south_rounded
                      : Icons.north_rounded,
                ),
                size: AppTextButtonSize.xSmall,
                onPressed: () => onSortChanged(
                  selectedSortField,
                  selectedSortDirection == SortDirection.desc
                      ? SortDirection.asc
                      : SortDirection.desc,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
