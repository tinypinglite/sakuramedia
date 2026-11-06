import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_format.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_card_icon.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_surface.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/status/presentation/status_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';

/// 媒体资产卡：概览页的主数据面。
///
/// 单层卡面：宽布局左右排布主指标和四个指标块，窄布局上下排列。
/// 内部不使用嵌套卡片，只用留白、分隔线和文字层级组织信息。
class AssetSummaryCard extends StatelessWidget {
  const AssetSummaryCard({
    super.key,
    required this.status,
    required this.pendingIndexCount,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  final StatusDto? status;
  final int pendingIndexCount;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _AssetCardSurface(
      key: const Key('overview-asset-summary-card'),
      title: AppLocalizations.of(context).overviewMediaAssets,
      libraryCount: status?.mediaLibraries.total,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading && status == null) {
      // loading 用占位数据渲染真实内容，由 [AppSkeletonizer] 灰化。
      return AppSkeletonizer(
        enabled: true,
        child: _buildLoaded(context, statusSummaryPlaceholder()),
      );
    }
    if (errorMessage != null) {
      return _AssetErrorState(
        message: errorMessage!,
        onRetry: onRetry,
        retryKey: const Key('overview-asset-retry-button'),
      );
    }

    final current = status;
    if (current == null) {
      return Text(
        AppLocalizations.of(context).overviewNoAssetData,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.secondary,
        ),
      );
    }
    return _buildLoaded(context, current);
  }

  Widget _buildLoaded(BuildContext context, StatusDto current) {
    final l10n = AppLocalizations.of(context);
    final movieMetric = _AssetMetric(
      id: 'movies',
      icon: Icons.play_circle_outline_rounded,
      label: l10n.overviewPlayableMovies,
      value: formatCount(current.movies.playable),
      secondary: l10n.overviewMovieTotal(formatCount(current.movies.total)),
    );
    final actorsMetric = _AssetMetric(
      id: 'actors',
      icon: Icons.person_outline_rounded,
      label: l10n.overviewActresses,
      value: formatCount(current.actors.femaleTotal),
      secondary: l10n.overviewSubscribedCount(
        formatCount(current.actors.femaleSubscribed),
      ),
    );
    final mediaSizeMetric = _mediaSizeMetric(current, l10n);
    final supportingMetrics = <_AssetMetric>[
      movieMetric,
      _AssetMetric(
        id: 'subscribed',
        icon: Icons.favorite_border_rounded,
        label: l10n.overviewSubscribedMovies,
        value: formatCount(current.movies.subscribed),
        secondary: l10n.overviewSubscriptionRate(
          formatSubscriptionRate(
            current.movies.subscribed,
            current.movies.total,
          ),
        ),
      ),
      actorsMetric,
      mediaSizeMetric,
    ];

    final backlog = _buildBacklogItems(current, l10n);

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = constraints.maxWidth >= _singleRowMinWidth
            ? _AssetSupportingMetricStrip(metrics: supportingMetrics)
            : _AssetSupportingMetricGrid(metrics: supportingMetrics);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            content,
            if (backlog.isNotEmpty) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(top: context.appSpacing.sm),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: _heroDividerColor(context),
                ),
              ),
              SizedBox(height: context.appSpacing.sm),
              _AssetBacklogStrip(
                key: const Key('overview-asset-status-line'),
                items: backlog,
              ),
            ],
          ],
        );
      },
    );
  }

  List<_FootnoteItem> _buildBacklogItems(
    StatusDto status,
    AppLocalizations l10n,
  ) {
    final thumbnails = status.thumbnails;
    return <_FootnoteItem>[
      if (thumbnails.pendingMedia > 0)
        _FootnoteItem(
          label: l10n.overviewPendingThumbnails,
          count: thumbnails.pendingMedia,
          icon: Icons.hourglass_top_rounded,
        ),
      if (pendingIndexCount > 0)
        _FootnoteItem(
          label: l10n.overviewPendingIndex,
          count: pendingIndexCount,
          icon: Icons.image_search_rounded,
        ),
    ];
  }
}

/// 四列指标带的最小内容宽度；更窄时改为 2×2 指标。
const double _singleRowMinWidth = 480;

_AssetMetric _mediaSizeMetric(StatusDto status, AppLocalizations l10n) {
  return _AssetMetric(
    id: 'media-size',
    icon: Icons.storage_rounded,
    label: l10n.overviewTotalMediaSize,
    value: formatFileSize(status.mediaFiles.totalSizeBytes),
    secondary: l10n.overviewFiles(formatCount(status.mediaFiles.total)),
  );
}

Color _heroDividerColor(BuildContext context) {
  return context.appColors.divider;
}

TextStyle _heroTextStyle(
  BuildContext context,
  AppTextSize size, {
  AppTextWeight weight = AppTextWeight.regular,
  double opacity = 1,
}) {
  return resolveAppTextStyle(
    context,
    size: size,
    weight: weight,
    tone: opacity >= 0.7 ? AppTextTone.primary : AppTextTone.secondary,
  );
}

class _AssetMetric {
  const _AssetMetric({
    required this.id,
    required this.icon,
    required this.label,
    required this.value,
    required this.secondary,
  });

  final String id;
  final IconData icon;
  final String label;
  final String value;
  final String secondary;
}

class _AssetSupportingMetricStrip extends StatelessWidget {
  const _AssetSupportingMetricStrip({required this.metrics});

  final List<_AssetMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final divider = _stripDivider(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var index = 0; index < metrics.length; index += 1) ...<Widget>[
            if (index > 0) divider,
            Expanded(child: _AssetSupportingMetric(metric: metrics[index])),
          ],
        ],
      ),
    );
  }

  Widget _stripDivider(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.sm),
      child: VerticalDivider(
        width: 1,
        thickness: 1,
        color: _heroDividerColor(context),
      ),
    );
  }
}

class _AssetSupportingMetricGrid extends StatelessWidget {
  const _AssetSupportingMetricGrid({required this.metrics});

  final List<_AssetMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final firstRow = metrics.take(2).toList(growable: false);
    final secondRow = metrics.skip(2).take(2).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        IntrinsicHeight(child: _AssetSupportingMetricRow(metrics: firstRow)),
        Divider(
          height: context.appSpacing.md,
          thickness: 1,
          color: _heroDividerColor(context),
        ),
        IntrinsicHeight(child: _AssetSupportingMetricRow(metrics: secondRow)),
      ],
    );
  }
}

class _AssetSupportingMetricRow extends StatelessWidget {
  const _AssetSupportingMetricRow({required this.metrics});

  final List<_AssetMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < metrics.length; index += 1) ...<Widget>[
          if (index > 0)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.appSpacing.md),
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: _heroDividerColor(context),
              ),
            ),
          Expanded(child: _AssetSupportingMetric(metric: metrics[index])),
        ],
      ],
    );
  }
}

class _AssetSupportingMetric extends StatelessWidget {
  const _AssetSupportingMetric({required this.metric});

  final _AssetMetric metric;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return Padding(
      key: Key('overview-asset-${metric.id}'),
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                metric.icon,
                size: context.appComponentTokens.iconSizeXs,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: spacing.xs),
              Expanded(
                child: Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _heroTextStyle(
                    context,
                    AppTextSize.s12,
                    weight: AppTextWeight.medium,
                    opacity: 0.6,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing.sm),
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                _heroTextStyle(
                  context,
                  AppTextSize.s20,
                  weight: AppTextWeight.semibold,
                ).copyWith(
                  height: 1.1,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
          ),
          SizedBox(height: spacing.xs),
          _AssetMetricDetail(metric: metric),
        ],
      ),
    );
  }
}

class _AssetMetricDetail extends StatelessWidget {
  const _AssetMetricDetail({required this.metric});

  final _AssetMetric metric;

  @override
  Widget build(BuildContext context) {
    final style = _heroTextStyle(
      context,
      AppTextSize.s10,
      opacity: 0.54,
    ).copyWith(height: 1.4);
    return Text(
      metric.secondary,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _AssetBacklogStrip extends StatelessWidget {
  const _AssetBacklogStrip({super.key, required this.items});

  final List<_FootnoteItem> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('overview-footnote-backlog'),
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      children: <Widget>[
        for (final item in items) _AssetBacklogChip(item: item),
      ],
    );
  }
}

class _AssetBacklogChip extends StatelessWidget {
  const _AssetBacklogChip({required this.item});

  final _FootnoteItem item;

  @override
  Widget build(BuildContext context) {
    final warning = context.appTextPalette.warning;
    return Container(
      height: context.appComponentTokens.buttonHeight2xs,
      padding: EdgeInsets.symmetric(horizontal: context.appSpacing.sm),
      decoration: BoxDecoration(
        color: context.appColors.warningSurface.withValues(alpha: 0.72),
        borderRadius: context.appRadius.pillBorder,
        border: Border.all(color: warning.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            item.icon,
            size: context.appComponentTokens.iconSize3xs,
            color: warning,
          ),
          SizedBox(width: context.appSpacing.xs),
          Text(
            item.label,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s10,
              weight: AppTextWeight.medium,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(width: context.appSpacing.xs),
          Text(
            formatCount(item.count),
            style:
                resolveAppTextStyle(
                  context,
                  size: AppTextSize.s10,
                  weight: AppTextWeight.semibold,
                  tone: AppTextTone.warning,
                ).copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
          ),
        ],
      ),
    );
  }
}

class _AssetErrorState extends StatelessWidget {
  const _AssetErrorState({
    required this.message,
    required this.onRetry,
    required this.retryKey,
  });

  final String message;
  final VoidCallback? onRetry;
  final Key retryKey;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: spacing.xxxl * 3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: spacing.xxxl,
              height: spacing.xxxl,
              decoration: BoxDecoration(
                color: context.appColors.errorSurface,
                borderRadius: context.appRadius.pillBorder,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: context.appComponentTokens.iconSizeMd,
                color: context.appTextPalette.error,
              ),
            ),
            SizedBox(height: spacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _heroTextStyle(
                context,
                AppTextSize.s12,
                weight: AppTextWeight.medium,
                opacity: 0.78,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              SizedBox(height: spacing.md),
              AppTextButton(
                label: AppLocalizations.of(context).commonRetry,
                labelKey: retryKey,
                icon: const Icon(Icons.refresh_rounded),
                emphasis: AppTextButtonEmphasis.accent,
                size: AppTextButtonSize.small,
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FootnoteItem {
  const _FootnoteItem({
    required this.label,
    required this.count,
    this.icon = Icons.hourglass_top_rounded,
  });

  final String label;
  final int count;
  final IconData icon;
}

/// 概览页媒体资产主卡：单层主题面，内部不再嵌套卡片。
class _AssetCardSurface extends StatelessWidget {
  const _AssetCardSurface({
    super.key,
    required this.title,
    required this.libraryCount,
    required this.child,
  });

  final String title;
  final int? libraryCount;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final count = libraryCount;
    return OverviewSurface(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const OverviewHeroIcon(icon: Icons.video_library_rounded),
              SizedBox(width: spacing.md),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _heroTextStyle(
                    context,
                    AppTextSize.s18,
                    weight: AppTextWeight.semibold,
                  ),
                ),
              ),
              if (count != null) ...<Widget>[
                SizedBox(width: spacing.md),
                Container(
                  key: const Key('overview-asset-library-count'),
                  height: context.appComponentTokens.buttonHeight2xs,
                  padding: EdgeInsets.symmetric(horizontal: spacing.md),
                  decoration: BoxDecoration(
                    color: context.appColors.surfaceCard.withValues(alpha: 0.6),
                    borderRadius: context.appRadius.pillBorder,
                    border: Border.all(
                      color: context.appColors.borderSubtle.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.folder_copy_outlined,
                        size: context.appComponentTokens.iconSize3xs,
                        color: context.appTextPalette.secondary,
                      ),
                      SizedBox(width: spacing.xs),
                      Text(
                        AppLocalizations.of(
                          context,
                        ).overviewLibraryCount(formatCount(count)),
                        style: _heroTextStyle(
                          context,
                          AppTextSize.s10,
                          opacity: 0.72,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: spacing.sm),
          child,
        ],
      ),
    );
  }
}
