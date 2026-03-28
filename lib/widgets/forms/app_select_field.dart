import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sakuramedia/theme.dart';

const double _kAppSelectItemHeight = 40;
const double _kAppSelectMenuGap = 4;
const double _kAppSelectMenuMaxHeight = 240;
const double _kAppSelectTriggerCompactHeight = 36;

enum AppSelectFieldSize { regular, compact }

class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.label,
    this.validator,
    this.placeholder,
    this.size = AppSelectFieldSize.regular,
    this.textStyle,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final String? label;
  final FormFieldValidator<T>? validator;
  final String? placeholder;
  final AppSelectFieldSize size;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      key: ValueKey<Object?>(value),
      initialValue: value,
      validator: validator,
      builder: (field) {
        return _AppSelectTrigger<T>(
          label: label,
          value: field.value,
          items: items,
          placeholder: placeholder ?? '请选择',
          errorText: field.errorText,
          size: size,
          textStyle: textStyle,
          enabled: onChanged != null,
          onSelected: (nextValue) {
            field.didChange(nextValue);
            onChanged?.call(nextValue);
          },
        );
      },
    );
  }
}

class _AppSelectTrigger<T> extends StatefulWidget {
  const _AppSelectTrigger({
    required this.items,
    required this.placeholder,
    required this.onSelected,
    required this.enabled,
    required this.size,
    required this.textStyle,
    this.label,
    this.value,
    this.errorText,
  });

  final List<DropdownMenuItem<T>> items;
  final String placeholder;
  final ValueChanged<T?> onSelected;
  final bool enabled;
  final AppSelectFieldSize size;
  final TextStyle? textStyle;
  final String? label;
  final T? value;
  final String? errorText;

  @override
  State<_AppSelectTrigger<T>> createState() => _AppSelectTriggerState<T>();
}

class _AppSelectTriggerState<T> extends State<_AppSelectTrigger<T>> {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  bool _isMenuOpen = false;
  double _triggerWidth = 0;
  double _triggerHeight = 0;
  double _menuHeight = 0;
  _AppSelectMenuPlacement _placement = _AppSelectMenuPlacement.down;

  @override
  void dispose() {
    _removeOverlay(notify: false);
    super.dispose();
  }

  void _toggleMenu() {
    if (!widget.enabled) {
      return;
    }
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }

    _showOverlay();
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    if (triggerBox == null) {
      return;
    }

    _triggerWidth = triggerBox.size.width;
    _triggerHeight = triggerBox.size.height;

    final triggerOffset = triggerBox.localToGlobal(Offset.zero);
    final triggerBottom = triggerOffset.dy + _triggerHeight;
    final spaceAbove = triggerOffset.dy;
    final view = View.of(context);
    final viewportHeight = view.physicalSize.height / view.devicePixelRatio;
    final spaceBelow = viewportHeight - triggerBottom;
    final idealMenuHeight = math.min(
      widget.items.length * _kAppSelectItemHeight,
      _kAppSelectMenuMaxHeight,
    );
    final opensUpward =
        triggerBottom + idealMenuHeight + _kAppSelectMenuGap > viewportHeight &&
        spaceAbove > _kAppSelectItemHeight;
    final availableSpace =
        (opensUpward ? spaceAbove : spaceBelow) - _kAppSelectMenuGap;
    final constrainedHeight = math.max(
      _kAppSelectItemHeight,
      math.min(idealMenuHeight, availableSpace),
    );

    _placement =
        opensUpward ? _AppSelectMenuPlacement.up : _AppSelectMenuPlacement.down;
    _menuHeight = constrainedHeight.toDouble();

    setState(() {
      _isMenuOpen = true;
    });

    _overlayEntry = OverlayEntry(
      builder: (context) {
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
              offset: Offset(
                0,
                _placement == _AppSelectMenuPlacement.down
                    ? _triggerHeight + _kAppSelectMenuGap
                    : -(_menuHeight + _kAppSelectMenuGap),
              ),
              child: Material(
                color: Colors.transparent,
                child: _AppSelectMenu<T>(
                  width: _triggerWidth,
                  height: _menuHeight,
                  items: widget.items,
                  selectedValue: widget.value,
                  textStyle: widget.textStyle,
                  onSelected: (value) {
                    widget.onSelected(value);
                    _removeOverlay();
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay({bool notify = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (!notify || !mounted) {
      return;
    }
    setState(() {
      _isMenuOpen = false;
    });
  }

  DropdownMenuItem<T>? _selectedItem() {
    for (final item in widget.items) {
      if (item.value == widget.value) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor =
        hasError ? theme.colorScheme.error : colors.borderSubtle;
    final selectedItem = _selectedItem();
    final displayChild =
        selectedItem?.child ??
        Text(widget.placeholder, overflow: TextOverflow.ellipsis);
    final textColor =
        selectedItem == null ? colors.textMuted : colors.textPrimary;
    final fontWeight = selectedItem == null ? FontWeight.w500 : FontWeight.w600;
    final isCompact = widget.size == AppSelectFieldSize.compact;
    final baseTextStyle = widget.textStyle ?? theme.textTheme.bodyMedium!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && widget.label!.isNotEmpty) ...[
          Text(
            widget.label!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.appSpacing.sm),
        ],
        MouseRegion(
          cursor:
              widget.enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
          child: CompositedTransformTarget(
            link: _layerLink,
            child: GestureDetector(
              onTap: _toggleMenu,
              child: AnimatedContainer(
                key: _triggerKey,
                duration: const Duration(milliseconds: 120),
                width: double.infinity,
                height: isCompact ? _kAppSelectTriggerCompactHeight : null,
                padding: EdgeInsets.symmetric(
                  horizontal: context.appSpacing.lg,
                  vertical: isCompact ? 0 : 14,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: context.appRadius.smBorder,
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DefaultTextStyle(
                        style: baseTextStyle.copyWith(
                          color: textColor,
                          fontWeight: fontWeight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: displayChild,
                      ),
                    ),
                    SizedBox(width: context.appSpacing.sm),
                    Icon(
                      _isMenuOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: context.appComponentTokens.iconSizeSm,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          SizedBox(height: context.appSpacing.xs),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

enum _AppSelectMenuPlacement { up, down }

class _AppSelectMenu<T> extends StatelessWidget {
  const _AppSelectMenu({
    required this.width,
    required this.height,
    required this.items,
    required this.onSelected,
    required this.textStyle,
    this.selectedValue,
  });

  final double width;
  final double height;
  final List<DropdownMenuItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T?> onSelected;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: context.appRadius.smBorder,
        border: Border.all(color: colors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: context.appRadius.smBorder,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items
                .map(
                  (item) => _AppSelectMenuItem<T>(
                    selected: item.value == selectedValue,
                    textStyle: textStyle,
                    child: item.child,
                    onTap: () {
                      onSelected(item.value);
                    },
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ),
    );
  }
}

class _AppSelectMenuItem<T> extends StatefulWidget {
  const _AppSelectMenuItem({
    required this.child,
    required this.onTap,
    required this.selected,
    required this.textStyle,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool selected;
  final TextStyle? textStyle;

  @override
  State<_AppSelectMenuItem<T>> createState() => _AppSelectMenuItemState<T>();
}

class _AppSelectMenuItemState<T> extends State<_AppSelectMenuItem<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final baseTextStyle = widget.textStyle ?? theme.textTheme.bodyMedium!;
    final backgroundColor =
        widget.selected
            ? colors.surfaceMuted
            : _isHovered
            ? colors.sidebarHoverBackground
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: _kAppSelectItemHeight,
          padding: EdgeInsets.symmetric(horizontal: context.appSpacing.lg),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: backgroundColor),
          child: DefaultTextStyle(
            style: baseTextStyle.copyWith(
              color: colors.textPrimary,
              fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
