import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/core/format/file_size.dart';
import 'package:sakuramedia/features/overview/presentation/overview_system_info_format.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_card_icon.dart';
import 'package:sakuramedia/features/overview/presentation/widgets/overview_card_states.dart';
import 'package:sakuramedia/features/status/data/status_dto.dart';
import 'package:sakuramedia/features/status/presentation/status_placeholders.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_content_card.dart';

/// 存储分布卡：各媒体库的文件数，以及存储端的占用构成。
///
/// provider 能返回容量时，长条按 SakuraMedia 占用 / 其他占用 / 空闲分段；
/// 返回不了时退回旧的「媒体合计占比」展示。
class StorageUsageCard extends StatelessWidget {
  const StorageUsageCard({
    super.key,
    required this.libraries,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.embedded = false,
  });

  final List<MediaLibraryUsageDto>? libraries;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;

  /// 关闭自身卡片外壳，由外层洞察带提供统一卡面。
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final libraryCount = libraries?.length;
    return AppContentCard(
      key: const Key('overview-storage-usage-card'),
      title: l10n.overviewStorageDistribution,
      padding: embedded ? EdgeInsets.zero : null,
      backgroundColor: embedded ? Colors.transparent : null,
      borderColor: embedded ? Colors.transparent : null,
      titleStyle: resolveAppTextStyle(
        context,
        size: AppTextSize.s16,
        weight: AppTextWeight.semibold,
        tone: AppTextTone.primary,
      ),
      headerLeading: const OverviewCardIcon(icon: Icons.storage_rounded),
      headerTrailing: libraryCount == null || libraryCount == 0
          ? null
          : Text(
              l10n.overviewLibraryCount(formatCount(libraryCount)),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s10,
                tone: AppTextTone.secondary,
              ),
            ),
      headerBottomSpacing: context.appSpacing.md,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (isLoading && libraries == null) {
      // loading 用占位媒体库渲染真实长条，由 [AppSkeletonizer] 灰化。
      return AppSkeletonizer(
        enabled: true,
        child: _buildLoaded(context, mediaLibraryUsagePlaceholders()),
      );
    }
    if (errorMessage != null) {
      return OverviewCardErrorRow(
        message: errorMessage!,
        onRetry: onRetry,
        retryKey: const Key('overview-storage-usage-retry-button'),
      );
    }

    final items = libraries ?? const <MediaLibraryUsageDto>[];
    if (items.isEmpty) {
      return Text(
        AppLocalizations.of(context).overviewNoMediaLibraries,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.regular,
          tone: AppTextTone.muted,
        ),
      );
    }
    return _buildLoaded(context, items);
  }

  Widget _buildLoaded(BuildContext context, List<MediaLibraryUsageDto> items) {
    final totalBytes = items.fold<int>(
      0,
      (sum, library) => sum + library.totalSizeBytes,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: context.appSpacing.xxxl * 5),
      child: ScrollbarTheme(
        data: ScrollbarTheme.of(context).copyWith(
          thumbColor: WidgetStatePropertyAll(context.appColors.borderStrong),
          thickness: WidgetStatePropertyAll(context.appSpacing.xs),
          radius: Radius.circular(context.appSpacing.xs / 2),
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            key: const Key('overview-storage-usage-scroll'),
            primary: false,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  var index = 0;
                  index < items.length;
                  index += 1
                ) ...<Widget>[
                  if (index > 0) SizedBox(height: context.appSpacing.lg),
                  _StorageUsageRow(
                    library: items[index],
                    ratio: totalBytes <= 0
                        ? 0
                        : items[index].totalSizeBytes / totalBytes,
                    breakdown: storageUsageBreakdown(items[index]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StorageUsageRow extends StatelessWidget {
  const _StorageUsageRow({
    required this.library,
    required this.ratio,
    required this.breakdown,
  });

  static const double _barHeight = 6;

  final MediaLibraryUsageDto library;
  final double ratio;
  final StorageUsageBreakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    final breakdown = this.breakdown;
    final l10n = AppLocalizations.of(context);
    return Column(
      key: Key('overview-storage-library-${library.libraryId}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Expanded(
              child: Text(
                library.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.primary,
                ),
              ),
            ),
            SizedBox(width: context.appSpacing.md),
            Text(
              breakdown == null
                  ? l10n.overviewFilesAndSize(
                      formatCount(library.fileCount),
                      formatFileSize(library.totalSizeBytes),
                    )
                  : l10n.overviewFiles(formatCount(library.fileCount)),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.secondary,
              ),
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.sm),
        _StorageUsageBar(
          key: Key('overview-storage-bar-${library.libraryId}'),
          libraryId: library.libraryId,
          height: _barHeight,
          ratio: ratio,
          breakdown: breakdown,
        ),
        if (breakdown != null) ...<Widget>[
          SizedBox(height: context.appSpacing.sm),
          _StorageUsageLegend(breakdown: breakdown),
        ],
      ],
    );
  }
}

class _StorageUsageBar extends StatelessWidget {
  const _StorageUsageBar({
    super.key,
    required this.libraryId,
    required this.height,
    required this.ratio,
    required this.breakdown,
  });

  final int libraryId;
  final double height;

  /// 无容量数据时的退回口径：本库媒体合计占所有媒体库合计的比例。
  final double ratio;
  final StorageUsageBreakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    final breakdown = this.breakdown;
    return ClipRRect(
      borderRadius: context.appRadius.pillBorder,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: context.appColors.surfaceMuted),
            if (breakdown == null)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio.clamp(0, 1),
                child: ColoredBox(color: Theme.of(context).colorScheme.primary),
              )
            else
              Row(
                // ColoredBox 无子节点，拉伸交叉轴才能撑满长条高度。
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final segment in _segments(context, breakdown))
                    if (segment.bytes > 0)
                      Expanded(
                        flex: segment.bytes,
                        child: ColoredBox(
                          key: Key(
                            'overview-storage-segment-${segment.name}-'
                            '$libraryId',
                          ),
                          color: segment.color,
                        ),
                      ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static List<({String name, Color color, int bytes})> _segments(
    BuildContext context,
    StorageUsageBreakdown breakdown,
  ) {
    return <({String name, Color color, int bytes})>[
      (
        name: 'sakura',
        color: Theme.of(context).colorScheme.primary,
        bytes: breakdown.sakuraBytes,
      ),
      (
        name: 'other',
        color: context.appTextPalette.muted,
        bytes: breakdown.otherBytes,
      ),
      (
        name: 'free',
        color: context.appColors.borderSubtle,
        bytes: breakdown.freeBytes,
      ),
    ];
  }
}

class _StorageUsageLegend extends StatelessWidget {
  const _StorageUsageLegend({required this.breakdown});

  final StorageUsageBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: context.appSpacing.md,
      runSpacing: context.appSpacing.xs,
      children: <Widget>[
        _StorageLegendItem(
          label: 'Sakura',
          bytes: breakdown.sakuraBytes,
          color: Theme.of(context).colorScheme.primary,
        ),
        _StorageLegendItem(
          label: l10n.overviewOther,
          bytes: breakdown.otherBytes,
          color: context.appTextPalette.muted,
        ),
        _StorageLegendItem(
          label: l10n.overviewFree,
          bytes: breakdown.freeBytes,
          color: context.appColors.borderSubtle,
        ),
      ],
    );
  }
}

class _StorageLegendItem extends StatelessWidget {
  const _StorageLegendItem({
    required this.label,
    required this.bytes,
    required this.color,
  });

  final String label;
  final int bytes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: context.appRadius.xsBorder,
          ),
        ),
        SizedBox(width: context.appSpacing.xs),
        Text(
          '$label ${formatFileSize(bytes)}',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s10,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
      ],
    );
  }
}
