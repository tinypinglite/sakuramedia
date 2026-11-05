import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_format.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_surface.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/status/presentation/status_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

enum AssetSummaryCardLayout { standard, hero }

/// 媒体资产卡：概览页的主数据面。
///
/// [AssetSummaryCardLayout.hero] 在宽桌面使用「主指标 + 三个辅助指标 + 单行
/// 库状态」；窄窗口与移动端继续使用等权分格，避免为了桌面层级牺牲窄屏可读性。
class AssetSummaryCard extends StatelessWidget {
  const AssetSummaryCard({
    super.key,
    required this.status,
    required this.insights,
    required this.pendingIndexCount,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.layout = AssetSummaryCardLayout.standard,
  });

  final StatusDto? status;
  final StatusInsightsDto? insights;
  final int pendingIndexCount;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final AssetSummaryCardLayout layout;

  @override
  Widget build(BuildContext context) {
    return _AssetHeroSurface(
      key: const Key('overview-asset-summary-card'),
      title: AppLocalizations.of(context).overviewMediaAssets,
      libraryCount: status?.mediaLibraries.total,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading && status == null) {
      // loading 用占位数据渲染真实分格，由 [AppSkeletonizer] 灰化。
      return AppSkeletonizer(
        enabled: true,
        child: _buildLoaded(
          context,
          statusSummaryPlaceholder(),
          statusInsightsPlaceholder(),
        ),
      );
    }
    if (errorMessage != null) {
      return _AssetErrorRow(
        message: errorMessage!,
        onRetry: onRetry,
        retryKey: const Key('overview-asset-retry-button'),
      );
    }

    final current = status;
    if (current == null) {
      return Text(
        AppLocalizations.of(context).overviewNoAssetData,
        style:
            resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: AppTextWeight.regular,
              tone: AppTextTone.onMedia,
            ).copyWith(
              color: context.appTextPalette.onMedia.withValues(alpha: 0.58),
            ),
      );
    }
    return _buildLoaded(context, current, insights);
  }

  Widget _buildLoaded(
    BuildContext context,
    StatusDto current,
    StatusInsightsDto? insights,
  ) {
    final l10n = AppLocalizations.of(context);
    final movieMetric = _AssetMetric(
      id: 'movies',
      label: l10n.overviewMovies,
      value: formatCount(current.movies.total),
      secondary: l10n.overviewMoviePlayableSubscribed(
        formatCount(current.movies.playable),
        formatCount(current.movies.subscribed),
      ),
      narrowSecondary: l10n.overviewMoviePlayable(
        formatCount(current.movies.playable),
      ),
    );
    final actorsMetric = _AssetMetric(
      id: 'actors',
      label: l10n.overviewActresses,
      value: formatCount(current.actors.femaleTotal),
      secondary: l10n.overviewSubscribedCount(
        formatCount(current.actors.femaleSubscribed),
      ),
    );
    final mediaFilesMetric = _AssetMetric(
      id: 'media-files',
      label: l10n.overviewMediaFiles,
      value: formatCount(current.mediaFiles.total),
      secondary: l10n.overviewLibraryCount(
        formatCount(current.mediaLibraries.total),
      ),
    );
    final mediaSizeMetric = _AssetMetric(
      id: 'media-size',
      label: l10n.overviewTotalMediaSize,
      value: formatFileSize(current.mediaFiles.totalSizeBytes),
      secondary: l10n.overviewMediaTotalDetail(
        formatCount(current.mediaFiles.total),
        formatCount(current.thumbnails.total),
      ),
    );
    final standardMetrics = <_AssetMetric>[
      movieMetric,
      actorsMetric,
      mediaFilesMetric,
      mediaSizeMetric,
    ];
    final heroSupportingMetrics = <_AssetMetric>[
      movieMetric,
      _AssetMetric(
        id: 'subscribed',
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
      _AssetMetric(
        id: 'collections',
        label: l10n.routeCollectionsTitle,
        value: formatCount(_collectionCount(insights?.collections)),
        secondary: l10n.overviewCollectionKinds,
      ),
    ];

    final backlog = _buildBacklogItems(current, l10n);
    final collections = _buildCollectionItems(insights?.collections, l10n);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (layout == AssetSummaryCardLayout.hero &&
            constraints.maxWidth >= _heroMinWidth) {
          return _buildHeroLayout(
            context,
            primaryMetric: mediaSizeMetric,
            supportingMetrics: heroSupportingMetrics,
            backlog: backlog,
            collections: collections,
          );
        }

        final narrow = constraints.maxWidth < _twoColumnMinWidth;
        final rows = narrow
            ? <List<_AssetMetric>>[
                standardMetrics.sublist(0, 2),
                standardMetrics.sublist(2, 4),
              ]
            : <List<_AssetMetric>>[standardMetrics];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var index = 0; index < rows.length; index += 1) ...<Widget>[
              if (index > 0) SizedBox(height: context.appSpacing.xl),
              _AssetMetricRow(
                cells: <Widget>[
                  for (final metric in rows[index])
                    _AssetMetricCell(metric: metric, narrow: narrow),
                ],
              ),
            ],
            if (backlog.isNotEmpty || collections.isNotEmpty) ...<Widget>[
              Padding(
                padding: EdgeInsets.symmetric(vertical: context.appSpacing.lg),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: _heroDividerColor(context),
                ),
              ),
              if (backlog.isNotEmpty)
                _FootnoteLine(
                  key: const Key('overview-footnote-backlog'),
                  icon: Icons.hourglass_empty_rounded,
                  items: backlog,
                ),
              if (backlog.isNotEmpty && collections.isNotEmpty)
                SizedBox(height: context.appSpacing.md),
              if (collections.isNotEmpty)
                _FootnoteLine(
                  key: const Key('overview-footnote-collections'),
                  icon: Icons.folder_outlined,
                  prefix: l10n.overviewCollectionsPrefix,
                  items: collections,
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeroLayout(
    BuildContext context, {
    required _AssetMetric primaryMetric,
    required List<_AssetMetric> supportingMetrics,
    required List<_FootnoteItem> backlog,
    required List<_FootnoteItem> collections,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(
                flex: 5,
                child: _AssetPrimaryMetric(metric: primaryMetric),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.appSpacing.xl,
                ),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: _heroDividerColor(context),
                ),
              ),
              Expanded(
                flex: 7,
                child: _AssetSupportingMetricGrid(metrics: supportingMetrics),
              ),
            ],
          ),
        ),
        if (backlog.isNotEmpty || collections.isNotEmpty) ...<Widget>[
          Padding(
            padding: EdgeInsets.only(top: context.appSpacing.xl),
            child: Divider(
              height: 1,
              thickness: 1,
              color: _heroDividerColor(context),
            ),
          ),
          SizedBox(height: context.appSpacing.lg),
          _HeroStatusLine(
            key: const Key('overview-asset-status-line'),
            backlog: backlog,
            collections: collections,
          ),
        ],
      ],
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
        ),
      if (pendingIndexCount > 0)
        _FootnoteItem(
          label: l10n.overviewPendingIndex,
          count: pendingIndexCount,
        ),
    ];
  }

  List<_FootnoteItem> _buildCollectionItems(
    CollectionsStatsDto? collections,
    AppLocalizations l10n,
  ) {
    if (collections == null || collections.isEmpty) {
      return const <_FootnoteItem>[];
    }
    return <_FootnoteItem>[
      if (collections.playlists.count > 0)
        _FootnoteItem(
          label: l10n.overviewPlaylists,
          count: collections.playlists.count,
        ),
      if (collections.videoCollections.count > 0)
        _FootnoteItem(
          label: l10n.overviewVideoCollections,
          count: collections.videoCollections.count,
        ),
      if (collections.clipCollections.count > 0)
        _FootnoteItem(
          label: l10n.overviewClipCollections,
          count: collections.clipCollections.count,
        ),
      if (collections.momentCollections.count > 0)
        _FootnoteItem(
          label: l10n.overviewMomentCollections,
          count: collections.momentCollections.count,
        ),
    ];
  }
}

/// 窄屏（卡片内容宽 < 该值）时指标折成两列。
const double _twoColumnMinWidth = 520;

/// Hero 布局的最小内容宽度；窄桌面窗口仍回退到等权分格。
const double _heroMinWidth = 520;

int _collectionCount(CollectionsStatsDto? collections) {
  if (collections == null) {
    return 0;
  }
  return collections.playlists.count +
      collections.videoCollections.count +
      collections.clipCollections.count +
      collections.momentCollections.count;
}

Color _heroDividerColor(BuildContext context) {
  return context.appTextPalette.onMedia.withValues(alpha: 0.14);
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
    tone: AppTextTone.onMedia,
  ).copyWith(color: context.appTextPalette.onMedia.withValues(alpha: opacity));
}

class _AssetMetric {
  const _AssetMetric({
    required this.id,
    required this.label,
    required this.value,
    required this.secondary,
    this.narrowSecondary,
  });

  final String id;
  final String label;
  final String value;

  /// 副文案；窄卡片放不下多个事实时退到 [narrowSecondary]。
  final String secondary;
  final String? narrowSecondary;
}

class _AssetPrimaryMetric extends StatelessWidget {
  const _AssetPrimaryMetric({required this.metric});

  final _AssetMetric metric;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('overview-asset-${metric.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.appTextPalette.onMedia.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(width: context.appSpacing.sm),
            Text(
              metric.label,
              style: _heroTextStyle(
                context,
                AppTextSize.s12,
                weight: AppTextWeight.medium,
                opacity: 0.62,
              ),
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.md),
        Text(
          metric.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              _heroTextStyle(
                context,
                AppTextSize.s32,
                weight: AppTextWeight.semibold,
              ).copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          metric.secondary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _heroTextStyle(context, AppTextSize.s12, opacity: 0.56),
        ),
      ],
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
        _AssetSupportingMetricRow(metrics: firstRow),
        SizedBox(height: context.appSpacing.xl),
        _AssetSupportingMetricRow(metrics: secondRow),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < metrics.length; index += 1) ...<Widget>[
          if (index > 0) SizedBox(width: context.appSpacing.xl),
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
    return Column(
      key: Key('overview-asset-${metric.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          metric.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _heroTextStyle(context, AppTextSize.s12, opacity: 0.58),
        ),
        SizedBox(height: context.appSpacing.sm),
        Text(
          metric.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              _heroTextStyle(
                context,
                AppTextSize.s16,
                weight: AppTextWeight.semibold,
              ).copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          metric.secondary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _heroTextStyle(context, AppTextSize.s12, opacity: 0.54),
        ),
      ],
    );
  }
}

class _HeroStatusLine extends StatelessWidget {
  const _HeroStatusLine({
    super.key,
    required this.backlog,
    required this.collections,
  });

  final List<_FootnoteItem> backlog;
  final List<_FootnoteItem> collections;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labelStyle = _heroTextStyle(context, AppTextSize.s12, opacity: 0.58);
    final countStyle = _heroTextStyle(
      context,
      AppTextSize.s12,
      weight: AppTextWeight.semibold,
    );
    final separatorStyle = labelStyle.copyWith(
      color: context.appTextPalette.onMedia.withValues(alpha: 0.30),
    );

    final spans = <InlineSpan>[];
    void addSeparator() {
      if (spans.isNotEmpty) {
        spans.add(TextSpan(text: '   ·   ', style: separatorStyle));
      }
    }

    void addIconSegment(IconData icon, List<InlineSpan> content) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            icon,
            size: context.appComponentTokens.iconSizeXs,
            color: context.appTextPalette.onMedia.withValues(alpha: 0.36),
          ),
        ),
      );
      spans.add(WidgetSpan(child: SizedBox(width: context.appSpacing.sm)));
      spans.addAll(content);
    }

    if (backlog.isNotEmpty) {
      addSeparator();
      addIconSegment(Icons.hourglass_empty_rounded, <InlineSpan>[
        for (var index = 0; index < backlog.length; index += 1) ...<InlineSpan>[
          if (index > 0) TextSpan(text: ' · ', style: separatorStyle),
          TextSpan(text: '${backlog[index].label} ', style: labelStyle),
          TextSpan(text: formatCount(backlog[index].count), style: countStyle),
        ],
      ]);
    }

    if (collections.isNotEmpty) {
      addSeparator();
      addIconSegment(Icons.folder_outlined, <InlineSpan>[
        TextSpan(text: l10n.overviewCollectionsPrefix, style: labelStyle),
        for (
          var index = 0;
          index < collections.length;
          index += 1
        ) ...<InlineSpan>[
          if (index > 0) TextSpan(text: ' · ', style: separatorStyle),
          TextSpan(text: '${collections[index].label} ', style: labelStyle),
          TextSpan(
            text: formatCount(collections[index].count),
            style: countStyle,
          ),
        ],
      ]);
    }

    return Text.rich(TextSpan(children: spans));
  }
}

class _AssetErrorRow extends StatelessWidget {
  const _AssetErrorRow({
    required this.message,
    required this.onRetry,
    required this.retryKey,
  });

  final String message;
  final VoidCallback? onRetry;
  final Key retryKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            message,
            style: _heroTextStyle(context, AppTextSize.s12, opacity: 0.78),
          ),
        ),
        if (onRetry != null) ...<Widget>[
          SizedBox(width: context.appSpacing.sm),
          AppInteractiveSurface(
            onTap: onRetry,
            child: Container(
              height: context.appComponentTokens.buttonHeightXs,
              padding: EdgeInsets.symmetric(horizontal: context.appSpacing.sm),
              alignment: Alignment.center,
              child: Text(
                AppLocalizations.of(context).commonRetry,
                key: retryKey,
                style: _heroTextStyle(
                  context,
                  AppTextSize.s12,
                  weight: AppTextWeight.semibold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AssetMetricRow extends StatelessWidget {
  const _AssetMetricRow({required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var index = 0; index < cells.length; index += 1) ...<Widget>[
            if (index > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.lg),
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: _heroDividerColor(context),
                ),
              ),
            Expanded(child: cells[index]),
          ],
        ],
      ),
    );
  }
}

class _AssetMetricCell extends StatelessWidget {
  const _AssetMetricCell({required this.metric, required this.narrow});

  final _AssetMetric metric;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: Key('overview-asset-${metric.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          metric.label,
          style: _heroTextStyle(context, AppTextSize.s12, opacity: 0.58),
        ),
        SizedBox(height: context.appSpacing.sm),
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
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
        ),
        SizedBox(height: context.appSpacing.xs),
        Text(
          narrow
              ? (metric.narrowSecondary ?? metric.secondary)
              : metric.secondary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: _heroTextStyle(context, AppTextSize.s12, opacity: 0.54),
        ),
      ],
    );
  }
}

class _FootnoteItem {
  const _FootnoteItem({required this.label, required this.count});

  final String label;
  final int count;
}

/// 脚注行：图标用行内 [WidgetSpan] 与文字同排版，天然与首行文字居中对齐，
/// 文本换行时图标也不会错位。
class _FootnoteLine extends StatelessWidget {
  const _FootnoteLine({
    super.key,
    required this.icon,
    required this.items,
    this.prefix,
  });

  final IconData icon;
  final List<_FootnoteItem> items;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final labelStyle = _heroTextStyle(context, AppTextSize.s12, opacity: 0.58);
    final countStyle = _heroTextStyle(
      context,
      AppTextSize.s12,
      weight: AppTextWeight.semibold,
    );
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(
              icon,
              size: context.appComponentTokens.iconSizeXs,
              color: context.appTextPalette.onMedia.withValues(alpha: 0.36),
            ),
          ),
          WidgetSpan(child: SizedBox(width: context.appSpacing.sm)),
          if (prefix != null) TextSpan(text: prefix, style: labelStyle),
          for (var index = 0; index < items.length; index += 1) ...<InlineSpan>[
            if (index > 0) TextSpan(text: ' · ', style: labelStyle),
            TextSpan(text: '${items[index].label} ', style: labelStyle),
            TextSpan(text: formatCount(items[index].count), style: countStyle),
          ],
        ],
      ),
    );
  }
}

/// 概览页唯一的主卡：深色面由当前主题色实时推导。
class _AssetHeroSurface extends StatelessWidget {
  const _AssetHeroSurface({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const _AssetHeroIconTile(icon: Icons.video_library_rounded),
              SizedBox(width: spacing.md),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _heroTextStyle(
                    context,
                    AppTextSize.s16,
                    weight: AppTextWeight.semibold,
                  ),
                ),
              ),
              if (count != null) ...<Widget>[
                SizedBox(width: spacing.md),
                Container(
                  key: const Key('overview-asset-library-count'),
                  height: context.appComponentTokens.buttonHeight2xs,
                  padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                  decoration: BoxDecoration(
                    color: context.appTextPalette.onMedia.withValues(
                      alpha: 0.10,
                    ),
                    borderRadius: context.appRadius.pillBorder,
                    border: Border.all(
                      color: context.appTextPalette.onMedia.withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    AppLocalizations.of(
                      context,
                    ).overviewLibraryCount(formatCount(count)),
                    style: _heroTextStyle(
                      context,
                      AppTextSize.s10,
                      opacity: 0.72,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: spacing.lg),
          child,
        ],
      ),
    );
  }
}

class _AssetHeroIconTile extends StatelessWidget {
  const _AssetHeroIconTile({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.appSpacing.xxl,
      height: context.appSpacing.xxl,
      decoration: BoxDecoration(
        borderRadius: context.appRadius.mdBorder,
        color: context.appTextPalette.onMedia.withValues(alpha: 0.14),
        border: Border.all(
          color: context.appTextPalette.onMedia.withValues(alpha: 0.12),
        ),
      ),
      child: Icon(
        icon,
        size: context.appComponentTokens.iconSizeMd,
        color: context.appTextPalette.onMedia,
      ),
    );
  }
}
