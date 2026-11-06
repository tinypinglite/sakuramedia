import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';

/// 筛选面板里的双滑块分节。
///
/// 拖动过程中只更新本地区间和值文案，松手才通过 [onChangeEnd] 应用到筛选状态；
/// 外部筛选值变化时会把滑块位置同步回来。[RangeSlider] 保留原生手势、键盘和
/// 无障碍语义，只替换视觉 token，避免自研双 thumb 控件的回归风险。
class AppFilterRangeSection extends StatefulWidget {
  const AppFilterRangeSection({
    super.key,
    required this.title,
    required this.values,
    required this.min,
    required this.max,
    required this.valueLabelBuilder,
    required this.minLabel,
    required this.maxLabel,
    this.divisions,
    this.onChanged,
    this.onChangeEnd,
    this.enabled = true,
    this.sliderKey,
    this.titleKey,
    this.valueLabelKey,
    this.semanticFormatter,
  });

  final String title;
  final RangeValues values;
  final double min;
  final double max;
  final String Function(RangeValues values) valueLabelBuilder;
  final String minLabel;
  final String maxLabel;
  final int? divisions;

  /// 拖动中的回调；只用于外部需要同步预览时，筛选请求应放在 [onChangeEnd]。
  final ValueChanged<RangeValues>? onChanged;
  final ValueChanged<RangeValues>? onChangeEnd;
  final bool enabled;
  final Key? sliderKey;
  final Key? titleKey;
  final Key? valueLabelKey;
  final String Function(double value)? semanticFormatter;

  @override
  State<AppFilterRangeSection> createState() => _AppFilterRangeSectionState();
}

class _AppFilterRangeSectionState extends State<AppFilterRangeSection> {
  late RangeValues _values;

  @override
  void initState() {
    super.initState();
    _values = _clamp(widget.values);
  }

  @override
  void didUpdateWidget(covariant AppFilterRangeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values != widget.values ||
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max) {
      _values = _clamp(widget.values);
    }
  }

  RangeValues _clamp(RangeValues values) {
    final start = values.start.clamp(widget.min, widget.max).toDouble();
    final end = values.end.clamp(widget.min, widget.max).toDouble();
    if (start > end) {
      return RangeValues(widget.min, widget.max);
    }
    return RangeValues(start, end);
  }

  void _apply(RangeValues values) {
    setState(() => _values = values);
    widget.onChangeEnd?.call(values);
  }

  String _formatSemanticValue(double value) {
    final formatter = widget.semanticFormatter;
    if (formatter != null) {
      return formatter(value);
    }
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              key: widget.titleKey,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: widget.enabled ? AppTextTone.primary : AppTextTone.muted,
              ),
            ),
            Text(
              key: widget.valueLabelKey,
              widget.valueLabelBuilder(_values),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: widget.enabled
                    ? AppTextTone.secondary
                    : AppTextTone.muted,
              ),
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.xs),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colors.borderSubtle,
            disabledActiveTrackColor: colors.borderStrong,
            disabledInactiveTrackColor: colors.borderSubtle,
            thumbColor: context.appTextPalette.onMedia,
            disabledThumbColor: colors.borderStrong,
            overlappingShapeStrokeColor: colors.borderStrong,
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 8,
              disabledThumbRadius: 8,
              elevation: 2,
              pressedElevation: 4,
            ),
            rangeTickMarkShape: const _NoRangeSliderTickMarkShape(),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            overlayColor: colorScheme.primary.withValues(alpha: 0.12),
            showValueIndicator: ShowValueIndicator.never,
          ),
          child: RangeSlider(
            key: widget.sliderKey,
            values: _values,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            semanticFormatterCallback: _formatSemanticValue,
            onChanged: widget.enabled
                ? (values) {
                    setState(() => _values = values);
                    widget.onChanged?.call(values);
                  }
                : null,
            onChangeEnd: widget.enabled ? _apply : null,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.appSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.minLabel,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s10,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              Text(
                widget.maxLabel,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s10,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoRangeSliderTickMarkShape extends RangeSliderTickMarkShape {
  const _NoRangeSliderTickMarkShape();

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    bool isEnabled = true,
  }) => Size.zero;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required Offset startThumbCenter,
    required Offset endThumbCenter,
    bool isEnabled = true,
    required TextDirection textDirection,
  }) {}
}
