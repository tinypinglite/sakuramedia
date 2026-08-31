import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_format.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_provider.dart';
import 'package:sakuramedia/features/overview/presentation/providers/overview_system_info_state.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/cloud115_authentication_status_chips.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/external_data_source_status_chips.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/scrolling/app_adaptive_refresh_scroll_view.dart';
import 'package:sakuramedia/widgets/base/actions/app_button.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';
import 'package:sakuramedia/widgets/base/feedback/app_empty_state.dart';

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
              children: [
                const _MobileSystemOverviewIntroCard(),
                SizedBox(height: context.appSpacing.md),
                _buildSystemInfoContent(context, state, notifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemInfoContent(
    BuildContext context,
    OverviewSystemInfoState systemInfo,
    OverviewSystemInfo notifier,
  ) {
    if (systemInfo.isLoadingStatus) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          _MobileSystemOverviewSectionSkeleton(title: '媒体资产'),
          _MobileSystemOverviewSectionSkeleton(title: '服务健康'),
        ],
      );
    }

    if (systemInfo.statusError != null) {
      return AppContentCard(
        title: '系统信息',
        padding: EdgeInsets.all(context.appSpacing.lg),
        child: AppEmptyState(
          message: systemInfo.statusError!,
          retryKey: const Key('mobile-system-overview-retry-button'),
          onRetry: notifier.refresh,
        ),
      );
    }

    final status = systemInfo.status;
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
              value: formatGigabytes(status.mediaFiles.totalSizeBytes),
            ),
            _MobileSystemOverviewMetricItem(
              id: 'thumbnails-total',
              label: '缩略图总数',
              value: status.thumbnails.total.toString(),
            ),
            _MobileSystemOverviewMetricItem(
              id: 'thumbnails-pending',
              label: '待生成缩略图',
              value: status.thumbnails.pendingMedia.toString(),
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
              value: systemInfo.buildJoyTagHealthValue(),
              isLoading: systemInfo.isLoadingImageSearchStatus,
            ),
            _MobileSystemOverviewMetricItem(
              id: 'joytag-device',
              label: '推理设备',
              value: systemInfo.buildJoyTagDeviceValue(),
              isLoading: systemInfo.isLoadingImageSearchStatus,
            ),
            _MobileSystemOverviewMetricItem(
              id: 'joytag-indexing-backlog',
              label: '待索引',
              value: systemInfo.buildJoyTagIndexingValue(),
              isLoading: systemInfo.isLoadingImageSearchStatus,
            ),
            _MobileSystemOverviewMetricItem(
              id: 'external-data-sources',
              label: '外部数据源',
              valueWidget: ExternalDataSourceStatusChips(
                javdbHealthy: systemInfo.javdbHealthy,
                isTesting: systemInfo.isTestingMetadataProviders,
                keyPrefix: 'mobile-system-overview',
              ),
              actionLabel: '检测',
              isActionLoading: systemInfo.isTestingMetadataProviders,
              onActionPressed: notifier.testExternalDataSources,
            ),
            _MobileSystemOverviewMetricItem(
              id: 'cloud115-authentication',
              label: '115 认证状态',
              valueWidget: Cloud115AuthenticationStatusChips(
                summary: systemInfo.cloud115CookiesStatus?.summary,
                isTesting: systemInfo.isTestingCloud115Authentication,
                requestFailed: systemInfo.cloud115AuthenticationRequestFailed,
                keyPrefix: 'mobile-system-overview',
              ),
              actionLabel: '检测',
              isActionLoading: systemInfo.isTestingCloud115Authentication,
              onActionPressed: notifier.testCloud115Authentication,
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
    this.value = '',
    this.valueWidget,
    this.isLoading = false,
    this.actionLabel,
    this.isActionLoading = false,
    this.onActionPressed,
  });

  final String id;
  final String label;
  final String value;

  /// 非 null 时代替 [value] 文本渲染（如外部数据源的状态徽章行）。
  final Widget? valueWidget;
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
          else if (item.valueWidget != null)
            item.valueWidget!
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
