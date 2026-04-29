import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sakuramedia/features/configuration/data/metadata_provider_license_api.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_controller.dart';
import 'package:sakuramedia/features/status/data/status_api.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';
import 'package:sakuramedia/widgets/app_shell/app_content_card.dart';
import 'package:sakuramedia/widgets/app_shell/app_empty_state.dart';

class MobileSystemOverviewPage extends StatefulWidget {
  const MobileSystemOverviewPage({super.key});

  @override
  State<MobileSystemOverviewPage> createState() =>
      _MobileSystemOverviewPageState();
}

class _MobileSystemOverviewPageState extends State<MobileSystemOverviewPage> {
  late final OverviewSystemInfoController _controller;

  @override
  void initState() {
    super.initState();
    _controller = OverviewSystemInfoController(
      statusApi: context.read<StatusApi>(),
      metadataProviderLicenseApi: context.read<MetadataProviderLicenseApi>(),
    )..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return KeyedSubtree(
          key: const Key('mobile-system-overview-page'),
          child: AppAdaptiveRefreshScrollView(
            onRefresh: _controller.refresh,
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _MobileSystemOverviewIntroCard(),
                    SizedBox(height: context.appSpacing.md),
                    _buildSystemInfoContent(context),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemInfoContent(BuildContext context) {
    if (_controller.isLoadingStatus) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _MobileSystemOverviewSectionSkeleton(title: '媒体资产'),
          _MobileSystemOverviewSectionSkeleton(title: '服务健康'),
        ],
      );
    }

    if (_controller.statusError != null) {
      return AppContentCard(
        title: '系统信息',
        padding: EdgeInsets.all(context.appSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppEmptyState(message: _controller.statusError!),
            SizedBox(height: context.appSpacing.md),
            Align(
              alignment: Alignment.center,
              child: AppButton(
                key: const Key('mobile-system-overview-retry-button'),
                label: '重试',
                onPressed: _controller.refresh,
              ),
            ),
          ],
        ),
      );
    }

    final status = _controller.status;
    if (status == null) {
      return const AppEmptyState(message: '暂无系统信息');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MobileSystemOverviewSection(
          key: const Key('mobile-system-overview-media-assets-section'),
          title: '媒体资产',
          items: <_MobileSystemOverviewMetricItem>[
            _MobileSystemOverviewMetricItem(
              id: 'movies-total',
              label: '影片总数',
              value: status.movies.total.toString(),
            ),
            _MobileSystemOverviewMetricItem(
              id: 'movies-playable',
              label: '可播放影片',
              value: status.movies.playable.toString(),
            ),
            _MobileSystemOverviewMetricItem(
              id: 'actors-female-total',
              label: '女优总数',
              value: status.actors.femaleTotal.toString(),
            ),
            _MobileSystemOverviewMetricItem(
              id: 'media-files-total',
              label: '媒体文件',
              value: status.mediaFiles.total.toString(),
            ),
            _MobileSystemOverviewMetricItem(
              id: 'media-libraries-total',
              label: '资源库',
              value: status.mediaLibraries.total.toString(),
            ),
            _MobileSystemOverviewMetricItem(
              id: 'media-files-size',
              label: '媒体总量',
              value: _controller.formatGigabytes(
                status.mediaFiles.totalSizeBytes,
              ),
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.md),
        _MobileSystemOverviewSection(
          key: const Key('mobile-system-overview-health-section'),
          title: '服务健康',
          items: <_MobileSystemOverviewMetricItem>[
            _MobileSystemOverviewMetricItem(
              id: 'joytag-health',
              label: 'JoyTag 健康',
              value: _controller.buildJoyTagHealthValue(),
              isLoading: _controller.isLoadingImageSearchStatus,
            ),
            _MobileSystemOverviewMetricItem(
              id: 'joytag-device',
              label: '推理设备',
              value: _controller.buildJoyTagDeviceValue(),
              isLoading: _controller.isLoadingImageSearchStatus,
            ),
            _MobileSystemOverviewMetricItem(
              id: 'joytag-indexing-backlog',
              label: '待索引',
              value: _controller.buildJoyTagIndexingValue(),
              isLoading: _controller.isLoadingImageSearchStatus,
            ),
            _MobileSystemOverviewMetricItem(
              id: 'metadata-provider-license',
              label: '数据源授权',
              value: _controller.buildLicenseStatusValue(),
              isLoading: _controller.isLoadingLicenseStatus,
            ),
            _MobileSystemOverviewMetricItem(
              id: 'license-center-connectivity',
              label: '授权中心',
              value: _controller.buildLicenseConnectivityValue(),
              actionLabel: '检测',
              isActionLoading: _controller.isTestingLicenseConnectivity,
              onActionPressed: _controller.testLicenseConnectivity,
            ),
            _MobileSystemOverviewMetricItem(
              id: 'external-data-sources',
              label: '外部数据源',
              value: _controller.buildExternalDataSourcesValue(),
              actionLabel: '检测',
              isActionLoading: _controller.isTestingMetadataProviders,
              onActionPressed: _controller.testExternalDataSources,
            ),
          ],
        ),
      ],
    );
  }
}

class _MobileSystemOverviewIntroCard extends StatelessWidget {
  const _MobileSystemOverviewIntroCard();

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      key: const Key('mobile-system-overview-intro-card'),
      title: '系统概览',
      padding: EdgeInsets.all(context.appSpacing.lg),
      headerBottomSpacing: context.appSpacing.xs,
      child: Text(
        '快速查看媒体资产规模、识别索引状态与外部服务健康情况。',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      ),
    );
  }
}

class _MobileSystemOverviewSection extends StatelessWidget {
  const _MobileSystemOverviewSection({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<_MobileSystemOverviewMetricItem> items;

  @override
  Widget build(BuildContext context) {
    return AppContentCard(
      title: title,
      padding: EdgeInsets.all(context.appSpacing.lg),
      headerBottomSpacing: context.appSpacing.md,
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s16,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = context.appSpacing.sm;
          final itemWidth = (constraints.maxWidth - spacing) / 2;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: items
                .map(
                  (item) => SizedBox(
                    width: itemWidth,
                    child: _MobileSystemOverviewMetricTile(item: item),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }
}

class _MobileSystemOverviewMetricItem {
  const _MobileSystemOverviewMetricItem({
    required this.id,
    required this.label,
    required this.value,
    this.isLoading = false,
    this.actionLabel,
    this.isActionLoading = false,
    this.onActionPressed,
  });

  final String id;
  final String label;
  final String value;
  final bool isLoading;
  final String? actionLabel;
  final bool isActionLoading;
  final VoidCallback? onActionPressed;
}

class _MobileSystemOverviewMetricTile extends StatelessWidget {
  const _MobileSystemOverviewMetricTile({required this.item});

  final _MobileSystemOverviewMetricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('mobile-system-overview-stat-${item.id}'),
      padding: EdgeInsets.all(context.appSpacing.md),
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.mdBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.regular,
              tone: AppTextTone.muted,
            ),
          ),
          SizedBox(height: context.appSpacing.xs),
          if (item.isLoading)
            SizedBox(
              width: context.appComponentTokens.iconSizeMd,
              height: context.appComponentTokens.iconSizeMd,
              child: CircularProgressIndicator.adaptive(
                key: Key('mobile-system-overview-stat-loading-${item.id}'),
                strokeWidth:
                    context.appComponentTokens.movieCardLoaderStrokeWidth,
              ),
            )
          else
            Text(
              item.value,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (item.actionLabel != null && item.onActionPressed != null) ...[
            SizedBox(height: context.appSpacing.sm),
            AppButton(
              key: Key('mobile-system-overview-${item.id}-test-button'),
              label: item.isActionLoading ? '检测中' : item.actionLabel!,
              onPressed: item.isActionLoading ? null : item.onActionPressed,
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileSystemOverviewSectionSkeleton extends StatelessWidget {
  const _MobileSystemOverviewSectionSkeleton({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.appSpacing.md),
      child: AppContentCard(
        title: title,
        padding: EdgeInsets.all(context.appSpacing.lg),
        headerBottomSpacing: context.appSpacing.md,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final spacing = context.appSpacing.sm;
            final itemWidth = (constraints.maxWidth - spacing) / 2;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List<Widget>.generate(
                4,
                (index) => SizedBox(
                  width: itemWidth,
                  child: Container(
                    height: context.appSpacing.xxl * 2,
                    decoration: BoxDecoration(
                      color: context.appColors.surfaceMuted,
                      borderRadius: context.appRadius.mdBorder,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
