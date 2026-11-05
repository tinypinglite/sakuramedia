import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_state.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/storage_usage_card.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_surface.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/watch_trend_card.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/theme.dart';

/// 桌面概览的数据洞察带。
///
/// 观看趋势和存储分布各自持有主题色推导的深色面；这一行比上方主行略浅一档。
/// 宽窗口按 7:5 分栏，窄窗口改为上下排列。内容卡片的 chrome 由
/// [WatchTrendCard.embedded] / [StorageUsageCard.embedded] 关闭。
class DesktopOverviewInsights extends StatelessWidget {
  const DesktopOverviewInsights({
    super.key,
    required this.state,
    required this.onTrendRangeChanged,
    required this.onTrendRetry,
    required this.onInsightsRetry,
  });

  static const double wideMinWidth = 960;

  final OverviewSystemInfoState state;
  final ValueChanged<WatchTrendRange> onTrendRangeChanged;
  final VoidCallback onTrendRetry;
  final VoidCallback onInsightsRetry;

  @override
  Widget build(BuildContext context) {
    final trend = OverviewSurface(
      key: const Key('overview-watch-trend-surface'),
      tone: OverviewSurfaceTone.insight,
      padding: EdgeInsets.all(context.appSpacing.lg),
      child: WatchTrendCard(
        trend: state.watchTrend,
        range: state.watchTrendRange,
        onRangeChanged: onTrendRangeChanged,
        isLoading: state.isLoadingWatchTrend,
        errorMessage: state.watchTrendError,
        onRetry: onTrendRetry,
        embedded: true,
        onDark: true,
      ),
    );
    final storage = OverviewSurface(
      key: const Key('overview-storage-usage-surface'),
      tone: OverviewSurfaceTone.insight,
      padding: EdgeInsets.all(context.appSpacing.lg),
      child: StorageUsageCard(
        libraries: state.insights?.mediaLibraries,
        isLoading: state.isLoadingInsights,
        errorMessage: state.insightsError,
        onRetry: onInsightsRetry,
        embedded: true,
        onDark: true,
      ),
    );

    return KeyedSubtree(
      key: const Key('overview-insights-band'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < wideMinWidth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                trend,
                SizedBox(height: context.appSpacing.lg),
                storage,
              ],
            );
          }

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(flex: 7, child: trend),
                SizedBox(width: context.appSpacing.lg),
                Expanded(flex: 5, child: storage),
              ],
            ),
          );
        },
      ),
    );
  }
}
