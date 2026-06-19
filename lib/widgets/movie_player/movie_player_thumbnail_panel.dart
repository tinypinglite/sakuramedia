import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/clips/clip_selection_status_bar.dart';
import 'package:sakuramedia/widgets/media/thumbnail_grid_column_resolver.dart';
import 'package:sakuramedia/widgets/movie_player/movie_media_thumbnail_grid.dart';

class MoviePlayerThumbnailPanel extends StatefulWidget {
  const MoviePlayerThumbnailPanel({
    super.key,
    required this.thumbnails,
    required this.isLoading,
    required this.errorMessage,
    required this.columns,
    required this.activeIndex,
    required this.isScrollLocked,
    required this.usesAutoColumns,
    required this.onAutoColumnsResolved,
    required this.onColumnsChanged,
    required this.onToggleScrollLock,
    required this.onThumbnailTap,
    required this.onRetry,
    this.onThumbnailMenuRequested,
    this.clipSelectionMode = false,
    this.clipStartIndex,
    this.clipEndIndex,
    this.clipStartSeconds,
    this.clipEndSeconds,
    this.clipDurationSeconds,
    this.canCreateClip = false,
    this.onToggleClipSelectionMode,
    this.onCreateClip,
    this.onClearClipSelection,
    this.layout = ThumbnailGridLayout.uniform16x9,
  });

  final List<MovieMediaThumbnailDto> thumbnails;
  final bool isLoading;
  final String? errorMessage;
  final int? columns;
  final int? activeIndex;
  final bool isScrollLocked;
  final bool usesAutoColumns;
  final ValueChanged<int> onAutoColumnsResolved;
  final ValueChanged<int> onColumnsChanged;
  final VoidCallback onToggleScrollLock;
  final ValueChanged<int> onThumbnailTap;
  final VoidCallback onRetry;
  final void Function(int index, Offset globalPosition)?
  onThumbnailMenuRequested;
  final bool clipSelectionMode;
  final int? clipStartIndex;
  final int? clipEndIndex;
  final int? clipStartSeconds;
  final int? clipEndSeconds;
  final int? clipDurationSeconds;
  final bool canCreateClip;
  final VoidCallback? onToggleClipSelectionMode;
  final VoidCallback? onCreateClip;
  final VoidCallback? onClearClipSelection;

  /// 缩略图网格布局。pornbox 合集连播页传 [ThumbnailGridLayout.staggered] 走瀑布流；
  /// 其余调用方默认 [ThumbnailGridLayout.uniform16x9]（统一 16:9 网格 + 运行时 fit 自适应）。
  final ThumbnailGridLayout layout;

  @override
  State<MoviePlayerThumbnailPanel> createState() =>
      _MoviePlayerThumbnailPanelState();
}

class _MoviePlayerThumbnailPanelState extends State<MoviePlayerThumbnailPanel> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.appSpacing;
        final autoColumns = resolveThumbnailGridColumnCount(
          width: constraints.maxWidth,
          spacing: spacing.sm,
          targetWidth: context.appComponentTokens.movieThumbnailTargetWidth,
        );
        final resolvedColumns =
            widget.usesAutoColumns
                ? autoColumns
                : (widget.columns ?? autoColumns);
        if (widget.usesAutoColumns && widget.columns != autoColumns) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onAutoColumnsResolved(autoColumns);
            }
          });
        }

        return Padding(
          padding: EdgeInsets.all(spacing.lg),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final count in const <int>[2, 3, 4, 5]) ...[
                        if (count != 2) SizedBox(width: spacing.xs),
                        AppTextButton(
                          key: Key('movie-player-columns-$count'),
                          label: '$count',
                          size: AppTextButtonSize.xSmall,
                          isSelected: resolvedColumns == count,
                          onPressed: () => widget.onColumnsChanged(count),
                        ),
                      ],
                      SizedBox(width: spacing.sm),
                      AppIconButton(
                        key: const Key('movie-player-scroll-lock-toggle'),
                        tooltip:
                            widget.isScrollLocked ? '锁定跟随播放位置' : '允许手动滚动缩略图',
                        isSelected: widget.isScrollLocked,
                        selectedIconColor:
                            Theme.of(context).colorScheme.primary,
                        onPressed: widget.onToggleScrollLock,
                        icon: Icon(
                          widget.isScrollLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          size: context.appComponentTokens.iconSizeSm,
                        ),
                      ),
                      if (widget.onToggleClipSelectionMode != null) ...[
                        SizedBox(width: spacing.sm),
                        AppIconButton(
                          key: const Key('movie-player-clip-selection-toggle'),
                          tooltip: widget.clipSelectionMode ? '退出切片圈选' : '圈选切片',
                          isSelected: widget.clipSelectionMode,
                          selectedIconColor:
                              Theme.of(context).colorScheme.primary,
                          onPressed: widget.onToggleClipSelectionMode,
                          icon: Icon(
                            Icons.content_cut_rounded,
                            size: context.appComponentTokens.iconSizeSm,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (widget.clipSelectionMode) ...[
                SizedBox(height: spacing.sm),
                ClipSelectionStatusBar(
                  keyPrefix: 'movie-player',
                  startSeconds: widget.clipStartSeconds,
                  endSeconds: widget.clipEndSeconds,
                  durationSeconds: widget.clipDurationSeconds,
                  canCreate: widget.canCreateClip,
                  onCreate: widget.onCreateClip,
                  onClear: widget.onClearClipSelection,
                ),
              ],
              SizedBox(height: spacing.md),
              Expanded(
                child: MovieMediaThumbnailGrid(
                  thumbnails: widget.thumbnails,
                  isLoading: widget.isLoading,
                  errorMessage: widget.errorMessage,
                  columns: resolvedColumns,
                  activeIndex: widget.activeIndex,
                  isScrollLocked: widget.isScrollLocked,
                  onThumbnailTap: widget.onThumbnailTap,
                  onRetry: widget.onRetry,
                  onThumbnailMenuRequested: widget.onThumbnailMenuRequested,
                  clipStartIndex: widget.clipStartIndex,
                  clipEndIndex: widget.clipEndIndex,
                  keyPrefix: 'movie-player',
                  layout: widget.layout,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

