import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_pill.dart';

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

/// 单选分段控件。
///
/// - 内部使用 `liquid_glass_widgets` 的 [GlassSegmentedControl.scrollable]，
///   保持自然宽度；空间不足时横向滚动。
/// - 由库组件负责轨道、选中指示器和交互动画；这里只做泛型值、主题和尺寸适配。
/// - 不再外包 `AppGlassSurface`，避免玻璃控件嵌在玻璃容器里降级折射。
class AppSegmentedControl<T> extends StatefulWidget {
  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.size = AppSegmentedSize.regular,
    this.onDark = false,
  });

  final List<AppSegmentedItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final AppSegmentedSize size;

  /// 放在深色品牌面上时切换未选中文字、指示器和轨道透明度。
  final bool onDark;

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
    final selectedColors = resolveAppPillColors(context, AppPillTone.selected);
    final inheritedFontFamily = DefaultTextStyle.of(context).style.fontFamily;
    final resolvedTextStyle = resolveAppTextStyle(
      context,
      size: spec.textSize,
      weight: AppTextWeight.regular,
      tone: AppTextTone.primary,
    );
    final baseTextStyle = resolvedTextStyle.copyWith(
      fontFamily: resolvedTextStyle.fontFamily ?? inheritedFontFamily,
    );
    final segments = <GlassSegment>[
      for (final item in widget.items)
        GlassSegment(
          id: item.key ?? item.value,
          label: item.label,
          icon: item.icon,
          semanticLabel: item.label,
        ),
    ];

    final pillRadius = context.appRadius.pill >= GlassDefaults.capsuleRadius
        ? GlassDefaults.capsuleRadius
        : context.appRadius.pill;
    final selectedTextStyle = baseTextStyle.copyWith(
      color: widget.onDark
          ? context.appTextPalette.onMedia
          : selectedColors.foreground,
    );
    final unselectedTextStyle = baseTextStyle.copyWith(
      color: widget.onDark
          ? context.appTextPalette.onMedia.withValues(alpha: 0.68)
          : context.appTextPalette.secondary,
    );
    void selectSegment(int index) {
      if (index < 0 || index >= widget.items.length) {
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

    return GlassSegmentedControl.scrollable(
      segments: segments,
      selectedIndex: resolvedSelectedIndex,
      onSegmentSelected: selectSegment,
      height: spec.height,
      borderRadius: pillRadius,
      indicatorBorderRadius: pillRadius,
      padding: EdgeInsets.all(context.appSpacing.xs / 2),
      selectedTextStyle: selectedTextStyle,
      unselectedTextStyle: unselectedTextStyle,
      indicatorColor: widget.onDark
          ? context.appTextPalette.onMedia.withValues(alpha: 0.18)
          : selectedColors.background,
      labelPadding: EdgeInsets.symmetric(horizontal: spec.horizontalPadding),
      iconSize: spec.iconSize,
      settings: _trackSettings(context, onDark: widget.onDark),
      useOwnLayer: true,
      quality: GlassQuality.standard,
    );
  }

  static LiquidGlassSettings _trackSettings(
    BuildContext context, {
    required bool onDark,
  }) {
    final overlay = context.appTextPalette.onMedia;
    return LiquidGlassSettings(
      thickness: 12,
      blur: 4,
      saturation: 1,
      chromaticAberration: 0,
      lightIntensity: 0.35,
      glassColor: onDark
          ? overlay.withValues(alpha: 0.08)
          : context.appColors.mediaOverlaySoft.withValues(alpha: 0.10),
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
