import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/features/rankings/presentation/rankings_placeholders.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/features/shared/data/movie_interaction_filter.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_filter_sections.dart';

/// 榜单筛选 section 锚点——chip 点击后定位到对应 section。
enum RankingFilterAnchor { source, board, period }

class RankingFilterSectionKeys {
  RankingFilterSectionKeys({
    GlobalKey? source,
    GlobalKey? board,
    GlobalKey? period,
  }) : source = source ?? GlobalKey(),
       board = board ?? GlobalKey(),
       period = period ?? GlobalKey();

  final GlobalKey source;
  final GlobalKey board;
  final GlobalKey period;

  GlobalKey forAnchor(RankingFilterAnchor anchor) => switch (anchor) {
    RankingFilterAnchor.source => source,
    RankingFilterAnchor.board => board,
    RankingFilterAnchor.period => period,
  };
}

/// 榜单筛选所有 section 的纵向 Column，桌面 panel 和移动抽屉共用。
///
/// 每个 section 外层 Container 挂有 [sectionKeys] 对应 GlobalKey，
/// 调用方可 `Scrollable.ensureVisible(sectionKeys.forAnchor(anchor).currentContext!)` 滚动定位。
class RankingFilterSectionGroup extends ConsumerWidget {
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
    required this.interaction,
    required this.onInteractionChanged,
    this.isBoardLoading = false,
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
  final MovieInteractionFilter interaction;
  final ValueChanged<MovieInteractionFilter> onInteractionChanged;
  final RankingFilterSectionKeys? sectionKeys;

  /// 切换来源后榜单（含周期）正在加载：榜单 / 周期分节显示骨架占位，
  /// 避免面板先塌成空标题、数据到达后再整块恢复的生硬跳变。
  final bool isBoardLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsEnabled = ref.watch(statsFeaturesEnabledProvider);
    final boardOptions = isBoardLoading ? rankingBoardPlaceholders() : boards;
    final periodOptions = isBoardLoading
        ? rankingPeriodPlaceholders()
        : selectedBoard?.supportedPeriods ?? const <String>[];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyedSubtree(
          key: sectionKeys?.source,
          child: AppFilterOptionSection<RankingSourceDto>(
            title: l10n.rankingFilterSource,
            options: sources,
            selectedValue: selectedSource,
            optionKeyBuilder: (value) =>
                Key('rankings-filter-source-${value.sourceKey}'),
            labelBuilder: (value) => value.name,
            onSelected: onSourceChanged,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        KeyedSubtree(
          key: sectionKeys?.board,
          child: AppFilterOptionSection<RankingBoardDto>(
            title: l10n.rankingFilterBoard,
            options: boardOptions,
            selectedValue: selectedBoard,
            isLoading: isBoardLoading,
            optionKeyBuilder: (value) =>
                Key('rankings-filter-board-${value.boardKey}'),
            labelBuilder: (value) => value.name,
            onSelected: onBoardChanged,
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        KeyedSubtree(
          key: sectionKeys?.period,
          child: AppFilterOptionSection<String>(
            title: l10n.rankingFilterPeriod,
            options: periodOptions,
            selectedValue: selectedPeriod,
            isLoading: isBoardLoading,
            optionKeyBuilder: (value) => Key('rankings-filter-period-$value'),
            labelBuilder: (value) => rankingPeriodLabel(value, l10n),
            onSelected: onPeriodChanged,
          ),
        ),
        if (statsEnabled) ...[
          SizedBox(height: context.appSpacing.lg),
          MovieInteractionRangeFilterSectionGroup(
            filter: interaction,
            onChanged: onInteractionChanged,
          ),
        ],
      ],
    );
  }
}
