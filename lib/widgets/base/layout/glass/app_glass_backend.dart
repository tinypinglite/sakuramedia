import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_flat_backend.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_flat_style.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_flat_surface.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_style.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_types.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';

export 'package:sakuramedia/widgets/base/layout/glass/app_glass_types.dart';

class AppGlassIconButtonBackend extends StatelessWidget {
  const AppGlassIconButtonBackend({
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
    this.glowColor,
    this.tone = AppGlassTone.standard,
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
  final Color? glowColor;
  final AppGlassTone tone;

  @override
  Widget build(BuildContext context) {
    if (tone == AppGlassTone.toolbar) {
      return _AppGlassToolbarIconButton(
        icon: icon,
        onTap: onTap,
        enabled: enabled,
        width: width,
        height: height,
        iconSize: iconSize,
        iconColor: iconColor,
      );
    }
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatIconButtonBackend(
        icon: icon,
        onTap: onTap,
        label: label,
        enabled: enabled,
        width: width,
        height: height,
        iconSize: iconSize,
        iconColor: iconColor,
        prominent: prominent,
      );
    }
    return GlassButton(
      icon: icon,
      onTap: onTap,
      label: label,
      enabled: enabled,
      width: width,
      height: height,
      iconSize: iconSize,
      iconColor: iconColor,
      shape: const LiquidOval(),
      useOwnLayer: true,
      style: prominent ? GlassButtonStyle.prominent : GlassButtonStyle.filled,
      settings: AppGlassStyle.settingsFor(context, AppGlassRole.control),
      quality: AppGlassStyle.qualityFor(AppGlassRole.control),
      stretch: 0.15,
      glowColor: glowColor,
    );
  }
}

class AppGlassCustomButtonBackend extends StatelessWidget {
  const AppGlassCustomButtonBackend({
    super.key,
    required this.child,
    required this.onTap,
    this.label = '',
    this.enabled = true,
    this.width,
    this.height,
    this.borderRadius = 16,
    this.style = AppGlassButtonStyle.filled,
    this.stretch = 0.5,
    this.useOwnLayer = false,
    this.role = AppGlassRole.control,
  });

  final Widget child;
  final VoidCallback onTap;
  final String label;
  final bool enabled;
  final double? width;
  final double? height;
  final double borderRadius;
  final AppGlassButtonStyle style;
  final double stretch;
  final bool useOwnLayer;
  final AppGlassRole role;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatCustomButtonBackend(
        onTap: onTap,
        label: label,
        enabled: enabled,
        width: width,
        height: height,
        borderRadius: borderRadius,
        style: style,
        role: AppGlassStyle.flatRoleFor(role),
        child: child,
      );
    }
    return GlassButton.custom(
      onTap: onTap,
      label: label,
      enabled: enabled,
      width: width,
      height: height,
      shape: LiquidRoundedRectangle(borderRadius: borderRadius),
      useOwnLayer: useOwnLayer,
      style: _mapButtonStyle(style),
      settings: AppGlassStyle.settingsFor(context, role),
      quality: AppGlassStyle.qualityFor(role),
      stretch: stretch,
      child: child,
    );
  }
}

class AppGlassButtonGroupBackend extends StatelessWidget {
  const AppGlassButtonGroupBackend({
    super.key,
    required this.children,
    required this.borderRadius,
    this.showDividers = false,
    this.role = AppGlassRole.control,
  });

  final List<Widget> children;
  final double borderRadius;
  final bool showDividers;
  final AppGlassRole role;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatButtonGroupBackend(
        borderRadius: borderRadius,
        showDividers: showDividers,
        role: AppGlassStyle.flatRoleFor(role),
        children: children,
      );
    }
    return GlassButtonGroup(
      borderRadius: borderRadius,
      useOwnLayer: true,
      showDividers: showDividers,
      settings: AppGlassStyle.settingsFor(context, role),
      quality: AppGlassStyle.qualityFor(role),
      children: children,
    );
  }
}

class AppGlassContainerBackend extends StatelessWidget {
  const AppGlassContainerBackend({
    super.key,
    required this.child,
    required this.borderRadius,
    this.role = AppGlassRole.surface,
  });

  final Widget child;
  final double borderRadius;
  final AppGlassRole role;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatContainerBackend(
        borderRadius: borderRadius,
        role: AppGlassStyle.flatRoleFor(role),
        child: child,
      );
    }
    return GlassContainer(
      useOwnLayer: true,
      clipBehavior: Clip.antiAlias,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      settings: AppGlassStyle.settingsFor(context, role),
      quality: AppGlassStyle.qualityFor(role),
      child: child,
    );
  }
}

class AppGlassTextFieldBackend extends StatelessWidget {
  const AppGlassTextFieldBackend({
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
    this.fillColor,
    this.highContrast = false,
    this.reduceMotion = false,
    this.enabled = true,
    this.tone = AppGlassTone.standard,
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
  final Color? fillColor;
  final bool highContrast;
  final bool reduceMotion;
  final bool enabled;
  final AppGlassTone tone;

  @override
  Widget build(BuildContext context) {
    final role = tone == AppGlassTone.toolbar
        ? AppGlassRole.toolbarInput
        : AppGlassRole.input;
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatTextFieldBackend(
        controller: controller,
        focusNode: focusNode,
        placeholder: placeholder,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        maxLines: maxLines,
        minLines: minLines,
        readOnly: readOnly,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTapOutside: onTapOutside,
        textStyle: textStyle,
        placeholderStyle: placeholderStyle,
        padding: padding,
        iconSpacing: iconSpacing,
        height: height,
        borderRadius: borderRadius,
        fillColor: fillColor,
        enabled: enabled,
        role: AppGlassStyle.flatRoleFor(role),
      );
    }
    final settings = highContrast
        ? null
        : AppGlassStyle.settingsFor(context, role, tintOverride: fillColor);

    final field = GlassTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      minLines: minLines,
      enabled: true,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTapOutside: onTapOutside,
      textStyle: textStyle,
      placeholderStyle: placeholderStyle,
      padding: padding ?? EdgeInsets.zero,
      iconSpacing: iconSpacing,
      height: height,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
      settings: settings,
      quality: highContrast ? null : AppGlassStyle.qualityFor(role),
      useOwnLayer: !highContrast,
      surfaceStyle: highContrast
          ? GlassSurfaceStyle.solid
          : GlassSurfaceStyle.glass,
      color: highContrast
          ? (fillColor ?? context.appColors.surfaceMuted)
          : null,
      interactionBehavior: highContrast || reduceMotion || !enabled
          ? GlassInteractionBehavior.none
          : GlassInteractionBehavior.glowOnly,
    );

    if (highContrast) {
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: context.appColors.borderStrong),
        ),
        child: field,
      );
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      foregroundPainter: _AppGlassInputRimPainter(
        radius: BorderRadius.circular(borderRadius),
        topColor: context.appColors.highlight.withValues(
          alpha: dark ? 0.22 : 0.55,
        ),
        sideColor: dark
            ? context.appColors.highlight.withValues(alpha: 0.08)
            : context.appColors.mediaOverlayStrong.withValues(alpha: 0.035),
        bottomColor: context.appColors.mediaOverlayStrong.withValues(
          alpha: dark ? 0.40 : 0.06,
        ),
      ),
      child: field,
    );
  }
}

class AppGlassPopoverBackend extends StatelessWidget {
  const AppGlassPopoverBackend({
    super.key,
    required this.triggerBuilder,
    required this.contentBuilder,
    required this.popoverWidth,
    required this.popoverBorderRadius,
    this.autoAdjustToScreen = true,
    this.screenPadding = const EdgeInsets.all(16),
    this.onOpen,
    this.role = AppGlassRole.popover,
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
  final AppGlassRole role;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatPopoverBackend(
        triggerBuilder: triggerBuilder,
        contentBuilder: contentBuilder,
        popoverWidth: popoverWidth,
        popoverBorderRadius: popoverBorderRadius,
        autoAdjustToScreen: autoAdjustToScreen,
        screenPadding: screenPadding,
        onOpen: onOpen,
        role: AppGlassStyle.flatRoleFor(role),
      );
    }
    return GlassPopover(
      popoverWidth: popoverWidth,
      popoverBorderRadius: popoverBorderRadius,
      autoAdjustToScreen: autoAdjustToScreen,
      screenPadding: screenPadding,
      settings: AppGlassStyle.settingsFor(context, role),
      quality: AppGlassStyle.qualityFor(role),
      triggerBuilder: triggerBuilder,
      onOpen: onOpen,
      contentBuilder: contentBuilder,
    );
  }
}

class AppGlassTabBarBackend extends StatelessWidget {
  const AppGlassTabBarBackend({
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
    this.role = AppGlassRole.bar,
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
  final AppGlassRole role;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatTabBarBackend(
        tabs: tabs,
        selectedIndex: selectedIndex,
        onTabSelected: onTabSelected,
        barHeight: barHeight,
        verticalPadding: verticalPadding,
        horizontalPadding: horizontalPadding,
        barBorderRadius: barBorderRadius,
        iconSize: iconSize,
        labelFontSize: labelFontSize,
        selectedIconColor: selectedIconColor,
        unselectedIconColor: unselectedIconColor,
        selectedLabelColor: selectedLabelColor,
        unselectedLabelColor: unselectedLabelColor,
        selectedLabelStyle: selectedLabelStyle,
        unselectedLabelStyle: unselectedLabelStyle,
        role: AppGlassStyle.flatRoleFor(role),
      );
    }
    return GlassTabBar.bottom(
      tabs: <GlassTab>[
        for (final tab in tabs)
          GlassTab(
            icon: tab.icon,
            activeIcon: tab.activeIcon ?? tab.icon,
            label: tab.label,
            semanticLabel: tab.label,
          ),
      ],
      selectedIndex: selectedIndex,
      onTabSelected: onTabSelected,
      barHeight: barHeight,
      verticalPadding: verticalPadding,
      horizontalPadding: horizontalPadding,
      barBorderRadius: barBorderRadius,
      iconSize: iconSize,
      labelFontSize: labelFontSize,
      selectedIconColor: selectedIconColor,
      unselectedIconColor: unselectedIconColor,
      selectedLabelColor: selectedLabelColor,
      unselectedLabelColor: unselectedLabelColor,
      selectedLabelStyle: selectedLabelStyle,
      unselectedLabelStyle: unselectedLabelStyle,
      settings: AppGlassStyle.settingsFor(context, role),
      quality: AppGlassStyle.qualityFor(role),
    );
  }
}

class AppGlassBackdropGroupBackend extends StatelessWidget {
  const AppGlassBackdropGroupBackend({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return child;
    }
    return GlassBackdropGroup(child: child);
  }
}

class AppGlassDividerBackend extends StatelessWidget {
  const AppGlassDividerBackend({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
  });

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatDividerBackend(indent: indent, endIndent: endIndent);
    }
    return GlassDivider(indent: indent, endIndent: endIndent);
  }
}

class AppGlassListTileBackend extends StatelessWidget {
  const AppGlassListTileBackend({
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
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatListTileBackend(
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap,
        titleStyle: titleStyle,
        subtitleStyle: subtitleStyle,
      );
    }
    return GlassListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );
  }
}

class AppGlassGroupedSectionBackend extends StatelessWidget {
  const AppGlassGroupedSectionBackend({
    super.key,
    required this.children,
    this.header,
  });

  final List<Widget> children;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatGroupedSectionBackend(
        header: header,
        children: children,
      );
    }
    return GlassGroupedSection(
      header: header,
      surfaceStyle: GlassSurfaceStyle.solid,
      children: children,
    );
  }
}

GlassButtonStyle _mapButtonStyle(AppGlassButtonStyle style) {
  return switch (style) {
    AppGlassButtonStyle.filled => GlassButtonStyle.filled,
    AppGlassButtonStyle.prominent => GlassButtonStyle.prominent,
    AppGlassButtonStyle.transparent => GlassButtonStyle.transparent,
  };
}

/// 顶栏图标钮：静止态只显示图标，hover/focus/press 才浮出轻玻璃胶囊。
class _AppGlassToolbarIconButton extends StatefulWidget {
  const _AppGlassToolbarIconButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.width,
    required this.height,
    required this.iconSize,
    required this.iconColor,
  });

  final Widget icon;
  final VoidCallback onTap;
  final bool enabled;
  final double width;
  final double height;
  final double iconSize;
  final Color? iconColor;

  @override
  State<_AppGlassToolbarIconButton> createState() =>
      _AppGlassToolbarIconButtonState();
}

class _AppGlassToolbarIconButtonState
    extends State<_AppGlassToolbarIconButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && (_hovered || _focused || _pressed);
    final flat = AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat;
    final radius = BorderRadius.circular(widget.height / 2);
    final iconColor = widget.iconColor ?? context.appTextPalette.primary;

    final background = flat
        ? AppGlassFlatSurface(
            width: widget.width,
            height: widget.height,
            borderRadius: radius,
            role: AppFlatSurfaceRole.toolbarControl,
            child: const SizedBox.expand(),
          )
        : GlassContainer(
            width: widget.width,
            height: widget.height,
            shape: const LiquidOval(),
            settings: AppGlassStyle.settingsFor(
              context,
              AppGlassRole.toolbarControl,
            ),
            quality: AppGlassStyle.qualityFor(AppGlassRole.toolbarControl),
            useOwnLayer: true,
            clipBehavior: Clip.antiAlias,
            child: const SizedBox.expand(),
          );

    return Opacity(
      opacity: widget.enabled ? 1 : 0.45,
      child: AppInteractiveSurface(
        enabled: widget.enabled,
        onTap: widget.enabled ? widget.onTap : null,
        onHoverChanged: (value) => setState(() => _hovered = value),
        onFocusChanged: (value) => setState(() => _focused = value),
        onPressedChanged: (value) => setState(() => _pressed = value),
        pressedOpacity: 1,
        focusRing: true,
        focusRingRadius: radius,
        excludeFromSemantics: true,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                AnimatedOpacity(
                  opacity: active ? 1 : 0,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  child: background,
                ),
                IconTheme(
                  data: IconThemeData(size: widget.iconSize, color: iconColor),
                  child: widget.icon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppGlassInputRimPainter extends CustomPainter {
  const _AppGlassInputRimPainter({
    required this.radius,
    required this.topColor,
    required this.sideColor,
    required this.bottomColor,
  });

  final BorderRadius radius;
  final Color topColor;
  final Color sideColor;
  final Color bottomColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.5);
    final shader = SweepGradient(
      center: Alignment.topCenter,
      startAngle: -math.pi / 2,
      endAngle: 3 * math.pi / 2,
      colors: <Color>[
        topColor,
        sideColor,
        sideColor,
        bottomColor,
        sideColor,
        sideColor,
        topColor,
      ],
      stops: const <double>[0, 0.18, 0.42, 0.5, 0.58, 0.82, 1],
    ).createShader(rect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = shader;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_AppGlassInputRimPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.topColor != topColor ||
        oldDelegate.sideColor != sideColor ||
        oldDelegate.bottomColor != bottomColor;
  }
}
