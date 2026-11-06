import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/movies/presentation/widgets/detail/movie_plot_preview_overlay.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_detail_thumbnail_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_glass_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/grids/grid_column_resolver.dart';
import 'package:sakuramedia/widgets/base/navigation/app_glass_list_header.dart';
import 'package:sakuramedia/widgets/base/overlays/app_bottom_drawer.dart';
import 'package:sakuramedia/widgets/domain/clips/clip_selection_status_bar.dart';
import 'package:sakuramedia/widgets/domain/media/movie_media_thumbnail_grid.dart';

/// 媒体缩略图页签内容。
///
/// JAV 详情和 PornBox 视频缩略图页共用这套时间间隔、列数、切片圈选、预览
/// 和图片菜单交互；远端加载与具体动作由调用方负责。
class MediaThumbnailTab extends ConsumerWidget {
  static const List<int> _intervalOptions = <int>[10, 20, 30, 60];
  static const List<int> _columnOptions = <int>[2, 3, 4, 5];

  /// 窄于此宽度时工具条收成单行紧凑入口（完整 chips 铺开约需 464pt，
  /// 移动端底抽屉会折成两行；桌面弹窗 960pt 与宽窗保持 chips 不变）。
  static const double _compactToolbarWidthThreshold = 600;

  const MediaThumbnailTab({
    super.key,
    required this.mediaId,
    required this.thumbnailPreviewPresentation,
    this.onThumbnailMenuRequested,
    this.onCreateClip,
    this.keyPrefix = 'movie-detail-thumbnail',
    this.glassChrome = false,
  });

  final int? mediaId;
  final MoviePlotPreviewPresentation thumbnailPreviewPresentation;
  final void Function(int index, Offset globalPosition)?
  onThumbnailMenuRequested;
  final VoidCallback? onCreateClip;
  final String keyPrefix;

  /// 移动端 PornBox 缩略图页：时间间隔、列数和剪刀入口使用液态玻璃分组。
  final bool glassChrome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movieDetailThumbnailProvider(mediaId: mediaId));
    final controller = ref.read(
      movieDetailThumbnailProvider(mediaId: mediaId).notifier,
    );
    final thumbnails = state.thumbnails;

    return LayoutBuilder(
      builder: (context, constraints) {
        final autoColumns = resolveGridColumnCount(
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
              if (constraints.maxWidth < _compactToolbarWidthThreshold)
                _MediaThumbnailCompactToolbar(
                  key: Key('$keyPrefix-toolbar'),
                  keyPrefix: keyPrefix,
                  selectedIntervalSeconds: state.selectedIntervalSeconds,
                  selectedColumns: resolvedColumns,
                  onSelectInterval: controller.setIntervalSeconds,
                  onSelectColumns: controller.setColumns,
                  clipSelectionMode: state.clipSelectionMode,
                  onToggleClipSelectionMode: onCreateClip == null
                      ? null
                      : controller.toggleClipSelectionMode,
                  glassChrome: glassChrome,
                )
              else
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
                        tooltip: state.clipSelectionMode
                            ? AppLocalizations.of(
                                context,
                              ).widgetMediaClipSelectionExit
                            : AppLocalizations.of(
                                context,
                              ).widgetMediaClipSelectionEnter,
                        isSelected: state.clipSelectionMode,
                        size: AppIconButtonSize.mini,
                        selectedIconColor: Theme.of(
                          context,
                        ).colorScheme.primary,
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
    final l10n = AppLocalizations.of(context);
    return _MediaThumbnailControlGroup(
      key: Key('$keyPrefix-interval-group'),
      iconKey: Key('$keyPrefix-interval-icon'),
      icon: Icons.schedule_rounded,
      tooltip: l10n.widgetMediaThumbnailInterval,
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
    final l10n = AppLocalizations.of(context);
    return _MediaThumbnailControlGroup(
      key: Key('$keyPrefix-columns-group'),
      iconKey: Key('$keyPrefix-columns-icon'),
      icon: Icons.grid_view_rounded,
      tooltip: l10n.widgetMediaThumbnailColumns,
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

/// 窄屏工具条：两个「图标 + 当前值 + 下拉箭头」入口 + 右对齐的剪刀按钮。
///
/// 入口复用移动筛选图标钮（常驻无底色），点击开小号
/// 底部抽屉选择，即时生效；比一行 chips 少一行高度，选项再多也不变高。
class _MediaThumbnailCompactToolbar extends StatelessWidget {
  const _MediaThumbnailCompactToolbar({
    super.key,
    required this.keyPrefix,
    required this.selectedIntervalSeconds,
    required this.selectedColumns,
    required this.onSelectInterval,
    required this.onSelectColumns,
    required this.clipSelectionMode,
    this.onToggleClipSelectionMode,
    this.glassChrome = false,
  });

  final String keyPrefix;
  final int selectedIntervalSeconds;
  final int selectedColumns;
  final ValueChanged<int> onSelectInterval;
  final ValueChanged<int> onSelectColumns;
  final bool clipSelectionMode;
  final VoidCallback? onToggleClipSelectionMode;
  final bool glassChrome;

  Future<void> _pickInterval(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final value = await _showThumbnailOptionDrawer(
      context: context,
      drawerKey: Key('$keyPrefix-interval-drawer'),
      title: l10n.widgetMediaThumbnailInterval,
      options: MediaThumbnailTab._intervalOptions,
      selectedValue: selectedIntervalSeconds,
      optionLabelBuilder: (seconds) =>
          l10n.widgetMediaThumbnailSeconds(seconds),
      optionKeyBuilder: (seconds) => Key('$keyPrefix-interval-option-$seconds'),
    );
    if (value != null) {
      onSelectInterval(value);
    }
  }

  Future<void> _pickColumns(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final value = await _showThumbnailOptionDrawer(
      context: context,
      drawerKey: Key('$keyPrefix-columns-drawer'),
      title: l10n.widgetMediaThumbnailColumns,
      options: MediaThumbnailTab._columnOptions,
      selectedValue: selectedColumns,
      optionLabelBuilder: (columns) =>
          l10n.widgetMediaThumbnailColumnCount(columns),
      optionKeyBuilder: (columns) => Key('$keyPrefix-columns-option-$columns'),
    );
    if (value != null) {
      onSelectColumns(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (glassChrome) {
      return SizedBox(
        height: AppGlassHeaderGroup.height,
        child: Row(
          children: [
            AppGlassHeaderGroup(
              children: <Widget>[
                AppGlassHeaderButton(
                  key: Key('$keyPrefix-interval-trigger'),
                  icon: Icons.schedule_rounded,
                  label: l10n.widgetMediaThumbnailSecondsCompact(
                    selectedIntervalSeconds,
                  ),
                  trailingIcon: Icons.expand_more_rounded,
                  tooltip: l10n.widgetMediaThumbnailInterval,
                  onTap: () => unawaited(_pickInterval(context)),
                ),
                AppGlassHeaderButton(
                  key: Key('$keyPrefix-columns-trigger'),
                  icon: Icons.grid_view_rounded,
                  label: l10n.widgetMediaThumbnailColumnCountCompact(
                    selectedColumns,
                  ),
                  trailingIcon: Icons.expand_more_rounded,
                  tooltip: l10n.widgetMediaThumbnailColumns,
                  onTap: () => unawaited(_pickColumns(context)),
                ),
              ],
            ),
            const Spacer(),
            if (onToggleClipSelectionMode != null)
              AppGlassIconButton(
                key: Key('$keyPrefix-clip-toggle'),
                tooltip: clipSelectionMode
                    ? l10n.widgetMediaClipSelectionExit
                    : l10n.widgetMediaClipSelectionEnter,
                icon: Icons.content_cut_rounded,
                iconSize: context.appComponentTokens.iconSizeMd,
                foregroundColor: clipSelectionMode
                    ? Theme.of(context).colorScheme.primary
                    : null,
                onPressed: onToggleClipSelectionMode,
              ),
          ],
        ),
      );
    }
    return SizedBox(
      height: context.appComponentTokens.buttonHeightXs,
      child: Row(
        children: [
          AppTextButton(
            key: Key('$keyPrefix-interval-trigger'),
            label: l10n.widgetMediaThumbnailSecondsCompact(
              selectedIntervalSeconds,
            ),
            icon: const Icon(Icons.schedule_rounded),
            size: AppTextButtonSize.xSmall,
            onPressed: () => unawaited(_pickInterval(context)),
          ),
          SizedBox(width: context.appSpacing.sm),
          AppTextButton(
            key: Key('$keyPrefix-columns-trigger'),
            label: l10n.widgetMediaThumbnailColumnCountCompact(selectedColumns),
            icon: const Icon(Icons.grid_view_rounded),
            size: AppTextButtonSize.xSmall,
            onPressed: () => unawaited(_pickColumns(context)),
          ),
          const Spacer(),
          if (onToggleClipSelectionMode != null)
            AppIconButton(
              key: Key('$keyPrefix-clip-toggle'),
              tooltip: clipSelectionMode
                  ? l10n.widgetMediaClipSelectionExit
                  : l10n.widgetMediaClipSelectionEnter,
              isSelected: clipSelectionMode,
              size: AppIconButtonSize.mini,
              selectedIconColor: Theme.of(context).colorScheme.primary,
              onPressed: onToggleClipSelectionMode,
              icon: const Icon(Icons.content_cut_rounded),
            ),
        ],
      ),
    );
  }
}

Future<int?> _showThumbnailOptionDrawer({
  required BuildContext context,
  required Key drawerKey,
  required String title,
  required List<int> options,
  required int selectedValue,
  required String Function(int value) optionLabelBuilder,
  required Key Function(int value) optionKeyBuilder,
}) {
  return showAppBottomDrawer<int>(
    context: context,
    drawerKey: drawerKey,
    maxHeightFactor: 0.4,
    ignoreTopSafeArea: true,
    contentPadding: EdgeInsets.zero,
    builder: (_) => _MediaThumbnailOptionDrawer(
      title: title,
      options: options,
      selectedValue: selectedValue,
      optionLabelBuilder: optionLabelBuilder,
      optionKeyBuilder: optionKeyBuilder,
    ),
  );
}

class _MediaThumbnailOptionDrawer extends StatelessWidget {
  const _MediaThumbnailOptionDrawer({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.optionLabelBuilder,
    required this.optionKeyBuilder,
  });

  static const double _topSpacing = 20;

  final String title;
  final List<int> options;
  final int selectedValue;
  final String Function(int value) optionLabelBuilder;
  final Key Function(int value) optionKeyBuilder;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              spacing.lg,
              _topSpacing,
              spacing.lg,
              spacing.sm,
            ),
            child: Text(
              title,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s16,
                weight: AppTextWeight.semibold,
                tone: AppTextTone.primary,
              ),
            ),
          ),
          for (final option in options)
            _MediaThumbnailOptionRow(
              key: optionKeyBuilder(option),
              label: optionLabelBuilder(option),
              isSelected: option == selectedValue,
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );
  }
}

class _MediaThumbnailOptionRow extends StatelessWidget {
  const _MediaThumbnailOptionRow({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  static const double _minHeight = 52;

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: AppInteractiveSurface(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.appSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: resolveAppTextStyle(
                      context,
                      size: AppTextSize.s14,
                      tone: isSelected
                          ? AppTextTone.accent
                          : AppTextTone.primary,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    size: context.appComponentTokens.iconSizeSm,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
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
