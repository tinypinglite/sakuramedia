import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/presentation/actions/movie_collection_feature_actions.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_provider.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_scope.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_summary_state.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_format.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_provider.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_state.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/cloud115_authentication_status_chips.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/interaction/refresh/app_page_refresh_scope.dart';
import 'package:sakuramedia/widgets/domain/movies/movie_summary_grid.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/external_data_source_status_chips.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_stats_strip.dart';
import 'package:sakuramedia/features/system_diagnostics/presentation/widgets/system_diagnostics_strip.dart';

class DesktopOverviewPage extends ConsumerStatefulWidget {
  const DesktopOverviewPage({super.key});

  @override
  ConsumerState<DesktopOverviewPage> createState() =>
      _DesktopOverviewPageState();
}

class _DesktopOverviewPageState extends ConsumerState<DesktopOverviewPage> {
  static const _latestScope = MovieSummaryScope.latest();
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreIfNeeded);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  void _loadMoreIfNeeded() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final summary = ref.read(movieSummaryProvider(_latestScope)).value;
    if (summary == null ||
        summary.paged.loadMoreErrorMessage != null ||
        position.pixels < position.maxScrollExtent - 300) {
      return;
    }
    unawaited(ref.read(movieSummaryProvider(_latestScope).notifier).loadMore());
  }

  Future<void> _refreshOverview() async {
    await Future.wait<void>([
      // 沿用旧行为:桌面刷新走 load()(不置 loading 标志),统计条不闪骨架。
      ref.read(overviewSystemInfoProvider.notifier).load(),
      ref.read(movieSummaryProvider(_latestScope).notifier).refresh(),
    ]);
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await ref
        .read(movieSummaryProvider(_latestScope).notifier)
        .toggleSubscription(movieNumber);
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    final systemInfo = ref.watch(overviewSystemInfoProvider);
    final moviesAsync = ref.watch(movieSummaryProvider(_latestScope));
    final movies = moviesAsync.value;
    final paged = movies?.paged;
    final stats =
        systemInfo.status == null
            ? const <OverviewStatItem>[]
            : <OverviewStatItem>[
              OverviewStatItem(
                id: 'movies-total',
                label: '影片总数',
                value: systemInfo.status!.movies.total.toString(),
              ),
              OverviewStatItem(
                id: 'movies-playable',
                label: '可播放影片',
                value: systemInfo.status!.movies.playable.toString(),
              ),
              OverviewStatItem(
                id: 'actors-female-total',
                label: '女优总数',
                value: systemInfo.status!.actors.femaleTotal.toString(),
              ),
              OverviewStatItem(
                id: 'media-files-total',
                label: '媒体文件',
                value: systemInfo.status!.mediaFiles.total.toString(),
              ),
              OverviewStatItem(
                id: 'media-libraries-total',
                label: '资源库',
                value: systemInfo.status!.mediaLibraries.total.toString(),
              ),
              OverviewStatItem(
                id: 'media-files-size',
                label: '媒体总量',
                value: formatGigabytes(
                  systemInfo.status!.mediaFiles.totalSizeBytes,
                ),
              ),
              OverviewStatItem(
                id: 'thumbnails-total',
                label: '缩略图总数',
                value: systemInfo.status!.thumbnails.total.toString(),
              ),
              OverviewStatItem(
                id: 'thumbnails-pending',
                label: '待生成缩略图',
                value: systemInfo.status!.thumbnails.pendingMedia.toString(),
              ),
              OverviewStatItem(
                id: 'joytag-health',
                label: 'JoyTag 健康',
                value: systemInfo.buildJoyTagHealthValue(),
                isLoading: systemInfo.isLoadingImageSearchStatus,
              ),
              OverviewStatItem(
                id: 'joytag-device',
                label: '推理设备',
                value: systemInfo.buildJoyTagDeviceValue(),
                isLoading: systemInfo.isLoadingImageSearchStatus,
              ),
              OverviewStatItem(
                id: 'joytag-indexing-backlog',
                label: '待索引',
                value: systemInfo.buildJoyTagIndexingValue(),
                isLoading: systemInfo.isLoadingImageSearchStatus,
              ),
              OverviewStatItem(
                id: 'external-data-sources',
                label: '外部数据源',
                valueWidget: ExternalDataSourceStatusChips(
                  javdbHealthy: systemInfo.javdbHealthy,
                  isTesting: systemInfo.isTestingMetadataProviders,
                ),
                maxWidth: 260,
                action: _buildExternalDataSourcesAction(context, systemInfo),
              ),
              OverviewStatItem(
                id: 'cloud115-authentication',
                label: '115 认证状态',
                valueWidget: Cloud115AuthenticationStatusChips(
                  summary: systemInfo.cloud115CookiesStatus?.summary,
                  isTesting: systemInfo.isTestingCloud115Authentication,
                  requestFailed: systemInfo.cloud115AuthenticationRequestFailed,
                ),
                maxWidth: 260,
                action: _buildCloud115AuthenticationAction(context, systemInfo),
              ),
            ];

    return AppPageRefreshScope(
      onRefresh: _refreshOverview,
      child: ColoredBox(
        color: context.appColors.surfaceElevated,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverMainAxisGroup(
              slivers: [
                const SliverToBoxAdapter(
                  child: KeyedSubtree(
                    key: Key('overview-page'),
                    child: SystemDiagnosticsStrip(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: context.appSpacing.md),
                ),
                SliverToBoxAdapter(
                  child: OverviewStatsStrip(
                    items: stats,
                    isLoading: systemInfo.isLoadingStatus,
                    errorMessage: systemInfo.statusError,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: context.appSpacing.xxl),
                ),
                SliverToBoxAdapter(
                  child: Text(
                    '最近添加',
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s18,
                      weight: AppTextWeight.semibold,
                      tone: AppTextTone.primary,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: context.appSpacing.md),
                ),
                SliverMainAxisGroup(
                  slivers: [
                    MovieSummarySliver(
                      items: paged?.items ?? const [],
                      isLoading: moviesAsync.isLoading && movies == null,
                      errorMessage:
                          moviesAsync.hasError && movies == null
                              ? _latestScope.initialLoadErrorText
                              : null,
                      onMovieTap:
                          (movie) => context.pushDesktopMovieDetail(
                            movieNumber: movie.movieNumber,
                            fallbackPath: desktopOverviewPath,
                          ),
                      onMovieMenuRequest:
                          (movie, globalPosition) => requestMovieCollectionMenu(
                            context,
                            movie.movieNumber,
                            globalPosition,
                            isSubscribed: movie.isSubscribed,
                          ),
                      onMovieSubscriptionTap:
                          (movie) =>
                              _toggleMovieSubscription(movie.movieNumber),
                      isMovieSubscriptionUpdating:
                          (movie) =>
                              movies?.isSubscriptionUpdating(
                                movie.movieNumber,
                              ) ??
                              false,
                      emptyMessage: '暂无入库影片，去搜索看看吧',
                    ),
                    if (_buildMovieLoadMoreFooter(context, movies)
                        case final footer?)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(top: context.appSpacing.md),
                          child: footer,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalDataSourcesAction(
    BuildContext context,
    OverviewSystemInfoState systemInfo,
  ) {
    return AppIconButton(
      key: const Key('overview-external-data-sources-test-button'),
      tooltip: '检测外部数据源',
      semanticLabel: '检测外部数据源',
      size: AppIconButtonSize.mini,
      onPressed:
          systemInfo.isTestingMetadataProviders
              ? null
              : ref
                  .read(overviewSystemInfoProvider.notifier)
                  .testExternalDataSources,
      icon:
          systemInfo.isTestingMetadataProviders
              ? SizedBox(
                width: context.appComponentTokens.iconSizeSm,
                height: context.appComponentTokens.iconSizeSm,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth:
                      context.appComponentTokens.movieCardLoaderStrokeWidth,
                ),
              )
              : const Icon(Icons.radar_rounded),
    );
  }

  Widget _buildCloud115AuthenticationAction(
    BuildContext context,
    OverviewSystemInfoState systemInfo,
  ) {
    return AppIconButton(
      key: const Key('overview-cloud115-authentication-test-button'),
      tooltip: '检测 115 认证状态',
      semanticLabel: '检测 115 认证状态',
      size: AppIconButtonSize.mini,
      onPressed:
          systemInfo.isTestingCloud115Authentication
              ? null
              : ref
                  .read(overviewSystemInfoProvider.notifier)
                  .testCloud115Authentication,
      icon:
          systemInfo.isTestingCloud115Authentication
              ? SizedBox(
                width: context.appComponentTokens.iconSizeSm,
                height: context.appComponentTokens.iconSizeSm,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth:
                      context.appComponentTokens.movieCardLoaderStrokeWidth,
                ),
              )
              : const Icon(Icons.radar_rounded),
    );
  }

  Widget? _buildMovieLoadMoreFooter(
    BuildContext context,
    MovieSummaryState? summary,
  ) {
    final paged = summary?.paged;
    if (paged == null || paged.items.isEmpty) {
      return null;
    }

    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    if (paged.isLoadingMore) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.md),
          child: SizedBox(
            width: componentTokens.movieCardLoaderSize,
            height: componentTokens.movieCardLoaderSize,
            child: CircularProgressIndicator(
              strokeWidth: componentTokens.movieCardLoaderStrokeWidth,
            ),
          ),
        ),
      );
    }

    if (paged.loadMoreErrorMessage == null) {
      return null;
    }

    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: context.appRadius.mdBorder,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: componentTokens.iconSizeXl,
                color: context.appTextPalette.secondary,
              ),
              SizedBox(width: spacing.sm),
              Text(
                paged.loadMoreErrorMessage!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(width: spacing.sm),
              TextButton(
                onPressed:
                    () =>
                        ref
                            .read(movieSummaryProvider(_latestScope).notifier)
                            .loadMore(),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.sm,
                    vertical: spacing.xs,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
