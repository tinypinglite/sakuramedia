import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_anchored_menu.dart';

enum AppSelectFieldSize { regular, compact, mini }

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
    final l10n = appL10n(context);
    final formTokens = context.appFormTokens;
    final menuItemHeight = switch (size) {
      AppSelectFieldSize.mini => formTokens.miniMenuItemHeight,
      AppSelectFieldSize.regular ||
      AppSelectFieldSize.compact => formTokens.menuItemHeight,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = constraints.hasBoundedWidth
            ? math.max(constraints.maxWidth, 160.0)
            : 240.0;
        return FormField<T>(
          key: ValueKey<Object?>(value),
          initialValue: value,
          validator: validator,
          builder: (field) {
            final selectedValue = field.value;
            return AppGlassAnchoredMenu(
              width: menuWidth,
              minWidth: 160,
              maxWidth: menuWidth,
              estimatedHeight: items.length * menuItemHeight,
              maxHeight: formTokens.menuMaxHeight,
              borderRadius: context.appRadius.smBorder,
              triggerBuilder: (context, isOpen, toggle) => _AppSelectTrigger<T>(
                label: label,
                value: selectedValue,
                items: items,
                placeholder: placeholder ?? l10n.baseSelectPlaceholder,
                errorText: field.errorText,
                size: size,
                textStyle: textStyle,
                enabled: onChanged != null,
                isOpen: isOpen,
                onTap: toggle,
              ),
              contentBuilder: (context, close) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final item in items)
                    AppGlassMenuRow(
                      key: item.key,
                      title: item.child,
                      selected: item.value == selectedValue,
                      showCheckmark: true,
                      enabled: item.enabled && onChanged != null,
                      onTap: () {
                        field.didChange(item.value);
                        onChanged?.call(item.value);
                        close();
                      },
                      minHeight: menuItemHeight,
                      padding: EdgeInsets.symmetric(
                        horizontal: formTokens.fieldHorizontalPadding,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AppSelectTrigger<T> extends StatelessWidget {
  const _AppSelectTrigger({
    required this.items,
    required this.placeholder,
    required this.enabled,
    required this.size,
    required this.textStyle,
    required this.isOpen,
    required this.onTap,
    this.label,
    this.value,
    this.errorText,
  });

  final List<DropdownMenuItem<T>> items;
  final String placeholder;
  final bool enabled;
  final AppSelectFieldSize size;
  final TextStyle? textStyle;
  final bool isOpen;
  final VoidCallback onTap;
  final String? label;
  final T? value;
  final String? errorText;

  DropdownMenuItem<T>? _selectedItem() {
    for (final item in items) {
      if (item.value == value) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;
    final selectedItem = _selectedItem();
    final displayChild = selectedItem == null
        ? Text(placeholder, overflow: TextOverflow.ellipsis)
        : _buildTriggerDisplayChild(selectedItem);
    final baseTextStyle =
        textStyle ??
        resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: AppTextWeight.regular,
          tone: AppTextTone.primary,
        );
    final formTokens = context.appFormTokens;
    final triggerHeight = switch (size) {
      AppSelectFieldSize.regular => null,
      AppSelectFieldSize.compact => formTokens.compactFieldHeight,
      AppSelectFieldSize.mini => formTokens.miniFieldHeight,
    };
    final horizontalPadding = switch (size) {
      AppSelectFieldSize.mini => formTokens.miniFieldHorizontalPadding,
      AppSelectFieldSize.regular ||
      AppSelectFieldSize.compact => formTokens.fieldHorizontalPadding,
    };
    final verticalPadding = switch (size) {
      AppSelectFieldSize.regular => formTokens.fieldVerticalPadding,
      AppSelectFieldSize.compact || AppSelectFieldSize.mini => 0.0,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null && label!.isNotEmpty) ...[
          Text(
            label!,
            softWrap: true,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.secondary,
            ),
          ),
          SizedBox(height: formTokens.labelGap),
        ],
        AppInteractiveSurface(
          enabled: enabled,
          onTap: enabled ? onTap : null,
          focusRingRadius: context.appRadius.smBorder,
          child: Builder(
            builder: (context) {
              Widget surface = AppSurface(
                width: double.infinity,
                height: triggerHeight,
                borderRadius: context.appRadius.smBorder,
                role: AppSurfaceRole.control,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _AppSelectText(
                        style: _resolveSelectTextStyle(
                          context,
                          baseStyle: baseTextStyle,
                          fallbackSize: AppTextSize.s14,
                          tone: selectedItem == null
                              ? AppTextTone.muted
                              : AppTextTone.primary,
                        ),
                        child: displayChild,
                      ),
                    ),
                    SizedBox(width: context.appSpacing.sm),
                    Icon(
                      isOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: context.appComponentTokens.iconSizeSm,
                      color: context.appTextPalette.secondary,
                    ),
                  ],
                ),
              );
              if (hasError) {
                surface = DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: context.appRadius.smBorder,
                    border: Border.all(color: theme.colorScheme.error),
                  ),
                  child: surface,
                );
              }
              return surface;
            },
          ),
        ),
        if (hasError) ...[
          SizedBox(height: context.appSpacing.xs),
          Text(
            errorText!,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.error,
            ),
          ),
        ],
      ],
    );
  }
}

Widget _buildTriggerDisplayChild<T>(DropdownMenuItem<T> item) {
  final label = _textLabelOf(item.child);
  if (label != null) {
    return Text(label, overflow: TextOverflow.ellipsis);
  }
  return item.child;
}

String? _textLabelOf(Widget child) {
  if (child is! Text) {
    return null;
  }
  if (child.data != null) {
    return child.data;
  }
  return child.textSpan?.toPlainText();
}

class _AppSelectText extends StatelessWidget {
  const _AppSelectText({required this.style, required this.child});

  final TextStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mergedStyle = DefaultTextStyle.of(context).style.merge(style);
    final label = _textLabelOf(child);
    if (label != null) {
      return Text(
        label,
        style: mergedStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return DefaultTextStyle(
      style: mergedStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: child,
    );
  }
}

TextStyle _resolveSelectTextStyle(
  BuildContext context, {
  required TextStyle? baseStyle,
  required AppTextSize fallbackSize,
  required AppTextTone tone,
}) {
  if (baseStyle != null) {
    return baseStyle.copyWith(color: resolveAppTextToneColor(context, tone));
  }
  return resolveAppTextStyle(context, size: fallbackSize, tone: tone);
}
