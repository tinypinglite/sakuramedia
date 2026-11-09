import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_flat_backend.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_types.dart';

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

  /// 分段节点的 Key；未提供时按 value/label 生成稳定身份。
  final Key? key;
}

enum AppSegmentedSize { compact, regular }

/// 分段控件的布局方式。
///
/// [auto] 在 2–6 项时使用等宽分段，超过 6 项时横向滚动；[fixed] 强制等宽
/// （超出 2–6 项范围时回退滚动）；[scrollable] 始终保持自然宽度并滚动。
enum AppSegmentedLayout { auto, fixed, scrollable }

/// 单选分段控件。
///
/// 使用中性轨道和选中胶囊，不跟随全局液态玻璃设置。
class AppSegmentedControl<T> extends StatefulWidget {
  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.size = AppSegmentedSize.regular,
    this.layout = AppSegmentedLayout.scrollable,
    this.enabled = true,
  });

  final List<AppSegmentedItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final AppSegmentedSize size;
  final AppSegmentedLayout layout;

  /// 为 `false` 时所有分段降级为不可点击，并降低不透明度。
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
    final isFixed = switch (widget.layout) {
      AppSegmentedLayout.scrollable => false,
      AppSegmentedLayout.fixed || AppSegmentedLayout.auto =>
        widget.items.length >= 2 && widget.items.length <= 6,
    };
    final inheritedFontFamily = DefaultTextStyle.of(context).style.fontFamily;
    final unselectedTextStyle = resolveAppTextStyle(
      context,
      size: spec.textSize,
      weight: AppTextWeight.regular,
      tone: AppTextTone.secondary,
    ).copyWith(fontFamily: inheritedFontFamily);
    final selectedTextStyle = resolveAppTextStyle(
      context,
      size: spec.textSize,
      weight: AppTextWeight.semibold,
      tone: AppTextTone.primary,
    ).copyWith(fontFamily: inheritedFontFamily);
    final segments = <AppGlassSegmentData>[
      for (final item in widget.items)
        AppGlassSegmentData(
          id: item.key ?? (item.value ?? item.label),
          label: item.label,
          icon: item.icon,
          enabled: widget.enabled,
        ),
    ];

    final textScale = MediaQuery.textScalerOf(context);
    final scaledTextHeight = textScale.scale(
      context.appTextScale.sizeOf(spec.textSize),
    );
    final controlHeight = math.max(spec.height, scaledTextHeight + 14.0);
    void selectSegment(int index) {
      if (!widget.enabled || index < 0 || index >= widget.items.length) {
        return;
      }
      final value = widget.items[index].value;
      if (value == widget.selected) {
        return;
      }
      if (_hasEmittedSelection && value == _lastEmittedValue) {
        return;
      }
      _hasEmittedSelection = true;
      _lastEmittedValue = value;
      widget.onChanged(value);
    }

    return AppGlassFlatSegmentedControlBackend(
      segments: segments,
      selectedIndex: resolvedSelectedIndex,
      onSegmentSelected: selectSegment,
      height: controlHeight,
      borderRadius: context.appRadius.pill,
      indicatorBorderRadius: controlHeight / 2,
      padding: EdgeInsets.all(context.appSpacing.xs / 2),
      selectedTextStyle: selectedTextStyle,
      unselectedTextStyle: unselectedTextStyle,
      indicatorColor: context.appColors.surfaceCard,
      labelPadding: EdgeInsets.symmetric(horizontal: spec.horizontalPadding),
      iconSize: spec.iconSize,
      backgroundColor: context.appColors.surfaceMuted,
      scrollable: !isFixed,
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
