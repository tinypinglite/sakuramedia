import 'package:flutter/material.dart';
import 'package:sakuramedia/features/rankings/data/ranking_board_dto.dart';
import 'package:sakuramedia/features/rankings/data/ranking_sort.dart';
import 'package:sakuramedia/features/rankings/data/ranking_source_dto.dart';
import 'package:sakuramedia/widgets/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/navigation/app_mobile_filter_drawer_scaffold.dart';
import 'package:sakuramedia/widgets/rankings/ranking_filter_sections.dart';

/// 抽屉每次重建时通过这个数据类拿一份最新的 page state 快照（含回调）。
class RankingFilterDrawerArgs {
  const RankingFilterDrawerArgs({
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
}

/// 弹出移动端榜单筛选底部抽屉。
///
/// 与影片/演员 tab 不同，榜单是「即时生效」——chip 改变立刻 reload。
/// 抽屉里改也是即时（回调直接走 page state 的方法），「确定」只是关闭抽屉的语法。
/// [initialAnchor] 用于 chip 点击后定位到对应 section（source/board/period/sort）。
///
/// 抽屉**订阅** [listenable]（通常传 page state），page state 变化（如切 source
/// 后 boards 列表刷新）时通过 [argsBuilder] 拿到最新快照重建内容。
Future<void> showMobileRankingFilterDrawer(
  BuildContext context, {
  required Listenable listenable,
  required RankingFilterDrawerArgs Function() argsBuilder,
  RankingFilterAnchor? initialAnchor,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-rankings-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (sheetContext) => _MobileRankingFilterDrawerContent(
      listenable: listenable,
      argsBuilder: argsBuilder,
      initialAnchor: initialAnchor,
    ),
  );
}

class _MobileRankingFilterDrawerContent extends StatefulWidget {
  const _MobileRankingFilterDrawerContent({
    required this.listenable,
    required this.argsBuilder,
    required this.initialAnchor,
  });

  final Listenable listenable;
  final RankingFilterDrawerArgs Function() argsBuilder;
  final RankingFilterAnchor? initialAnchor;

  @override
  State<_MobileRankingFilterDrawerContent> createState() =>
      _MobileRankingFilterDrawerContentState();
}

class _MobileRankingFilterDrawerContentState
    extends State<_MobileRankingFilterDrawerContent> {
  late final RankingFilterSectionKeys _sectionKeys;

  @override
  void initState() {
    super.initState();
    _sectionKeys = RankingFilterSectionKeys();
    final anchor = widget.initialAnchor;
    if (anchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final keyContext = _sectionKeys.forAnchor(anchor).currentContext;
        if (keyContext != null) {
          Scrollable.ensureVisible(
            keyContext,
            duration: const Duration(milliseconds: 240),
            alignment: 0.05,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppMobileFilterDrawerScaffold(
      title: '筛选',
      // 榜单是即时生效，没有「本地副本可重置」的概念。
      onReset: null,
      onConfirm: () => Navigator.of(context).pop(),
      confirmLabel: '完成',
      child: AnimatedBuilder(
        animation: widget.listenable,
        builder: (context, _) {
          final args = widget.argsBuilder();
          return RankingFilterSectionGroup(
            sources: args.sources,
            selectedSource: args.selectedSource,
            boards: args.boards,
            selectedBoard: args.selectedBoard,
            selectedPeriod: args.selectedPeriod,
            onSourceChanged: args.onSourceChanged,
            onBoardChanged: args.onBoardChanged,
            onPeriodChanged: args.onPeriodChanged,
            selectedSortField: args.selectedSortField,
            selectedSortDirection: args.selectedSortDirection,
            onSortChanged: args.onSortChanged,
            sectionKeys: _sectionKeys,
          );
        },
      ),
    );
  }
}
