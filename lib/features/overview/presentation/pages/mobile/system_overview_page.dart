import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oktoast/oktoast.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_format.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_provider.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/asset_summary_card.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/service_health_card.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/storage_usage_card.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_surface.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/watch_trend_card.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/feedback/app_confirm_dialog.dart';

class MobileSystemOverviewPage extends ConsumerWidget {
  const MobileSystemOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(overviewSystemInfoProvider);
    final notifier = ref.read(overviewSystemInfoProvider.notifier);
    return KeyedSubtree(
      key: const Key('mobile-system-overview-page'),
      child: AppAdaptiveRefreshScrollView(
        onRefresh: notifier.refresh,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AssetSummaryCard(
                  status: state.status,
                  insights: state.insights,
                  pendingIndexCount: pendingIndexCount(state.imageSearchStatus),
                  isLoading: state.isLoadingStatus,
                  errorMessage: state.statusError,
                  onRetry: notifier.loadStatus,
                ),
                SizedBox(height: context.appSpacing.lg),
                OverviewSurface(
                  key: const Key('mobile-overview-watch-trend-surface'),
                  tone: OverviewSurfaceTone.insight,
                  padding: EdgeInsets.all(context.appSpacing.lg),
                  child: WatchTrendCard(
                    trend: state.watchTrend,
                    range: state.watchTrendRange,
                    onRangeChanged: notifier.setWatchTrendRange,
                    compactSelector: true,
                    isLoading: state.isLoadingWatchTrend,
                    errorMessage: state.watchTrendError,
                    onRetry: notifier.loadWatchTrend,
                    embedded: true,
                    onDark: true,
                  ),
                ),
                SizedBox(height: context.appSpacing.lg),
                OverviewSurface(
                  key: const Key('mobile-overview-storage-usage-surface'),
                  tone: OverviewSurfaceTone.insight,
                  padding: EdgeInsets.all(context.appSpacing.lg),
                  child: StorageUsageCard(
                    libraries: state.insights?.mediaLibraries,
                    isLoading: state.isLoadingInsights,
                    errorMessage: state.insightsError,
                    onRetry: notifier.loadInsights,
                    embedded: true,
                    onDark: true,
                  ),
                ),
                SizedBox(height: context.appSpacing.lg),
                ServiceHealthCard(
                  imageSearchStatus: state.imageSearchStatus,
                  javdbHealthy: state.javdbHealthy,
                  isLoading: state.isLoadingImageSearchStatus,
                  isTestingExternalDataSources:
                      state.isTestingMetadataProviders,
                  isRebuildingIndex: state.isResettingImageSearch,
                  onTestExternalDataSources: notifier.testExternalDataSources,
                  onRebuildIndex: () => _confirmImageSearchReset(
                    context,
                    notifier,
                    state.imageSearchStatus?.indexSpace.indexedSpaceId,
                    state.imageSearchStatus?.indexSpace.currentSpaceId,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmImageSearchReset(
    BuildContext context,
    OverviewSystemInfo notifier,
    String? indexedSpaceId,
    String? currentSpaceId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final spaceMessage = indexedSpaceId == null
        ? l10n.overviewImageSearchSpaceUnknown
        : l10n.overviewImageSearchSpaceChanged(
            indexedSpaceId,
            currentSpaceId ?? l10n.commonUnknown,
          );
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.systemMaintenanceRebuildDialogTitle,
      message: l10n.overviewRebuildIndexConfirm(spaceMessage),
      confirmLabel: l10n.systemMaintenanceRebuildIndex,
      danger: true,
      dialogKey: const Key('mobile-image-search-reset-confirm-dialog'),
      confirmKey: const Key('mobile-image-search-reset-confirm'),
      cancelKey: const Key('mobile-image-search-reset-cancel'),
      onConfirm: notifier.resetImageSearch,
      failureFallback: l10n.systemMaintenanceRebuildFailed,
    );
    if (confirmed && context.mounted) {
      showToast(l10n.systemMaintenanceRebuildStarted);
    }
  }
}
