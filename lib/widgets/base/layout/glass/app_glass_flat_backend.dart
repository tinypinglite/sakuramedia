import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_flat_style.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_flat_surface.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_types.dart';

class AppGlassFlatIconButtonBackend extends StatelessWidget {
  const AppGlassFlatIconButtonBackend({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.enabled = true,
    this.width = 44,
    this.height = 44,
    this.iconSize = 20,
    this.iconColor,
    this.prominent = false,
  });

  final Widget icon;
  final VoidCallback onTap;
  final String label;
  final bool enabled;
  final double width;
  final double height;
  final double iconSize;
  final Color? iconColor;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? context.appTextPalette.primary;
    final surface = AppGlassFlatSurface(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(width / 2),
      role: prominent
          ? AppFlatSurfaceRole.buttonProminent
          : AppFlatSurfaceRole.buttonFilled,
      child: AppInteractiveSurface(
        enabled: enabled,
        onTap: enabled ? onTap : null,
        focusRing: false,
        child: Center(
          child: IconTheme(
            data: IconThemeData(size: iconSize, color: color),
            child: icon,
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: enabled ? surface : Opacity(opacity: 0.5, child: surface),
    );
  }
}

class AppGlassFlatCustomButtonBackend extends StatelessWidget {
  const AppGlassFlatCustomButtonBackend({
    super.key,
    required this.child,
    required this.onTap,
    this.label = '',
    this.enabled = true,
    this.width,
    this.height,
    this.borderRadius = 16,
    this.style = AppGlassButtonStyle.filled,
    this.role,
  });

  final Widget child;
  final VoidCallback onTap;
  final String label;
  final bool enabled;
  final double? width;
  final double? height;
  final double borderRadius;
  final AppGlassButtonStyle style;
  final AppFlatSurfaceRole? role;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    Widget body = AppInteractiveSurface(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      focusRing: false,
      child: SizedBox(
        width: width,
        height: height,
        child: Center(child: child),
      ),
    );

    if (style != AppGlassButtonStyle.transparent) {
      body = AppGlassFlatSurface(
        width: width,
        height: height,
        borderRadius: radius,
        role:
            role ??
            (style == AppGlassButtonStyle.prominent
                ? AppFlatSurfaceRole.buttonProminent
                : AppFlatSurfaceRole.buttonFilled),
        child: body,
      );
    }

    if (!enabled) {
      body = Opacity(opacity: 0.5, child: body);
    }

    return Semantics(button: true, enabled: enabled, label: label, child: body);
  }
}

class AppGlassFlatButtonGroupBackend extends StatelessWidget {
  const AppGlassFlatButtonGroupBackend({
    super.key,
    required this.children,
    required this.borderRadius,
    this.showDividers = false,
    this.role = AppFlatSurfaceRole.buttonFilled,
  });

  final List<Widget> children;
  final double borderRadius;
  final bool showDividers;
  final AppFlatSurfaceRole role;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final rowChildren = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (showDividers && index > 0) {
        rowChildren.add(
          SizedBox(
            width: 1,
            height: 16,
            child: ColoredBox(color: context.appColors.borderSubtle),
          ),
        );
      }
      rowChildren.add(children[index]);
    }
    return AppGlassFlatSurface(
      borderRadius: BorderRadius.circular(borderRadius),
      role: role,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: rowChildren,
      ),
    );
  }
}

class AppGlassFlatContainerBackend extends StatelessWidget {
  const AppGlassFlatContainerBackend({
    super.key,
    required this.child,
    required this.borderRadius,
    this.role = AppFlatSurfaceRole.overlay,
  });

  final Widget child;
  final double borderRadius;
  final AppFlatSurfaceRole role;

  @override
  Widget build(BuildContext context) {
    return AppGlassFlatSurface(
      borderRadius: BorderRadius.circular(borderRadius),
      role: role,
      child: child,
    );
  }
}

class AppGlassFlatTextFieldBackend extends StatelessWidget {
  const AppGlassFlatTextFieldBackend({
    super.key,
    required this.controller,
    this.focusNode,
    this.placeholder,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onTapOutside,
    required this.textStyle,
    required this.placeholderStyle,
    this.padding,
    this.iconSpacing = 8,
    this.height,
    this.borderRadius = 12,
    this.enabled = true,
    this.role = AppFlatSurfaceRole.input,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? minLines;
  final bool readOnly;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TapRegionCallback? onTapOutside;
  final TextStyle textStyle;
  final TextStyle placeholderStyle;
  final EdgeInsetsGeometry? padding;
  final double iconSpacing;
  final double? height;
  final double borderRadius;
  final bool enabled;
  final AppFlatSurfaceRole role;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final resolvedPadding = (padding ?? EdgeInsets.zero).resolve(direction);
    final leadingInset = direction == TextDirection.rtl
        ? resolvedPadding.right
        : resolvedPadding.left;
    final trailingInset = direction == TextDirection.rtl
        ? resolvedPadding.left
        : resolvedPadding.right;
    final inputPadding = height == null
        ? (padding ?? EdgeInsets.zero)
        : EdgeInsetsDirectional.only(start: leadingInset, end: trailingInset);
    // InputDecorator 在存在 prefixIcon / suffixIcon 时会忽略 contentPadding
    // 的水平部分，只在图标和输入区之间留一个固定 gap，所以图标内边距要在
    // 图标自身补齐。
    final inputGap = Theme.of(context).useMaterial3 ? 4.0 : 0.0;
    final iconTextGap = math.max(0.0, iconSpacing - inputGap);
    Widget field = Material(
      color: Colors.transparent,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: textStyle,
        cursorColor: Theme.of(context).colorScheme.primary,
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: placeholderStyle,
          prefixIcon: prefixIcon == null
              ? null
              : Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: leadingInset,
                    end: iconTextGap,
                  ),
                  child: prefixIcon,
                ),
          suffixIcon: suffixIcon == null
              ? null
              : Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: iconTextGap,
                    end: trailingInset,
                  ),
                  child: suffixIcon,
                ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          isDense: true,
          contentPadding: inputPadding,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        minLines: minLines,
        readOnly: readOnly,
        enabled: enabled,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTapOutside: onTapOutside,
        textAlignVertical: TextAlignVertical.center,
      ),
    );

    if (height != null) {
      final theme = Theme.of(context);
      field = Theme(
        data: theme.copyWith(
          visualDensity: theme.visualDensity.copyWith(vertical: 0),
        ),
        child: field,
      );
    }

    final content = height == null
        ? field
        : SizedBox(
            height: height,
            child: Center(child: field),
          );

    return AppGlassFlatSurface(
      height: height,
      borderRadius: BorderRadius.circular(borderRadius),
      role: role,
      child: content,
    );
  }
}

class AppGlassFlatSegmentedControlBackend extends StatelessWidget {
  const AppGlassFlatSegmentedControlBackend({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onSegmentSelected,
    required this.height,
    required this.borderRadius,
    required this.indicatorBorderRadius,
    this.padding,
    required this.selectedTextStyle,
    required this.unselectedTextStyle,
    required this.indicatorColor,
    required this.labelPadding,
    required this.iconSize,
    this.backgroundColor,
    this.scrollable = false,
  });

  final List<AppGlassSegmentData> segments;
  final int selectedIndex;
  final ValueChanged<int> onSegmentSelected;
  final double height;
  final double borderRadius;
  final double indicatorBorderRadius;
  final EdgeInsetsGeometry? padding;
  final TextStyle selectedTextStyle;
  final TextStyle unselectedTextStyle;
  final Color indicatorColor;
  final EdgeInsetsGeometry labelPadding;
  final double iconSize;
  final Color? backgroundColor;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final resolvedPadding = padding ?? EdgeInsets.zero;
    final row = scrollable
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (var index = 0; index < segments.length; index++)
                  _buildSegment(context, index),
              ],
            ),
          )
        : Row(
            children: <Widget>[
              for (var index = 0; index < segments.length; index++)
                Expanded(child: _buildSegment(context, index)),
            ],
          );

    final content = SizedBox(height: height, child: row);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highContrast
            ? context.appColors.surfaceElevated
            : backgroundColor ?? context.appColors.surfaceMuted,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: highContrast
              ? context.appColors.borderStrong
              : context.appColors.borderSubtle,
        ),
      ),
      child: Padding(padding: resolvedPadding, child: content),
    );
  }

  Widget _buildSegment(BuildContext context, int index) {
    final segment = segments[index];
    final selected = index == selectedIndex;
    final style = selected ? selectedTextStyle : unselectedTextStyle;
    final indicator = BorderRadius.circular(indicatorBorderRadius);
    final disabled = !segment.enabled;
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final selectionFill = highContrast
        ? context.appColors.selectionSurface
        : indicatorColor;
    final selectionBorderColor = highContrast
        ? context.appColors.borderStrong
        : context.appColors.borderSubtle;

    Widget segmentChild = Semantics(
      button: true,
      selected: selected,
      enabled: segment.enabled,
      label: segment.label,
      child: AppInteractiveSurface(
        enabled: segment.enabled,
        onTap: segment.enabled ? () => onSegmentSelected(index) : null,
        focusRingRadius: indicator,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? selectionFill : Colors.transparent,
            borderRadius: indicator,
            border: selected ? Border.all(color: selectionBorderColor) : null,
          ),
          child: Padding(
            padding: labelPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (segment.icon != null) ...<Widget>[
                  IconTheme(
                    data: IconThemeData(size: iconSize, color: style.color),
                    child: segment.icon!,
                  ),
                  SizedBox(width: iconSize * 0.3),
                ],
                Flexible(
                  child: Text(
                    segment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (disabled) {
      segmentChild = Opacity(opacity: 0.5, child: segmentChild);
    }
    final segmentKey = segment.id is Key
        ? segment.id as Key
        : ValueKey<Object>(segment.id);
    return KeyedSubtree(key: segmentKey, child: segmentChild);
  }
}

class AppGlassFlatPopoverBackend extends StatefulWidget {
  const AppGlassFlatPopoverBackend({
    super.key,
    required this.triggerBuilder,
    required this.contentBuilder,
    required this.popoverWidth,
    required this.popoverBorderRadius,
    this.autoAdjustToScreen = true,
    this.screenPadding = EdgeInsets.zero,
    this.onOpen,
    this.role = AppFlatSurfaceRole.popover,
  });

  final Widget Function(BuildContext context, VoidCallback toggle)
  triggerBuilder;
  final Widget Function(BuildContext context, VoidCallback close)
  contentBuilder;
  final double popoverWidth;
  final double popoverBorderRadius;
  final bool autoAdjustToScreen;
  final EdgeInsets screenPadding;
  final VoidCallback? onOpen;
  final AppFlatSurfaceRole role;

  @override
  State<AppGlassFlatPopoverBackend> createState() =>
      _AppGlassFlatPopoverBackendState();
}

class _AppGlassFlatPopoverBackendState
    extends State<AppGlassFlatPopoverBackend> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      onOpen: widget.onOpen,
      alignmentOffset: Offset(0, context.appSpacing.xs),
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        side: const WidgetStatePropertyAll(BorderSide.none),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(widget.popoverBorderRadius),
          ),
        ),
      ),
      menuChildren: <Widget>[
        _FixedWidthMenuIntrinsicShield(
          width: widget.popoverWidth,
          child: SizedBox(
            width: widget.popoverWidth,
            child: AppGlassFlatSurface(
              borderRadius: BorderRadius.circular(widget.popoverBorderRadius),
              role: widget.role,
              child: widget.contentBuilder(context, _controller.close),
            ),
          ),
        ),
      ],
      builder: (context, controller, _) {
        return widget.triggerBuilder(
          context,
          () => controller.isOpen ? controller.close() : controller.open(),
        );
      },
    );
  }
}

/// 截断 `MenuAnchor` 对弹层内容的 intrinsic 查询。
///
/// 垂直 `MenuAnchor` 会用 `IntrinsicWidth` 测量菜单，而筛选面板里的
/// `LayoutBuilder` 不支持 intrinsic 尺寸，会直接抛
/// "LayoutBuilder does not support returning intrinsic dimensions"。
/// 本弹层宽度由 [width] 固定，最终高度由真实布局决定，因此这里把
/// intrinsic 宽度固定为 [width]、高度报告为 0，避免继续向下询问内容。
class _FixedWidthMenuIntrinsicShield extends SingleChildRenderObjectWidget {
  const _FixedWidthMenuIntrinsicShield({
    required this.width,
    required super.child,
  });

  final double width;

  @override
  _RenderFixedWidthMenuIntrinsicShield createRenderObject(
    BuildContext context,
  ) {
    return _RenderFixedWidthMenuIntrinsicShield(width);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFixedWidthMenuIntrinsicShield renderObject,
  ) {
    renderObject.width = width;
  }
}

class _RenderFixedWidthMenuIntrinsicShield extends RenderProxyBox {
  _RenderFixedWidthMenuIntrinsicShield(this._width);

  double _width;

  set width(double value) {
    if (_width == value) {
      return;
    }
    _width = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicWidth(double height) => _width;

  @override
  double computeMaxIntrinsicWidth(double height) => _width;

  @override
  double computeMinIntrinsicHeight(double width) => 0.0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0.0;
}

class AppGlassFlatTabBarBackend extends StatelessWidget {
  const AppGlassFlatTabBarBackend({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.barHeight,
    required this.verticalPadding,
    required this.horizontalPadding,
    required this.barBorderRadius,
    required this.iconSize,
    required this.labelFontSize,
    required this.selectedIconColor,
    required this.unselectedIconColor,
    required this.selectedLabelColor,
    required this.unselectedLabelColor,
    required this.selectedLabelStyle,
    required this.unselectedLabelStyle,
    this.role = AppFlatSurfaceRole.bar,
  });

  final List<AppGlassTabData> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final double barHeight;
  final double verticalPadding;
  final double horizontalPadding;
  final double barBorderRadius;
  final double iconSize;
  final double labelFontSize;
  final Color selectedIconColor;
  final Color unselectedIconColor;
  final Color selectedLabelColor;
  final Color unselectedLabelColor;
  final TextStyle selectedLabelStyle;
  final TextStyle unselectedLabelStyle;
  final AppFlatSurfaceRole role;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppGlassFlatSurface(
      height: barHeight,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      borderRadius: BorderRadius.circular(barBorderRadius),
      role: role,
      child: Row(
        children: <Widget>[
          for (var index = 0; index < tabs.length; index++)
            Expanded(child: _buildTab(context, tabs[index], index)),
        ],
      ),
    );
  }

  Widget _buildTab(BuildContext context, AppGlassTabData tab, int index) {
    final selected = index == selectedIndex;
    final iconColor = selected ? selectedIconColor : unselectedIconColor;
    final labelColor = selected ? selectedLabelColor : unselectedLabelColor;
    final labelStyle = (selected ? selectedLabelStyle : unselectedLabelStyle)
        .copyWith(fontSize: labelFontSize, color: labelColor);

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: AppInteractiveSurface(
        onTap: () => onTabSelected(index),
        focusRing: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected
                ? selectedLabelColor.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(barBorderRadius - 4),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconTheme(
                  data: IconThemeData(size: iconSize, color: iconColor),
                  child: selected ? (tab.activeIcon ?? tab.icon) : tab.icon,
                ),
                const SizedBox(height: 2),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppGlassFlatDividerBackend extends StatelessWidget {
  const AppGlassFlatDividerBackend({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
  });

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: indent,
      endIndent: endIndent,
      color: context.appColors.borderSubtle,
    );
  }
}

class AppGlassFlatListTileBackend extends StatelessWidget {
  const AppGlassFlatListTileBackend({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleStyle,
    this.subtitleStyle,
  });

  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    return AppInteractiveSurface(
      enabled: onTap != null,
      onTap: onTap,
      focusRing: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.sm + spacing.xs / 2,
        ),
        child: Row(
          children: <Widget>[
            if (leading != null) ...[leading!, SizedBox(width: spacing.md)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DefaultTextStyle.merge(
                    style:
                        titleStyle ??
                        resolveAppTextStyle(
                          context,
                          size: AppTextSize.s16,
                          tone: AppTextTone.primary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style:
                          subtitleStyle ??
                          resolveAppTextStyle(
                            context,
                            size: AppTextSize.s12,
                            tone: AppTextTone.muted,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: subtitle!,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[SizedBox(width: spacing.md), trailing!],
          ],
        ),
      ),
    );
  }
}

class AppGlassFlatGroupedSectionBackend extends StatelessWidget {
  const AppGlassFlatGroupedSectionBackend({
    super.key,
    required this.children,
    this.header,
  });

  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final section = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appColors.surfaceElevated,
        borderRadius: context.appRadius.xlBorder,
        border: Border.all(
          color: highContrast
              ? context.appColors.borderStrong
              : context.appColors.borderSubtle,
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
    if (header == null) {
      return section;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.appSpacing.lg,
            context.appSpacing.sm,
            context.appSpacing.lg,
            context.appSpacing.sm,
          ),
          child: header,
        ),
        section,
      ],
    );
  }
}
