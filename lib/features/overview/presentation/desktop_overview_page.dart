import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_dto.dart';
import 'package:sakuramedia/features/movies/data/movies_api.dart';
import 'package:sakuramedia/features/movies/presentation/movie_subscription_change_notifier.dart';
import 'package:sakuramedia/features/movies/presentation/paged_movie_summary_controller.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
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
  bool _isLoadingStatus = true;
  bool _isLoadingImageSearchStatus = true;
  bool _isLoadingLicenseStatus = true;
  bool _isTestingMetadataProviders = false;
  bool _isTestingLicenseConnectivity = false;
  StatusDto? _status;
  StatusImageSearchDto? _imageSearchStatus;
  MetadataProviderLicenseStatusDto? _licenseStatus;
  MetadataProviderLicenseConnectivityTestDto? _licenseConnectivityTest;
  String? _licenseStatusError;
  bool? _javdbHealthy;
  bool? _dmmHealthy;
  String? _statusError;
  late final PagedMovieSummaryController _moviesController;
  late final MovieSubscriptionChangeNotifier _subscriptionChangeNotifier;

  @override
  void initState() {
    super.initState();
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
    _subscriptionChangeNotifier.removeListener(_onMovieSubscriptionChanged);
    _moviesController.dispose();
    super.dispose();
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
    final statusFuture = _loadStatus();
    final imageSearchStatusFuture = _loadImageSearchStatus();
    final licenseStatusFuture = _loadLicenseStatus();
    final moviesFuture = _moviesController.initialize();
    await Future.wait<void>([
      statusFuture,
      imageSearchStatusFuture,
      licenseStatusFuture,
      moviesFuture,
    ]);
  }

  Future<void> _loadStatus() async {
    try {
      final status = await context.read<StatusApi>().getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _statusError = null;
        _isLoadingStatus = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusError = '系统信息加载失败，请稍后重试';
        _isLoadingStatus = false;
      });
    }
  }

  Future<void> _loadImageSearchStatus() async {
    try {
      final imageSearchStatus =
          await context.read<StatusApi>().getImageSearchStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _imageSearchStatus = imageSearchStatus;
        _isLoadingImageSearchStatus = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _imageSearchStatus = null;
        _isLoadingImageSearchStatus = false;
      });
    }
  }

  Future<void> _loadLicenseStatus() async {
    try {
      final licenseStatus =
          await context.read<MetadataProviderLicenseApi>().getStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _licenseStatus = licenseStatus;
        _licenseStatusError = null;
        _isLoadingLicenseStatus = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _licenseStatus = null;
        _licenseStatusError = 'unavailable';
        _isLoadingLicenseStatus = false;
      });
    }
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

  Future<void> _testExternalDataSources() async {
    if (_isTestingMetadataProviders) {
      return;
    }

    final statusApi = context.read<StatusApi>();
    setState(() {
      _isTestingMetadataProviders = true;
    });

    final results = await Future.wait<bool>([
      _testMetadataProvider(statusApi, 'javdb'),
      _testMetadataProvider(statusApi, 'dmm'),
    ]);

    if (!mounted) {
      return;
    }
    setState(() {
      _javdbHealthy = results[0];
      _dmmHealthy = results[1];
      _isTestingMetadataProviders = false;
    });
  }

  Future<void> _testLicenseConnectivity() async {
    if (_isTestingLicenseConnectivity) {
      return;
    }

    setState(() {
      _isTestingLicenseConnectivity = true;
    });

    try {
      final result =
          await context.read<MetadataProviderLicenseApi>().testConnectivity();
      if (!mounted) {
        return;
      }
      setState(() {
        _licenseConnectivityTest = result;
        _isTestingLicenseConnectivity = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _licenseConnectivityTest =
            const MetadataProviderLicenseConnectivityTestDto(
              ok: false,
              url: '',
              proxyEnabled: false,
              elapsedMs: 0,
              error: 'unavailable',
            );
        _isTestingLicenseConnectivity = false;
      });
    }
  }

  Future<bool> _testMetadataProvider(
    StatusApi statusApi,
    String provider,
  ) async {
    try {
      final result = await statusApi.testMetadataProvider(provider);
      return result.healthy;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats =
        _status == null
            ? const <OverviewStatItem>[]
            : <OverviewStatItem>[
              OverviewStatItem(
                id: 'movies-total',
                label: '影片总数',
                value: _status!.movies.total.toString(),
              ),
              OverviewStatItem(
                id: 'movies-playable',
                label: '可播放影片',
                value: _status!.movies.playable.toString(),
              ),
              OverviewStatItem(
                id: 'actors-female-total',
                label: '女优总数',
                value: _status!.actors.femaleTotal.toString(),
              ),
              OverviewStatItem(
                id: 'media-files-total',
                label: '媒体文件',
                value: _status!.mediaFiles.total.toString(),
              ),
              OverviewStatItem(
                id: 'media-libraries-total',
                label: '资源库',
                value: _status!.mediaLibraries.total.toString(),
              ),
              OverviewStatItem(
                id: 'media-files-size',
                label: '媒体总量',
                value: _formatGigabytes(_status!.mediaFiles.totalSizeBytes),
              ),
              OverviewStatItem(
                id: 'joytag-health',
                label: 'JoyTag 健康',
                value: _buildJoyTagHealthValue(),
                isLoading: _isLoadingImageSearchStatus,
              ),
              OverviewStatItem(
                id: 'joytag-device',
                label: '推理设备',
                value: _buildJoyTagDeviceValue(),
                isLoading: _isLoadingImageSearchStatus,
              ),
              OverviewStatItem(
                id: 'joytag-indexing-backlog',
                label: '待索引',
                value: _buildJoyTagIndexingValue(),
                isLoading: _isLoadingImageSearchStatus,
              ),
              OverviewStatItem(
                id: 'metadata-provider-license',
                label: '数据源授权',
                value: _buildLicenseStatusValue(),
                isLoading: _isLoadingLicenseStatus,
                valueTextSize: AppTextSize.s12,
              ),
              OverviewStatItem(
                id: 'license-center-connectivity',
                label: '授权中心',
                value: _buildLicenseConnectivityValue(),
                valueTextSize: AppTextSize.s12,
                action: _buildLicenseConnectivityAction(context),
              ),
              OverviewStatItem(
                id: 'external-data-sources',
                label: '外部数据源',
                value: _buildExternalDataSourcesValue(),
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
              isLoading: _isLoadingStatus,
              errorMessage: _statusError,
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

  String _formatGigabytes(int bytes) {
    const bytesPerGigabyte = 1024 * 1024 * 1024;
    final value = bytes <= 0 ? 0.0 : bytes / bytesPerGigabyte;
    return '${value.toStringAsFixed(1)} GB';
  }

  String _buildJoyTagHealthValue() {
    if (_imageSearchStatus == null) {
      return '不可用';
    }
    return _imageSearchStatus!.joyTag.healthy ? '正常' : '异常';
  }

  String _buildJoyTagDeviceValue() {
    final device = _imageSearchStatus?.joyTag.usedDevice;
    if (device == null || device.trim().isEmpty) {
      return '未知';
    }
    return device;
  }

  String _buildJoyTagIndexingValue() {
    if (_imageSearchStatus == null) {
      return '不可用';
    }
    return _imageSearchStatus!.indexing.pendingThumbnails.toString();
  }

  String _buildLicenseStatusValue() {
    if (_licenseStatusError != null) {
      return '不可用';
    }
    final status = _licenseStatus;
    if (status == null) {
      return '不可用';
    }
    if (status.active) {
      return '已激活';
    }
    final errorCode = status.errorCode?.trim();
    if (errorCode == 'license_expired' ||
        _isUnixSecondsExpired(status.licenseValidUntil)) {
      return '授权已到期';
    }
    if (status.licenseValidUntil != null) {
      return '授权待同步';
    }
    if (status.configured && errorCode != null && errorCode.isNotEmpty) {
      return _licenseErrorLabel(errorCode);
    }
    return '未激活';
  }

  String _buildLicenseConnectivityValue() {
    if (_isTestingLicenseConnectivity) {
      return '检测中';
    }
    final result = _licenseConnectivityTest;
    if (result == null) {
      return '未检测';
    }
    return result.ok ? '连接正常' : '连接异常';
  }

  bool _isUnixSecondsExpired(int? unixSeconds) {
    if (unixSeconds == null) {
      return false;
    }
    final value = DateTime.fromMillisecondsSinceEpoch(
      unixSeconds * 1000,
      isUtc: true,
    );
    return value.isBefore(DateTime.now().toUtc());
  }

  String _licenseErrorLabel(String errorCode) {
    return switch (errorCode) {
      'license_required' => '未激活',
      'license_expired' => '授权已到期',
      'license_revoked' => '授权已吊销',
      'license_unavailable' => '授权不可用',
      _ => errorCode,
    };
  }

  String _buildExternalDataSourcesValue() {
    if (_javdbHealthy == null && _dmmHealthy == null) {
      return '未检测 JavDB / DMM';
    }
    return '${_buildExternalDataSourceText('JavDB', _javdbHealthy)} ${_buildExternalDataSourceText('DMM', _dmmHealthy)}';
  }

  String _buildExternalDataSourceText(String label, bool? healthy) {
    if (healthy == null) {
      return '未检测 $label';
    }
    return '${healthy ? '✅' : '❌'} $label';
  }

  Widget _buildExternalDataSourcesAction(BuildContext context) {
    return AppIconButton(
      key: const Key('overview-external-data-sources-test-button'),
      tooltip: '检测外部数据源',
      semanticLabel: '检测外部数据源',
      size: AppIconButtonSize.mini,
      onPressed: _isTestingMetadataProviders ? null : _testExternalDataSources,
      icon:
          _isTestingMetadataProviders
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
          _isTestingLicenseConnectivity ? null : _testLicenseConnectivity,
      icon:
          _isTestingLicenseConnectivity
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
