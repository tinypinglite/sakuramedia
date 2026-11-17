import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status.dart';
import 'package:sakuramedia/features/subscriptions/data/dto/movie_subscription_status_counts_dto.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_manager_provider.dart';
import 'package:sakuramedia/features/subscriptions/presentation/providers/movie_subscription_status_counts_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/navigation/app_tab_bar.dart';

/// 状态分段签的顺序：**按可操作性排**，不按后端 CASE 优先级。
///
/// 订阅只增不减，`imported` 常年占九成以上——把「全部」和「已入库」摆在最左，等于
/// 让用户每次都先滑过两个用不上的签。用户来这一页是因为「我订的片怎么还没下
/// 来」，所以待办四态（缺资源 / 已放弃 / 导入失败 / 查询出错）打头，归档态收尾。
const List<MovieSubscriptionStatus?> kMovieSubscriptionStatusTabs =
    <MovieSubscriptionStatus?>[
      MovieSubscriptionStatus.missing,
      MovieSubscriptionStatus.exhausted,
      MovieSubscriptionStatus.importFailed,
      MovieSubscriptionStatus.failed,
      MovieSubscriptionStatus.pending,
      MovieSubscriptionStatus.downloading,
      MovieSubscriptionStatus.imported,
      // null = 全部，不下发 status 参数。
      null,
    ];

/// 需要人工介入才会有进展的状态——计数用警示色，把注意力从默认签上拉过去。
///
/// 「缺资源」不在此列：它下一轮还会自动继续查，用户不做任何事也可能自己好。
/// 「未入库」在此列且永远不会自愈——文件已在盘上、后端也不会再给它查资源。
bool _needsAttention(MovieSubscriptionStatus? status) =>
    status == MovieSubscriptionStatus.exhausted ||
    status == MovieSubscriptionStatus.importFailed ||
    status == MovieSubscriptionStatus.failed;

String _labelOf(AppLocalizations l10n, MovieSubscriptionStatus? status) {
  if (status == MovieSubscriptionStatus.importFailed) {
    return l10n.subscriptionStatusNotImported;
  }
  return status?.label(l10n) ?? l10n.subscriptionStatusAll;
}

/// 订阅管理页顶部的状态分段签，标签自带计数角标。
///
/// 计数来自独立的 [movieSubscriptionStatusCountsProvider]——它挂了就退化成没有数字
/// 的纯文字签，列表照常可用。
class MovieSubscriptionStatusTabs extends HookConsumerWidget {
  const MovieSubscriptionStatusTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStatus = ref.watch(movieSubscriptionStatusSelectionProvider);
    final counts =
        ref.watch(movieSubscriptionStatusCountsProvider).value ??
        MovieSubscriptionStatusCountsDto.empty;

    final activeIndex = kMovieSubscriptionStatusTabs.indexOf(activeStatus);
    final selectedIndex = activeIndex >= 0 ? activeIndex : 0;
    final tabTickerProvider = useSingleTickerProvider();
    final tabController = useMemoized(
      () => TabController(
        length: kMovieSubscriptionStatusTabs.length,
        initialIndex: selectedIndex,
        vsync: tabTickerProvider,
      ),
      [tabTickerProvider],
    );
    useEffect(() => tabController.dispose, [tabController]);

    // 分段签是状态的唯一入口，但筛选状态归 provider——别的路径改了 status（深链、
    // 未来的「去看已放弃」引导按钮）时把指示器拨过去。
    useEffect(() {
      if (tabController.index != selectedIndex) {
        tabController.index = selectedIndex;
      }
      return null;
    }, <Object?>[tabController, selectedIndex]);

    return AppTabBar(
      key: const Key('movie-subscriptions-status-tabs'),
      controller: tabController,
      onTap: (index) {
        final status = kMovieSubscriptionStatusTabs[index];
        ref
            .read(movieSubscriptionStatusSelectionProvider.notifier)
            .select(status);
      },
      tabs: <Widget>[
        for (final status in kMovieSubscriptionStatusTabs)
          _StatusTab(status: status, count: counts.countOf(status)),
      ],
    );
  }
}

/// 单个签：`标签 计数`。
///
/// 标签本身不指定颜色，交给 `TabBar` 的 selected / unselected 样式自然过渡；只给
/// **计数**上色，且只在「需要人工介入且确实有货」时才上警示色——小面积、有语义，
/// 不引入第二个强调色。
class _StatusTab extends StatelessWidget {
  const _StatusTab({required this.status, required this.count});

  final MovieSubscriptionStatus? status;
  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = _labelOf(l10n, status);
    final highlight = count > 0 && _needsAttention(status);
    return Tab(
      key: Key('movie-subscriptions-status-tab-${status?.apiValue ?? 'all'}'),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(text: label),
            TextSpan(
              text: '  $count',
              style: TextStyle(
                color: highlight
                    ? context.appTextPalette.warning
                    : context.appTextPalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
