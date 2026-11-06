import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_flat_backend.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_style.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_types.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';
import 'package:sakuramedia/theme.dart';

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

  @override
  Widget build(BuildContext context) {
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
  });

  final List<Widget> children;
  final double borderRadius;
  final bool showDividers;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatButtonGroupBackend(
        borderRadius: borderRadius,
        showDividers: showDividers,
        children: children,
      );
    }
    return GlassButtonGroup(
      borderRadius: borderRadius,
      useOwnLayer: true,
      showDividers: showDividers,
      children: children,
    );
  }
}

class AppGlassContainerBackend extends StatelessWidget {
  const AppGlassContainerBackend({
    super.key,
    required this.child,
    required this.borderRadius,
  });

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatContainerBackend(
        borderRadius: borderRadius,
        child: child,
      );
    }
    return GlassContainer(
      useOwnLayer: true,
      clipBehavior: Clip.antiAlias,
      shape: LiquidRoundedSuperellipse(borderRadius: borderRadius),
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

  @override
  Widget build(BuildContext context) {
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
        height: height,
        borderRadius: borderRadius,
        fillColor: fillColor,
        enabled: enabled,
      );
    }
    final settings = !highContrast && fillColor != null
        ? AppGlassStyle.settingsWithColor(context, fillColor!)
        : null;

    return GlassTextField(
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
  }
}

class AppGlassSegmentedControlBackend extends StatelessWidget {
  const AppGlassSegmentedControlBackend({
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
    this.indicatorShadow,
    this.neutral = false,
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
  final List<BoxShadow>? indicatorShadow;
  final bool neutral;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (AppSurfaceStyleScope.of(context) == AppSurfaceStyle.flat) {
      return AppGlassFlatSegmentedControlBackend(
        segments: segments,
        selectedIndex: selectedIndex,
        onSegmentSelected: onSegmentSelected,
        height: height,
        borderRadius: borderRadius,
        indicatorBorderRadius: indicatorBorderRadius,
        padding: padding,
        selectedTextStyle: selectedTextStyle,
        unselectedTextStyle: unselectedTextStyle,
        indicatorColor: indicatorColor,
        labelPadding: labelPadding,
        iconSize: iconSize,
        backgroundColor: backgroundColor,
        neutral: neutral,
        scrollable: scrollable,
      );
    }
    final mappedSegments = <GlassSegment>[
      for (final segment in segments)
        GlassSegment(
          id: segment.id,
          label: segment.label,
          icon: segment.icon,
          semanticLabel: segment.label,
          enabled: segment.enabled,
        ),
    ];
    if (scrollable) {
      return GlassSegmentedControl.scrollable(
        segments: mappedSegments,
        selectedIndex: selectedIndex,
        onSegmentSelected: onSegmentSelected,
        height: height,
        borderRadius: borderRadius,
        indicatorBorderRadius: indicatorBorderRadius,
        padding: padding ?? EdgeInsets.zero,
        selectedTextStyle: selectedTextStyle,
        unselectedTextStyle: unselectedTextStyle,
        indicatorColor: indicatorColor,
        labelPadding: labelPadding,
        iconSize: iconSize,
        backgroundColor: backgroundColor,
        indicatorShadow: indicatorShadow,
        useOwnLayer: !neutral,
      );
    }
    return GlassSegmentedControl(
      segments: mappedSegments,
      selectedIndex: selectedIndex,
      onSegmentSelected: onSegmentSelected,
      height: height,
      borderRadius: borderRadius,
      indicatorBorderRadius: indicatorBorderRadius,
      padding: padding ?? EdgeInsets.zero,
      selectedTextStyle: selectedTextStyle,
      unselectedTextStyle: unselectedTextStyle,
      indicatorColor: indicatorColor,
      indicatorExpansion: EdgeInsets.zero,
      labelPadding: labelPadding,
      iconSize: iconSize,
      backgroundColor: backgroundColor,
      indicatorShadow: indicatorShadow,
      useOwnLayer: !neutral,
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
      );
    }
    return GlassPopover(
      popoverWidth: popoverWidth,
      popoverBorderRadius: popoverBorderRadius,
      autoAdjustToScreen: autoAdjustToScreen,
      screenPadding: screenPadding,
      settings: AppGlassStyle.surfaceSettings(context),
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
