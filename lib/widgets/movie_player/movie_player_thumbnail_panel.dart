import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/data/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/actions/app_text_button.dart';
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
              Row(
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
                    tooltip: widget.isScrollLocked ? '锁定跟随播放位置' : '允许手动滚动缩略图',
                    isSelected: widget.isScrollLocked,
                    selectedIconColor: Theme.of(context).colorScheme.primary,
                    onPressed: widget.onToggleScrollLock,
                    icon: Icon(
                      widget.isScrollLocked
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      size: context.appComponentTokens.iconSizeSm,
                    ),
                  ),
                ],
              ),
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
                  keyPrefix: 'movie-player',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
