import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_format.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_provider.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/asset_summary_card.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/desktop_overview_insights.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_page_header.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_work_queue_card.dart';
import 'package:sakuramedia/features/playlists/data/dto/playlist_dto.dart';
import 'package:sakuramedia/features/playlists/presentation/providers/system_playlist_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/providers/recent_views_provider.dart';
import 'package:sakuramedia/features/recent_views/presentation/widgets/recent_views_section.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_routes.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_inline_error_banner.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/base/navigation/app_section_header.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_rail.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/system_diagnostics_strip.dart';

final _recentlyPlayedPlaylistProvider = systemPlaylistProvider(
  PlaylistKind.recentlyPlayed,
);

/// 宽桌面时工作台跟媒体资产保持同一视觉高度；窄窗口不强制高度。
const double _wideTopRowMinHeight = 220;

/// 两张主卡并肩排布所需的内容宽度；更窄时上下排列，避免中等宽度下挤成
/// 两套高度不一致的窄布局。
const double _wideTopRowMinWidth = 1000;

class DesktopOverviewPage extends ConsumerStatefulWidget {
  const DesktopOverviewPage({super.key});

  @override
  ConsumerState<DesktopOverviewPage> createState() =>
      _DesktopOverviewPageState();
}

class _DesktopOverviewPageState extends ConsumerState<DesktopOverviewPage> {
  static const _latestScope = MovieSummaryScope.latest();
  static const _recentlySubscribedScope =
      MovieSummaryScope.recentlySubscribed();

  /// 预览分区的占位项数量（「最近添加」「最近订阅」「最近播放」各一行横向
  /// rail，更多内容进各自页面）。
  static const int _previewItemCount = 12;

  bool _refreshFailed = false;

  Future<void> _refreshOverview(BuildContext context) async {
    final recentPlaylist = ref.read(_recentlyPlayedPlaylistProvider).value;
    final futures = <Future<void>>[
      // 沿用旧行为:桌面刷新走 load()(不置 loading 标志),卡片不闪骨架。
      ref.read(overviewSystemInfoProvider.notifier).load(),
      ref.read(movieSummaryProvider(_latestScope).notifier).refresh(),
      ref
          .read(movieSummaryProvider(_recentlySubscribedScope).notifier)
          .refresh(),
    ];
    if (recentPlaylist != null) {
      futures.add(
        ref
            .read(
              movieSummaryProvider(
                MovieSummaryScope.playlist(playlistId: recentPlaylist.id),
              ).notifier,
            )
            .refresh(),
      );
    }
    ref.invalidate(_recentlyPlayedPlaylistProvider);
    ref.invalidate(recentViewsProvider);
    try {
      await Future.wait<void>([
        ...futures,
        // invalidate 的两个 provider 也要等重建完成：否则刷新指示器先于
        // 「最近播放」「最近浏览」重载结束，rail 里还是旧快照。
        ref.read(_recentlyPlayedPlaylistProvider.future).then<void>((_) {}),
        ref.read(recentViewsProvider.future).then<void>((_) {}),
      ]);
      if (mounted && _refreshFailed) {
        setState(() => _refreshFailed = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _refreshFailed = true);
      }
    }
  }

  Future<void> _toggleMovieSubscription(
    BuildContext context,
    WidgetRef ref,
    MovieSummaryScope scope,
    String movieNumber,
  ) async {
    final result = await ref
        .read(movieSummaryProvider(scope).notifier)
        .toggleSubscription(movieNumber);
    if (!context.mounted) return;
    showMovieSubscriptionFeedback(result, l10n: AppLocalizations.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final systemInfo = ref.watch(overviewSystemInfoProvider);
    final systemInfoNotifier = ref.read(overviewSystemInfoProvider.notifier);
    final latestAsync = ref.watch(movieSummaryProvider(_latestScope));
    final latest = latestAsync.value;
    final recentlySubscribedAsync = ref.watch(
      movieSummaryProvider(_recentlySubscribedScope),
    );
    final recentPlaylist = ref.watch(_recentlyPlayedPlaylistProvider).value;
    final recentScope = recentPlaylist == null
        ? null
        : MovieSummaryScope.playlist(playlistId: recentPlaylist.id);
    final recentAsync = recentScope == null
        ? null
        : ref.watch(movieSummaryProvider(recentScope));
    final downloadTasks =
        systemInfo.insights?.downloadTasks ??
        const StatusDownloadTaskSummaryDto();

    return AppPageRefreshScope(
      onRefresh: () => _refreshOverview(context),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: const Key('overview-page'),
              child: OverviewPageHeader(
                isConnected:
                    systemInfo.status != null && systemInfo.statusError == null,
                onImportTap: () =>
                    context.goPrimary(AppRouteId.desktopMediaImport),
              ),
            ),
          ),
          if (_refreshFailed) ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: context.appSpacing.md),
                child: AppInlineErrorBanner(
                  key: const Key('overview-refresh-error'),
                  message: l10n.overviewRefreshFailed,
                  retryKey: const Key('overview-refresh-retry'),
                  onRetry: () => _refreshOverview(context),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.lg)),
          SliverToBoxAdapter(
            child: _buildTopRow(
              context,
              status: systemInfo.status,
              pendingIndexCount: pendingIndexCount(
                systemInfo.imageSearchStatus,
              ),
              isLoadingStatus: systemInfo.isLoadingStatus,
              statusError: systemInfo.statusError,
              onStatusRetry: systemInfoNotifier.loadStatus,
              isWorkbenchLoading:
                  systemInfo.isLoadingInsights && systemInfo.insights == null,
              insightsError: systemInfo.insightsError,
              onInsightsRetry: systemInfoNotifier.loadInsights,
              downloading: downloadTasks.downloading,
              importing: downloadTasks.importing,
              imported: downloadTasks.imported,
              onAllTasksTap: () =>
                  context.goPrimary(AppRouteId.desktopDownloadTasks),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.xl)),
          SliverToBoxAdapter(
            child: DesktopOverviewInsights(
              state: systemInfo,
              onTrendRangeChanged: systemInfoNotifier.setWatchTrendRange,
              onTrendRetry: systemInfoNotifier.loadWatchTrend,
              onInsightsRetry: systemInfoNotifier.loadInsights,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.xl)),
          SliverToBoxAdapter(
            child: AppSectionHeader(
              title: l10n.overviewRecentlyAdded,
              actionLabel: l10n.overviewMore,
              actionKey: const Key('overview-latest-more'),
              onActionTap: () => DesktopRoutes.latestMovies().push(context),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.md)),
          SliverToBoxAdapter(
            child: _buildMovieRail(
              context,
              ref: ref,
              scope: _latestScope,
              summary: latest,
              isLoading: latestAsync.isLoading && latest == null,
              errorMessage: latestAsync.hasError && latest == null
                  ? _latestScope.errorText(l10n)
                  : null,
              emptyMessage: l10n.overviewNoLatestMovies,
            ),
          ),
          if (recentPlaylist != null && recentScope != null) ...<Widget>[
            SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.xl)),
            SliverToBoxAdapter(
              child: AppSectionHeader(
                title: l10n.overviewRecentlyPlayed,
                trailingText: l10n.overviewMovieCount(
                  formatCount(recentPlaylist.movieCount),
                ),
                actionLabel: l10n.overviewMore,
                actionKey: const Key('overview-recent-played-more'),
                onActionTap: () => DesktopRoutes.playlistDetail(
                  playlistId: recentPlaylist.id,
                  fallbackPath: desktopOverviewPath,
                ).push(context),
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.md)),
            SliverToBoxAdapter(
              child: _buildMovieRail(
                context,
                ref: ref,
                scope: recentScope,
                summary: recentAsync?.value,
                isLoading:
                    (recentAsync?.isLoading ?? false) &&
                    recentAsync?.value == null,
                errorMessage:
                    (recentAsync?.hasError ?? false) &&
                        recentAsync?.value == null
                    ? recentScope.errorText(l10n)
                    : null,
                emptyMessage: l10n.overviewNoWatchHistory,
              ),
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.xl)),
          SliverToBoxAdapter(
            child: AppSectionHeader(
              title: l10n.overviewRecentlySubscribed,
              actionLabel: l10n.overviewMore,
              actionKey: const Key('overview-recently-subscribed-more'),
              onActionTap: () =>
                  DesktopRoutes.recentlySubscribedMovies().push(context),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: context.appSpacing.md)),
          SliverToBoxAdapter(
            child: _buildMovieRail(
              context,
              ref: ref,
              scope: _recentlySubscribedScope,
              summary: recentlySubscribedAsync.value,
              isLoading:
                  recentlySubscribedAsync.isLoading &&
                  recentlySubscribedAsync.value == null,
              errorMessage:
                  recentlySubscribedAsync.hasError &&
                      recentlySubscribedAsync.value == null
                  ? _recentlySubscribedScope.errorText(l10n)
                  : null,
              emptyMessage: l10n.overviewNoSubscribedMovies,
            ),
          ),
          SliverToBoxAdapter(
            child: RecentViewsSection(
              spacingBefore: context.appSpacing.xl,
              actionKey: const Key('overview-recent-views-more'),
              onMoreTap: () => DesktopRoutes.recentViews().push(context),
              onMovieTap: (movieNumber) => DesktopRoutes.movieDetail(
                movieNumber: movieNumber,
                fallbackPath: desktopOverviewPath,
              ).push(context),
              onActorTap: (actorId) => DesktopRoutes.actorDetail(
                actorId: actorId,
                fallbackPath: desktopOverviewPath,
              ).push(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow(
    BuildContext context, {
    required StatusDto? status,
    required int pendingIndexCount,
    required bool isLoadingStatus,
    required String? statusError,
    required VoidCallback onStatusRetry,
    required bool isWorkbenchLoading,
    required String? insightsError,
    required VoidCallback onInsightsRetry,
    required int downloading,
    required int importing,
    required int imported,
    required VoidCallback onAllTasksTap,
  }) {
    final asset = AssetSummaryCard(
      status: status,
      pendingIndexCount: pendingIndexCount,
      isLoading: isLoadingStatus,
      errorMessage: statusError,
      onRetry: onStatusRetry,
    );
    Widget buildWorkbench({double? minHeight}) => OverviewWorkQueueCard(
      downloading: downloading,
      importing: importing,
      imported: imported,
      pendingIndexCount: pendingIndexCount,
      diagnostics: const SystemDiagnosticsStrip(),
      onAllTasksTap: onAllTasksTap,
      isLoading: isWorkbenchLoading,
      errorMessage: insightsError,
      onRetry: onInsightsRetry,
      minHeight: minHeight,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _wideTopRowMinWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              asset,
              SizedBox(height: context.appSpacing.lg),
              buildWorkbench(),
            ],
          );
        }
        final gap = context.appSpacing.lg;
        final availableWidth = constraints.maxWidth - gap;
        final assetWidth = availableWidth * 7 / 12;
        // 首列按实际内容决定行高，工作台用 fill 拉到同高；固定列宽避开
        // 资产卡内部 LayoutBuilder 不支持 intrinsic 计算的限制。
        return Table(
          columnWidths: <int, TableColumnWidth>{
            0: FixedColumnWidth(assetWidth),
            1: FixedColumnWidth(gap),
            2: FixedColumnWidth(availableWidth - assetWidth),
          },
          children: <TableRow>[
            TableRow(
              children: <Widget>[
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: _wideTopRowMinHeight,
                    ),
                    child: asset,
                  ),
                ),
                const TableCell(
                  verticalAlignment: TableCellVerticalAlignment.top,
                  child: SizedBox.shrink(),
                ),
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.fill,
                  child: buildWorkbench(minHeight: _wideTopRowMinHeight),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMovieRail(
    BuildContext context, {
    required WidgetRef ref,
    required MovieSummaryScope scope,
    required MovieSummaryState? summary,
    required bool isLoading,
    required String? errorMessage,
    required String emptyMessage,
  }) {
    return AppSkeletonizer(
      enabled: isLoading,
      child: MovieSummaryRail(
        items: isLoading
            ? movieListItemPlaceholders(count: _previewItemCount)
            : summary?.paged.items.take(_previewItemCount).toList() ?? const [],
        errorMessage: errorMessage,
        onMovieTap: (movie) => DesktopRoutes.movieDetail(
          movieNumber: movie.movieNumber,
          fallbackPath: desktopOverviewPath,
        ).push(context),
        onMovieMenuRequest: (movie, globalPosition) =>
            requestMovieCollectionMenu(
              context,
              movie.movieNumber,
              globalPosition,
              isSubscribed: movie.isSubscribed,
            ),
        onMovieSubscriptionTap: (movie) =>
            _toggleMovieSubscription(context, ref, scope, movie.movieNumber),
        isMovieSubscriptionUpdating: (movie) =>
            summary?.isSubscriptionUpdating(movie.movieNumber) ?? false,
        emptyMessage: emptyMessage,
      ),
    );
  }
}
