import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_provider.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_scope.dart';
import 'package:sakuramedia/features/rankings/presentation/providers/ranking_summary_state.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/ranking_filter_sections.dart';
import 'package:sakuramedia/features/rankings/presentation/widgets/rankings_filter_panel.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/base/navigation/app_mobile_filter_drawer_scaffold.dart';

/// 弹出移动端榜单筛选底部抽屉。
///
/// chip 选中态即时更新；榜单结果由 Provider 统一防抖刷新。
/// 抽屉没有“确定”按钮，关闭仅靠下拉或点遮罩。
/// [initialAnchor] 用于 chip 点击后定位到对应 section（source/board/period）。
///
Future<void> showMobileRankingFilterDrawer(
  BuildContext context, {
  required RankingSummaryScope scope,
  required RankingsFilterActions actions,
  RankingFilterAnchor? initialAnchor,
}) {
  return showAppBottomDrawer<void>(
    context: context,
    drawerKey: const Key('mobile-rankings-filter-drawer'),
    maxHeightFactor: 0.6,
    builder: (sheetContext) => _MobileRankingFilterDrawerContent(
      scope: scope,
      actions: actions,
      initialAnchor: initialAnchor,
    ),
  );
}

class _MobileRankingFilterDrawerContent extends ConsumerStatefulWidget {
  const _MobileRankingFilterDrawerContent({
    required this.scope,
    required this.actions,
    required this.initialAnchor,
  });

  final RankingSummaryScope scope;
  final RankingsFilterActions actions;
  final RankingFilterAnchor? initialAnchor;

  @override
  ConsumerState<_MobileRankingFilterDrawerContent> createState() =>
      _MobileRankingFilterDrawerContentState();
}

class _MobileRankingFilterDrawerContentState
    extends ConsumerState<_MobileRankingFilterDrawerContent> {
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
    final filters =
        ref.watch(rankingSummaryProvider(widget.scope)).value?.filters ??
        RankingFilterState.initial;
    return AppMobileFilterDrawerScaffold(
      // 榜单没有「恢复默认」语义（来源/榜单必须二选一），故不带 footer。
      scrollViewKey: const Key('mobile-rankings-filter-scroll-view'),
      child: RankingsFilterPanel(
        filters: filters,
        actions: widget.actions,
        sectionKeys: _sectionKeys,
      ),
    );
  }
}
