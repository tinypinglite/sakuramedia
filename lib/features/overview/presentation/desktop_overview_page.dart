import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_controller.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/subscriptions/presentation/subscription_feedback.dart';
import 'package:sakuramedia/routes/app_navigation_actions.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/movies/movie_summary_grid.dart';
import 'package:sakuramedia/widgets/overview/overview_stats_strip.dart';

class DesktopOverviewPage extends StatefulWidget {
  const DesktopOverviewPage({super.key});

  @override
  State<DesktopOverviewPage> createState() => _DesktopOverviewPageState();
}

class _DesktopOverviewPageState extends State<DesktopOverviewPage> {
  late final OverviewSystemInfoController _systemInfoController;
  late final PagedMovieSummaryController _moviesController;
  late final MovieSubscriptionChangeNotifier _subscriptionChangeNotifier;

  @override
  void initState() {
    super.initState();
    _systemInfoController = OverviewSystemInfoController(
      statusApi: context.read<StatusApi>(),
      metadataProviderLicenseApi: context.read<MetadataProviderLicenseApi>(),
    )..addListener(_onSystemInfoChanged);
    _subscriptionChangeNotifier =
        context.read<MovieSubscriptionChangeNotifier>();
    _subscriptionChangeNotifier.addListener(_onMovieSubscriptionChanged);
    _moviesController = PagedMovieSummaryController(
      fetchPage:
          (page, pageSize) => context.read<MoviesApi>().getLatestMovies(
            page: page,
            pageSize: pageSize,
          ),
      subscribeMovie: context.read<MoviesApi>().subscribeMovie,
      unsubscribeMovie: context.read<MoviesApi>().unsubscribeMovie,
      onSubscriptionChanged: _reportSubscriptionChange,
      pageSize: 24,
      loadMoreTriggerOffset: 300,
    );
    _moviesController.attachScrollListener();
    _loadOverview();
  }

  @override
  void dispose() {
    _systemInfoController.removeListener(_onSystemInfoChanged);
    _systemInfoController.dispose();
    _subscriptionChangeNotifier.removeListener(_onMovieSubscriptionChanged);
    _moviesController.dispose();
    super.dispose();
  }

  void _onSystemInfoChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onMovieSubscriptionChanged() {
    final change = _subscriptionChangeNotifier.lastChange;
    if (change == null) {
      return;
    }
    _moviesController.applySubscriptionChange(
      movieNumber: change.movieNumber,
      isSubscribed: change.isSubscribed,
    );
  }

  void _reportSubscriptionChange({
    required String movieNumber,
    required bool isSubscribed,
  }) {
    _subscriptionChangeNotifier.reportChange(
      movieNumber: movieNumber,
      isSubscribed: isSubscribed,
    );
  }

  Future<void> _loadOverview() async {
    final systemInfoFuture = _systemInfoController.load();
    final moviesFuture = _moviesController.initialize();
    await Future.wait<void>([systemInfoFuture, moviesFuture]);
  }

  Future<void> _toggleMovieSubscription(String movieNumber) async {
    final result = await _moviesController.toggleSubscription(
      movieNumber: movieNumber,
    );
    if (!mounted) {
      return;
    }
    showMovieSubscriptionFeedback(result);
  }

  @override
  Widget build(BuildContext context) {
    final systemInfo = _systemInfoController;
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
                value: systemInfo.formatGigabytes(
                  systemInfo.status!.mediaFiles.totalSizeBytes,
                ),
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
                id: 'metadata-provider-license',
                label: '数据源授权',
                value: systemInfo.buildLicenseStatusValue(),
                isLoading: systemInfo.isLoadingLicenseStatus,
                valueTextSize: AppTextSize.s12,
              ),
              OverviewStatItem(
                id: 'license-center-connectivity',
                label: '授权中心',
                value: systemInfo.buildLicenseConnectivityValue(),
                valueTextSize: AppTextSize.s12,
                action: _buildLicenseConnectivityAction(context),
              ),
              OverviewStatItem(
                id: 'external-data-sources',
                label: '外部数据源',
                value: systemInfo.buildExternalDataSourcesValue(),
                valueTextSize: AppTextSize.s12,
                maxWidth: 260,
                action: _buildExternalDataSourcesAction(context),
              ),
            ];

    return ColoredBox(
      color: context.appColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _moviesController.scrollController,
        child: Column(
          key: const Key('overview-page'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OverviewStatsStrip(
              items: stats,
              isLoading: systemInfo.isLoadingStatus,
              errorMessage: systemInfo.statusError,
            ),
            SizedBox(height: context.appSpacing.xxl),
            Text(
              '最近添加',
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s18,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
            SizedBox(height: context.appSpacing.md),
            AnimatedBuilder(
              animation: _moviesController,
              builder: (context, _) {
                final footer = _buildMovieLoadMoreFooter(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MovieSummaryGrid(
                      items: _moviesController.items,
                      isLoading: _moviesController.isInitialLoading,
                      errorMessage: _moviesController.initialErrorMessage,
                      onMovieTap:
                          (movie) => context.pushDesktopMovieDetail(
                            movieNumber: movie.movieNumber,
                            fallbackPath: desktopOverviewPath,
                          ),
                      onMovieSubscriptionTap:
                          (movie) =>
                              _toggleMovieSubscription(movie.movieNumber),
                      isMovieSubscriptionUpdating:
                          (movie) => _moviesController.isSubscriptionUpdating(
                            movie.movieNumber,
                          ),
                      emptyMessage: '暂无最新入库影片',
                    ),
                    if (footer != null) ...[
                      SizedBox(height: context.appSpacing.md),
                      footer,
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalDataSourcesAction(BuildContext context) {
    return AppIconButton(
      key: const Key('overview-external-data-sources-test-button'),
      tooltip: '检测外部数据源',
      semanticLabel: '检测外部数据源',
      size: AppIconButtonSize.mini,
      onPressed:
          _systemInfoController.isTestingMetadataProviders
              ? null
              : _systemInfoController.testExternalDataSources,
      icon:
          _systemInfoController.isTestingMetadataProviders
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

  Widget _buildLicenseConnectivityAction(BuildContext context) {
    return AppIconButton(
      key: const Key('overview-license-center-test-button'),
      tooltip: '测试授权中心连接',
      semanticLabel: '测试授权中心连接',
      size: AppIconButtonSize.mini,
      onPressed:
          _systemInfoController.isTestingLicenseConnectivity
              ? null
              : _systemInfoController.testLicenseConnectivity,
      icon:
          _systemInfoController.isTestingLicenseConnectivity
              ? SizedBox(
                width: context.appComponentTokens.iconSizeSm,
                height: context.appComponentTokens.iconSizeSm,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth:
                      context.appComponentTokens.movieCardLoaderStrokeWidth,
                ),
              )
              : const Icon(Icons.cloud_sync_outlined),
    );
  }

  Widget? _buildMovieLoadMoreFooter(BuildContext context) {
    if (_moviesController.items.isEmpty) {
      return null;
    }

    final spacing = context.appSpacing;
    final colors = context.appColors;
    final componentTokens = context.appComponentTokens;

    if (_moviesController.isLoadingMore) {
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

    if (_moviesController.loadMoreErrorMessage == null) {
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
                _moviesController.loadMoreErrorMessage!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(width: spacing.sm),
              TextButton(
                onPressed: _moviesController.loadMore,
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
