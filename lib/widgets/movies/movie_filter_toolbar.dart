import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/movie_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/actions/app_button.dart';

class MovieFilterToolbar extends StatefulWidget {
  const MovieFilterToolbar({
    super.key,
    required this.filterState,
    required this.onChanged,
    required this.onReset,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onChanged;
  final VoidCallback onReset;

  @override
  State<MovieFilterToolbar> createState() => _MovieFilterToolbarState();
}

class _MovieFilterToolbarState extends State<MovieFilterToolbar> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _overlayRebuildScheduled = false;
  Size _triggerSize = const Size(160, 36);
  Offset _triggerOffsetInOverlay = Offset.zero;

  @override
  void didUpdateWidget(covariant MovieFilterToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleOverlayRebuild();
  }

  @override
  void dispose() {
    _removeOverlay(updateState: false);
    super.dispose();
  }

  void _togglePanel() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _updateTriggerMetrics();
    _isOpen = true;
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => _buildOverlay(overlayContext),
    );
    Overlay.of(context).insert(_overlayEntry!);
    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleOverlayRebuild() {
    if (!_isOpen || _overlayEntry == null || _overlayRebuildScheduled) {
      return;
    }
    _overlayRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overlayRebuildScheduled = false;
      if (!mounted || !_isOpen) {
        return;
      }
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _updateTriggerMetrics() {
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (triggerBox != null) {
      _triggerSize = triggerBox.size;
    }
  }

  RenderBox? _updateTriggerMetricsForOverlay(BuildContext overlayContext) {
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayState = Overlay.maybeOf(overlayContext);
    final overlayBox = overlayState?.context.findRenderObject() as RenderBox?;

    if (triggerBox != null) {
      _triggerSize = triggerBox.size;
    }
    if (triggerBox != null && overlayBox != null) {
      _triggerOffsetInOverlay = triggerBox.localToGlobal(
        Offset.zero,
        ancestor: overlayBox,
      );
    }
    return overlayBox;
  }

  void _removeOverlay({bool updateState = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _overlayRebuildScheduled = false;
    if (updateState && _isOpen && mounted) {
      setState(() {
        _isOpen = false;
      });
      return;
    }
    _isOpen = false;
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final overlayBox = _updateTriggerMetricsForOverlay(overlayContext);
    final mediaQuery = MediaQuery.of(overlayContext);
    final overlayWidth = overlayBox?.size.width ?? mediaQuery.size.width;
    final desiredWidth = _triggerSize.width + 260;
    final panelWidth =
        desiredWidth.clamp(_triggerSize.width, overlayWidth).toDouble();
    final leftSpace = _triggerOffsetInOverlay.dx;
    final rightAlignedOffset =
        -((panelWidth - _triggerSize.width).clamp(0, leftSpace)).toDouble();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _removeOverlay,
            child: const SizedBox.expand(),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(rightAlignedOffset, _triggerSize.height + 8),
          child: Material(
            color: Colors.transparent,
            child: Container(
              key: const Key('movies-filter-panel'),
              width: panelWidth,
              padding: EdgeInsets.all(context.appSpacing.lg),
              decoration: BoxDecoration(
                color: context.appColors.surfaceCard,
                borderRadius: context.appRadius.mdBorder,
                border: Border.all(color: context.appColors.borderSubtle),
                boxShadow: context.appShadows.panel,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterSection<MovieStatusFilter>(
                    title: '状态筛选',
                    options: MovieStatusFilter.values,
                    selectedValue: widget.filterState.status,
                    labelBuilder: (value) => value.label,
                    onSelected:
                        (value) => widget.onChanged(
                          widget.filterState.copyWith(status: value),
                        ),
                  ),
                  SizedBox(height: context.appSpacing.lg),
                  _FilterSection<MovieCollectionTypeFilter>(
                    title: '合集类型',
                    options: MovieCollectionTypeFilter.values,
                    selectedValue: widget.filterState.collectionType,
                    labelBuilder: (value) => value.label,
                    onSelected:
                        (value) => widget.onChanged(
                          widget.filterState.copyWith(collectionType: value),
                        ),
                  ),
                  SizedBox(height: context.appSpacing.lg),
                  _SortSection(
                    filterState: widget.filterState,
                    onSortFieldChanged:
                        (value) => widget.onChanged(
                          widget.filterState.copyWith(sortField: value),
                        ),
                    onSortDirectionChanged:
                        (value) => widget.onChanged(
                          widget.filterState.copyWith(sortDirection: value),
                        ),
                  ),
                  SizedBox(height: context.appSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.filterState.isDefault ? '当前使用默认筛选' : '筛选已即时生效',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                      AppButton(
                        label: '重置',
                        size: AppButtonSize.xSmall,
                        variant: AppButtonVariant.secondary,
                        onPressed:
                            widget.filterState.isDefault
                                ? null
                                : widget.onReset,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: context.appSpacing.sm,
      runSpacing: context.appSpacing.sm,
      children: [
        CompositedTransformTarget(
          link: _layerLink,
          child: AppButton(
            key: _triggerKey,
            label: widget.filterState.triggerLabel,
            labelKey: const Key('movies-filter-trigger-label'),
            icon: const Icon(Icons.filter_alt_outlined),
            trailingIcon: Icon(_isOpen ? Icons.expand_less : Icons.expand_more),
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            isSelected: !widget.filterState.isDefault || _isOpen,
            onPressed: _togglePanel,
          ),
        ),
        for (final preset in MovieFilterPreset.values)
          AppButton(
            key: Key('movies-filter-preset-${preset.key}'),
            label: preset.label,
            variant: AppButtonVariant.secondary,
            size: AppButtonSize.small,
            isSelected: widget.filterState.matchesPreset(preset),
            onPressed: () => widget.onChanged(preset.filterState),
          ),
      ],
    );
  }
}

class _FilterSection<T> extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.labelBuilder,
    required this.onSelected,
  });

  final String title;
  final List<T> options;
  final T selectedValue;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.appColors.textPrimary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        Wrap(
          spacing: context.appSpacing.sm,
          runSpacing: context.appSpacing.sm,
          children: options
              .map(
                (value) => AppButton(
                  label: labelBuilder(value),
                  size: AppButtonSize.xSmall,
                  variant: AppButtonVariant.secondary,
                  isSelected: value == selectedValue,
                  onPressed: () => onSelected(value),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _SortSection extends StatelessWidget {
  const _SortSection({
    required this.filterState,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieSortField> onSortFieldChanged;
  final ValueChanged<SortDirection> onSortDirectionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '排序方式',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.appColors.textPrimary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        Wrap(
          spacing: context.appSpacing.sm,
          runSpacing: context.appSpacing.sm,
          children: MovieSortField.values
              .map(
                (value) => AppButton(
                  label: value.label,
                  size: AppButtonSize.xSmall,
                  variant: AppButtonVariant.secondary,
                  isSelected: value == filterState.sortField,
                  onPressed: () => onSortFieldChanged(value),
                ),
              )
              .toList(growable: false),
        ),
        SizedBox(height: context.appSpacing.md),
        Wrap(
          spacing: context.appSpacing.sm,
          children: SortDirection.values
              .map(
                (value) => AppButton(
                  label: value.label,
                  size: AppButtonSize.xSmall,
                  variant: AppButtonVariant.secondary,
                  isSelected: value == filterState.sortDirection,
                  onPressed: () => onSortDirectionChanged(value),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
