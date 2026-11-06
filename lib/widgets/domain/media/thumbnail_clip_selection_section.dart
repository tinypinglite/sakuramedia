import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/thumbnails/movie_media_thumbnail_dto.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_selection_status_bar.dart';
import 'package:sakuramedia/widgets/domain/media/movie_media_thumbnail_grid.dart';

typedef ThumbnailSectionToolbarBuilder =
    Widget Function(BuildContext context, int columns, double width);

/// 缩略图网格与圈选状态栏的公共布局。
///
/// 自动列数、回写、状态栏和网格参数只维护一份；调用方通过
/// [toolbarBuilder] 提供自己的工具条，不传时使用播放器列数/滚动锁工具条。
class ThumbnailClipSelectionSection extends StatelessWidget {
  const ThumbnailClipSelectionSection({
    super.key,
    required this.thumbnails,
    required this.isLoading,
    required this.errorMessage,
    required this.columns,
    required this.usesAutoColumns,
    this.onAutoColumnsResolved,
    required this.activeIndex,
    this.isScrollLocked = false,
    required this.onThumbnailTap,
    required this.onRetry,
    this.onThumbnailMenuRequested,
    required this.onColumnsChanged,
    this.onToggleScrollLock,
    this.onToggleClipSelectionMode,
    this.controlsAlignment = Alignment.centerLeft,
    this.clipSelectionMode = false,
    this.clipStartIndex,
    this.clipEndIndex,
    this.clipStartSeconds,
    this.clipEndSeconds,
    this.clipDurationSeconds,
    this.canCreateClip = false,
    this.onCreateClip,
    this.onClearClipSelection,
    this.keyPrefix = 'movie-player',
    this.layout = ThumbnailGridLayout.uniform16x9,
    this.spacing,
    this.gridGap,
    this.padding,
    this.toolbarBuilder,
  });

  final List<MovieMediaThumbnailDto> thumbnails;
  final bool isLoading;
  final String? errorMessage;
  final int? columns;
  final int? activeIndex;
  final bool isScrollLocked;
  final bool usesAutoColumns;

  /// 运行时解析出的自动列数回调；不需要把自动列数写回状态的调用方可以省略。
  final ValueChanged<int>? onAutoColumnsResolved;
  final ValueChanged<int> onThumbnailTap;
  final VoidCallback onRetry;
  final void Function(int index, Offset globalPosition)?
  onThumbnailMenuRequested;
  final ValueChanged<int> onColumnsChanged;
  final VoidCallback? onToggleScrollLock;
  final VoidCallback? onToggleClipSelectionMode;
  final Alignment controlsAlignment;
  final bool clipSelectionMode;
  final int? clipStartIndex;
  final int? clipEndIndex;
  final int? clipStartSeconds;
  final int? clipEndSeconds;
  final int? clipDurationSeconds;
  final bool canCreateClip;
  final VoidCallback? onCreateClip;
  final VoidCallback? onClearClipSelection;
  final String keyPrefix;

  /// 网格布局；默认统一 16:9，合集连播页可传瀑布流。
  final ThumbnailGridLayout layout;

  /// 列数计算与网格间距；null 时用主题 `appSpacing.xs`。
  final double? spacing;

  /// 状态栏与网格之间的间距；null 时用主题 `appSpacing.sm`。
  final double? gridGap;
  final EdgeInsets? padding;
  final ThumbnailSectionToolbarBuilder? toolbarBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = this.spacing ?? context.appSpacing.xs;
        final autoColumns = resolveGridColumnCount(
          width: constraints.maxWidth,
          spacing: spacing,
          targetWidth: context.appComponentTokens.movieThumbnailTargetWidth,
        );
        final resolvedColumns = usesAutoColumns
            ? autoColumns
            : (columns ?? autoColumns);
        final onAutoColumnsResolved = this.onAutoColumnsResolved;
        if (usesAutoColumns &&
            columns != autoColumns &&
            onAutoColumnsResolved != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              onAutoColumnsResolved(autoColumns);
            }
          });
        }

        return Padding(
          padding: padding ?? EdgeInsets.all(context.appSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildToolbar(context, resolvedColumns, constraints.maxWidth),
              if (clipSelectionMode) ...[
                SizedBox(height: context.appSpacing.sm),
                ClipSelectionStatusBar(
                  keyPrefix: keyPrefix,
                  startSeconds: clipStartSeconds,
                  endSeconds: clipEndSeconds,
                  durationSeconds: clipDurationSeconds,
                  canCreate: canCreateClip,
                  onCreate: onCreateClip,
                  onClear: onClearClipSelection,
                ),
              ],
              SizedBox(height: gridGap ?? context.appSpacing.sm),
              Expanded(
                child: MovieMediaThumbnailGrid(
                  thumbnails: thumbnails,
                  isLoading: isLoading,
                  errorMessage: errorMessage,
                  columns: resolvedColumns,
                  activeIndex: activeIndex,
                  isScrollLocked: isScrollLocked,
                  onRetry: onRetry,
                  onThumbnailMenuRequested: onThumbnailMenuRequested,
                  clipStartIndex: clipStartIndex,
                  clipEndIndex: clipEndIndex,
                  keyPrefix: keyPrefix,
                  layout: layout,
                  spacing: spacing,
                  onThumbnailTap: onThumbnailTap,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToolbar(BuildContext context, int columns, double width) {
    final toolbarBuilder = this.toolbarBuilder;
    if (toolbarBuilder != null) {
      return toolbarBuilder(context, columns, width);
    }

    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: controlsAlignment,
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
                isSelected: columns == count,
                onPressed: () => onColumnsChanged(count),
              ),
            ],
            SizedBox(width: spacing.sm),
            if (onToggleScrollLock != null)
              AppIconButton(
                key: const Key('movie-player-scroll-lock-toggle'),
                tooltip: isScrollLocked
                    ? l10n.widgetMediaScrollLockEnabled
                    : l10n.widgetMediaScrollLockDisabled,
                isSelected: isScrollLocked,
                selectedIconColor: Theme.of(context).colorScheme.primary,
                onPressed: onToggleScrollLock,
                icon: Icon(
                  isScrollLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: context.appComponentTokens.iconSizeSm,
                ),
              ),
            if (onToggleClipSelectionMode != null) ...[
              SizedBox(width: spacing.sm),
              AppIconButton(
                key: const Key('movie-player-clip-selection-toggle'),
                tooltip: clipSelectionMode
                    ? l10n.widgetMediaClipSelectionExit
                    : l10n.widgetMediaClipSelectionEnter,
                isSelected: clipSelectionMode,
                selectedIconColor: Theme.of(context).colorScheme.primary,
                onPressed: onToggleClipSelectionMode,
                icon: Icon(
                  Icons.content_cut_rounded,
                  size: context.appComponentTokens.iconSizeSm,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
