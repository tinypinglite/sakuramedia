import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_thumbnail_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/media/images/thumbnail_grid_column_resolver.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_selection_status_bar.dart';
import 'package:sakuramedia/widgets/domain/media/movie_media_thumbnail_grid.dart';

/// 媒体缩略图页签内容。
///
/// JAV 详情和 PornBox 视频缩略图页共用这套时间间隔、列数、切片圈选、预览
/// 和图片菜单交互；远端加载与具体动作由调用方负责。
class MediaThumbnailTab extends ConsumerWidget {
  static const List<int> _intervalOptions = <int>[10, 20, 30, 60];
  static const List<int> _columnOptions = <int>[2, 3, 4, 5];

  const MediaThumbnailTab({
    super.key,
    required this.mediaId,
    required this.thumbnailPreviewPresentation,
    this.onThumbnailMenuRequested,
    this.onCreateClip,
    this.keyPrefix = 'movie-detail-thumbnail',
  });

  final int? mediaId;
  final MoviePlotPreviewPresentation thumbnailPreviewPresentation;
  final void Function(int index, Offset globalPosition)?
  onThumbnailMenuRequested;
  final VoidCallback? onCreateClip;
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movieDetailThumbnailProvider(mediaId: mediaId));
    final controller = ref.read(
      movieDetailThumbnailProvider(mediaId: mediaId).notifier,
    );
    final thumbnails = state.thumbnails;

    return LayoutBuilder(
      builder: (context, constraints) {
        final autoColumns = resolveThumbnailGridColumnCount(
          width: constraints.maxWidth,
          spacing: context.appSpacing.sm,
          targetWidth: context.appComponentTokens.movieThumbnailTargetWidth,
        );
        final resolvedColumns = state.usesAutoColumns
            ? autoColumns
            : (state.columns ?? autoColumns);
        if (state.usesAutoColumns && state.columns != autoColumns) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              controller.applyAutoColumns(autoColumns);
            }
          });
        }

        return Padding(
          padding: EdgeInsets.only(
            top: context.appSpacing.md,
            bottom: context.appSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                key: Key('$keyPrefix-toolbar'),
                spacing: _MediaThumbnailControlGroup.groupSpacing,
                runSpacing: context.appSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MediaThumbnailIntervalSelector(
                    keyPrefix: keyPrefix,
                    options: _intervalOptions,
                    selectedIntervalSeconds: state.selectedIntervalSeconds,
                    onSelect: controller.setIntervalSeconds,
                  ),
                  _MediaThumbnailColumnsSelector(
                    keyPrefix: keyPrefix,
                    options: _columnOptions,
                    selectedColumns: resolvedColumns,
                    onSelect: controller.setColumns,
                  ),
                  if (onCreateClip != null)
                    AppIconButton(
                      key: Key('$keyPrefix-clip-toggle'),
                      tooltip: state.clipSelectionMode ? '退出切片圈选' : '圈选切片',
                      isSelected: state.clipSelectionMode,
                      size: AppIconButtonSize.mini,
                      selectedIconColor: Theme.of(context).colorScheme.primary,
                      onPressed: controller.toggleClipSelectionMode,
                      icon: const Icon(Icons.content_cut_rounded),
                    ),
                ],
              ),
              if (state.clipSelectionMode) ...[
                SizedBox(height: context.appSpacing.sm),
                ClipSelectionStatusBar(
                  keyPrefix: keyPrefix,
                  startSeconds: state.clipStartThumbnail?.offsetSeconds,
                  endSeconds: state.clipEndThumbnail?.offsetSeconds,
                  durationSeconds: state.clipSelectionDurationSeconds,
                  canCreate: state.canCreateClip,
                  onCreate: onCreateClip,
                  onClear: controller.clearClipSelection,
                ),
              ],
              SizedBox(height: context.appSpacing.md),
              Expanded(
                child: MovieMediaThumbnailGrid(
                  thumbnails: thumbnails,
                  isLoading: state.isLoading,
                  errorMessage: state.errorMessage,
                  columns: resolvedColumns,
                  activeIndex: state.activeIndex,
                  isScrollLocked: false,
                  onRetry: controller.retry,
                  onThumbnailMenuRequested: onThumbnailMenuRequested,
                  clipStartIndex: state.clipStartIndex,
                  clipEndIndex: state.clipEndIndex,
                  keyPrefix: keyPrefix,
                  onThumbnailTap: (index) {
                    if (state.clipSelectionMode) {
                      controller.handleClipSelectionTap(index);
                      return;
                    }
                    controller.selectIndex(index);
                    showMoviePlotPreviewOverlay(
                      context: context,
                      plotImages: thumbnails
                          .map((item) => item.image)
                          .toList(growable: false),
                      initialIndex: index,
                      onRequestImageMenu: onThumbnailMenuRequested == null
                          ? null
                          : (menuContext, previewIndex, globalPosition) async {
                              onThumbnailMenuRequested!(
                                previewIndex,
                                globalPosition,
                              );
                            },
                      presentation: thumbnailPreviewPresentation,
                      thumbnailStripLayout:
                          MoviePlotPreviewThumbnailStripLayout.fixed,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MediaThumbnailIntervalSelector extends StatelessWidget {
  const _MediaThumbnailIntervalSelector({
    required this.keyPrefix,
    required this.options,
    required this.selectedIntervalSeconds,
    required this.onSelect,
  });

  final String keyPrefix;
  final List<int> options;
  final int selectedIntervalSeconds;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _MediaThumbnailControlGroup(
      key: Key('$keyPrefix-interval-group'),
      iconKey: Key('$keyPrefix-interval-icon'),
      icon: Icons.schedule_rounded,
      tooltip: '缩略图时间间隔',
      children: [
        for (final seconds in options)
          AppTextButton(
            key: Key('$keyPrefix-interval-$seconds'),
            label: '$seconds',
            size: AppTextButtonSize.xSmall,
            isSelected: selectedIntervalSeconds == seconds,
            onPressed: () => onSelect(seconds),
          ),
      ],
    );
  }
}

class _MediaThumbnailColumnsSelector extends StatelessWidget {
  const _MediaThumbnailColumnsSelector({
    required this.keyPrefix,
    required this.options,
    required this.selectedColumns,
    required this.onSelect,
  });

  final String keyPrefix;
  final List<int> options;
  final int selectedColumns;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _MediaThumbnailControlGroup(
      key: Key('$keyPrefix-columns-group'),
      iconKey: Key('$keyPrefix-columns-icon'),
      icon: Icons.grid_view_rounded,
      tooltip: '缩略图列数',
      children: [
        for (final columns in options)
          AppTextButton(
            key: Key('$keyPrefix-columns-$columns'),
            label: '$columns',
            size: AppTextButtonSize.xSmall,
            isSelected: selectedColumns == columns,
            onPressed: () => onSelect(columns),
          ),
      ],
    );
  }
}

class _MediaThumbnailControlGroup extends StatelessWidget {
  static const double groupSpacing = 12;
  static const double itemExtent = 28;

  const _MediaThumbnailControlGroup({
    super.key,
    required this.icon,
    required this.iconKey,
    required this.tooltip,
    required this.children,
  });

  final IconData icon;
  final Key iconKey;
  final String tooltip;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Wrap(
      spacing: context.appSpacing.xs,
      runSpacing: context.appSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Tooltip(
          message: tooltip,
          child: SizedBox.square(
            key: iconKey,
            dimension: itemExtent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: context.appRadius.smBorder,
                border: Border.all(color: colors.borderStrong),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: context.appComponentTokens.iconSizeXs,
                  color: context.appTextPalette.primary,
                ),
              ),
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}
