import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_pill.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_backend.dart';

/// 分段控件的一项。
class AppSegmentedItem<T> {
  const AppSegmentedItem({
    required this.value,
    required this.label,
    this.icon,
    this.key,
  });

  final T value;
  final String label;
  final Widget? icon;

  /// 分段在列表变化时的稳定身份。
  ///
  /// 该值现在交给库的 `GlassSegment.id`，不再作为可查找的 Widget key。
  final Key? key;
}

enum AppSegmentedSize { compact, regular }

/// 分段控件的表面语气。
///
/// [standard] 保留项目原有的玻璃轨道；[neutral] 用于玻璃弹层内部，轨道透明，
/// 选中项只浮起一枚中性胶囊。
enum AppSegmentedTone { standard, neutral }

/// 分段控件的布局方式。
///
/// [auto] 在 2–6 项时使用等宽分段，超过 6 项时横向滚动；[fixed] 强制等宽
/// （超出库的 2–6 项限制时回退滚动）；[scrollable] 始终保持自然宽度并滚动。
enum AppSegmentedLayout { auto, fixed, scrollable }

/// 单选分段控件。
///
/// - 内部使用 `liquid_glass_widgets` 的 [GlassSegmentedControl]；[layout]
///   控制等宽分段或自然宽度滚动。
/// - 由库组件负责轨道、选中指示器和交互动画；这里只做泛型值、主题和尺寸适配。
/// - 不再外包 `AppGlassSurface`，避免玻璃控件嵌在玻璃容器里降级折射。
class AppSegmentedControl<T> extends StatefulWidget {
  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.size = AppSegmentedSize.regular,
    this.tone = AppSegmentedTone.standard,
    this.layout = AppSegmentedLayout.scrollable,
    this.enabled = true,
  });

  final List<AppSegmentedItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final AppSegmentedSize size;
  final AppSegmentedTone tone;
  final AppSegmentedLayout layout;

  /// 为 `false` 时所有分段降级为不可点击，视觉由库的 disabled segment 处理。
  final bool enabled;

  @override
  State<AppSegmentedControl<T>> createState() => _AppSegmentedControlState<T>();
}

class _AppSegmentedControlState<T> extends State<AppSegmentedControl<T>> {
  bool _hasEmittedSelection = false;
  T? _lastEmittedValue;

  @override
  void didUpdateWidget(covariant AppSegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _hasEmittedSelection = false;
      _lastEmittedValue = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(
      widget.items.isNotEmpty,
      'AppSegmentedControl needs at least one item',
    );
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    final selectedIndex = widget.items.indexWhere(
      (item) => item.value == widget.selected,
    );
    assert(
      selectedIndex >= 0,
      'AppSegmentedControl.selected must match one of the items',
    );
    final resolvedSelectedIndex = selectedIndex < 0 ? 0 : selectedIndex;

    final spec = _AppSegmentedSizeSpec.resolve(context, widget.size);
    final isNeutral = widget.tone == AppSegmentedTone.neutral;
    final isFixed = switch (widget.layout) {
      AppSegmentedLayout.scrollable => false,
      AppSegmentedLayout.fixed || AppSegmentedLayout.auto =>
        widget.items.length >= 2 && widget.items.length <= 6,
    };
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final neutralIndicatorColor = isDark
        ? context.appColors.mediaOverlayBorder.withValues(alpha: 0.18)
        : context.appColors.surfaceElevated;
    final neutralTrackColor = isDark
        ? context.appColors.mediaOverlaySoft
        : context.appColors.surfaceMuted.withValues(alpha: 0.45);
    final selectedColors = isNeutral
        ? AppPillColors(
            background: neutralIndicatorColor,
            foreground: context.appTextPalette.primary,
          )
        : resolveAppPillColors(context, AppPillTone.selected);
    final inheritedFontFamily = DefaultTextStyle.of(context).style.fontFamily;
    final resolvedTextStyle = isNeutral
        ? resolveAppTextStyle(
            context,
            size: spec.textSize,
            weight: AppTextWeight.regular,
            tone: AppTextTone.secondary,
          )
        : resolveAppTextStyle(
            context,
            size: spec.textSize,
            weight: AppTextWeight.regular,
            tone: AppTextTone.primary,
          );
    final baseTextStyle = resolvedTextStyle.copyWith(
      fontFamily: resolvedTextStyle.fontFamily ?? inheritedFontFamily,
    );
    final segments = <AppGlassSegmentData>[
      for (final item in widget.items)
        AppGlassSegmentData(
          id: item.key ?? (item.value ?? item.label),
          label: item.label,
          icon: item.icon,
          enabled: widget.enabled,
        ),
    ];

    final pillRadius = context.appRadius.pill >= appGlassCapsuleRadius
        ? appGlassCapsuleRadius
        : context.appRadius.pill;
    final textScale = MediaQuery.textScalerOf(context);
    final scaledTextHeight = textScale.scale(
      context.appTextScale.sizeOf(spec.textSize),
    );
    final minimumControlHeight = isNeutral ? 34.0 : spec.height;
    final controlHeight = math.max(
      minimumControlHeight,
      scaledTextHeight + (isNeutral ? 20.0 : 14.0),
    );
    final selectedTextStyle = isNeutral
        ? resolveAppTextStyle(
            context,
            size: spec.textSize,
            weight: AppTextWeight.semibold,
            tone: AppTextTone.primary,
          ).copyWith(
            fontFamily: resolvedTextStyle.fontFamily ?? inheritedFontFamily,
          )
        : baseTextStyle.copyWith(color: selectedColors.foreground);
    final unselectedTextStyle = isNeutral
        ? baseTextStyle
        : baseTextStyle.copyWith(color: context.appTextPalette.secondary);
    void selectSegment(int index) {
      if (!widget.enabled || index < 0 || index >= widget.items.length) {
        return;
      }
      final value = widget.items[index].value;
      if (_hasEmittedSelection && value == _lastEmittedValue) {
        return;
      }
      _hasEmittedSelection = true;
      _lastEmittedValue = value;
      widget.onChanged(value);
    }

    final controlRadius = isNeutral ? controlHeight / 2 : pillRadius;
    if (isFixed) {
      return AppGlassSegmentedControlBackend(
        segments: segments,
        selectedIndex: resolvedSelectedIndex,
        onSegmentSelected: selectSegment,
        height: controlHeight,
        borderRadius: controlRadius,
        indicatorBorderRadius: controlRadius,
        padding: isNeutral
            ? EdgeInsets.zero
            : EdgeInsets.all(context.appSpacing.xs / 2),
        selectedTextStyle: selectedTextStyle,
        unselectedTextStyle: unselectedTextStyle,
        indicatorColor: selectedColors.background,
        labelPadding: EdgeInsets.symmetric(
          horizontal: isNeutral ? 12 : spec.horizontalPadding,
        ),
        iconSize: spec.iconSize,
        backgroundColor: isNeutral ? neutralTrackColor : null,
        indicatorShadow: isNeutral ? context.appShadows.indicator : null,
        neutral: isNeutral,
      );
    }
    return AppGlassSegmentedControlBackend(
      segments: segments,
      selectedIndex: resolvedSelectedIndex,
      onSegmentSelected: selectSegment,
      height: controlHeight,
      borderRadius: controlRadius,
      indicatorBorderRadius: controlRadius,
      padding: isNeutral
          ? EdgeInsets.zero
          : EdgeInsets.all(context.appSpacing.xs / 2),
      selectedTextStyle: selectedTextStyle,
      unselectedTextStyle: unselectedTextStyle,
      indicatorColor: selectedColors.background,
      labelPadding: EdgeInsets.symmetric(
        horizontal: isNeutral ? 12 : spec.horizontalPadding,
      ),
      iconSize: spec.iconSize,
      backgroundColor: isNeutral ? neutralTrackColor : null,
      indicatorShadow: isNeutral ? context.appShadows.indicator : null,
      neutral: isNeutral,
      scrollable: true,
    );
  }
}

class _AppSegmentedSizeSpec {
  const _AppSegmentedSizeSpec({
    required this.height,
    required this.horizontalPadding,
    required this.textSize,
    required this.iconSize,
  });

  final double height;
  final double horizontalPadding;
  final AppTextSize textSize;
  final double iconSize;

  static _AppSegmentedSizeSpec resolve(
    BuildContext context,
    AppSegmentedSize size,
  ) {
    final spacing = context.appSpacing;
    final tokens = context.appComponentTokens;
    return switch (size) {
      AppSegmentedSize.compact => _AppSegmentedSizeSpec(
        height: tokens.buttonHeight2xs,
        horizontalPadding: spacing.sm,
        textSize: AppTextSize.s12,
        iconSize: tokens.iconSize3xs,
      ),
      AppSegmentedSize.regular => _AppSegmentedSizeSpec(
        height: tokens.buttonHeightXs,
        horizontalPadding: spacing.md,
        textSize: AppTextSize.s12,
        iconSize: tokens.iconSize2xs,
      ),
    };
  }
}
