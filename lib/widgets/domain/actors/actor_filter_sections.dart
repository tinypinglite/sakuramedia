import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_filter_options_dto.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_filter_options_provider.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 演员筛选所有 section 的纵向 Column。
///
/// 桌面 `AppListHeader` 的就地浮层 panel 和移动 `MobileActorFilterDrawer` 都用它，
/// 避免双份维护。底栏/重置按钮由调用方自己附加。
class ActorFilterSectionGroup extends ConsumerWidget {
  const ActorFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final ActorFilterState filterState;
  final ValueChanged<ActorFilterState> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optionsScope = ActorFilterOptionsScope(
      subscriptionStatus: filterState.subscriptionStatus,
      gender: filterState.gender,
    );
    final options = ref.watch(actorFilterOptionsProvider(optionsScope));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActorFilterChoiceSection<ActorSubscriptionStatus>(
          title: '订阅筛选',
          options: ActorSubscriptionStatus.values,
          selectedValue: filterState.subscriptionStatus,
          labelBuilder: (value) => value.label,
          onSelected: (value) =>
              onChanged(filterState.copyWith(subscriptionStatus: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        ActorFilterChoiceSection<ActorGender>(
          title: '性别筛选',
          options: ActorGender.values,
          selectedValue: filterState.gender,
          labelBuilder: (value) => value.label,
          onSelected: (value) => onChanged(filterState.copyWith(gender: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        options.when(
          data: (value) => ActorProfileFilterSections(
            filterState: filterState,
            options: value,
            onChanged: onChanged,
          ),
          loading: () => const _ActorProfileFilterOptionsMessage(
            message: '正在加载资料筛选选项',
            loading: true,
          ),
          error: (_, _) => _ActorProfileFilterOptionsMessage(
            message: '资料筛选选项加载失败',
            onRetry: () =>
                ref.invalidate(actorFilterOptionsProvider(optionsScope)),
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        ActorSortSection(
          filterState: filterState,
          onSortFieldChanged: (value) =>
              onChanged(filterState.copyWith(sortField: value)),
          onSortDirectionChanged: (value) =>
              onChanged(filterState.copyWith(sortDirection: value)),
        ),
      ],
    );
  }
}

class _ActorProfileFilterOptionsMessage extends StatelessWidget {
  const _ActorProfileFilterOptionsMessage({
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: context.appSpacing.sm),
        ],
        Text(
          message,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ),
        ),
        if (onRetry != null) ...[
          SizedBox(width: context.appSpacing.sm),
          AppTextButton(
            label: '重试',
            size: AppTextButtonSize.xSmall,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}

class ActorProfileFilterSections extends StatelessWidget {
  const ActorProfileFilterSections({
    super.key,
    required this.filterState,
    required this.options,
    required this.onChanged,
  });

  final ActorFilterState filterState;
  final ActorFilterOptionsDto options;
  final ValueChanged<ActorFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActorNumericRangeFilterSection(
          title: '年龄',
          range: options.age,
          suffix: '岁',
          selectedMin: filterState.ageMin,
          selectedMax: filterState.ageMax,
          onChanged: (range) => onChanged(
            filterState.copyWith(ageMin: range.$1, ageMax: range.$2),
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        ActorNumericRangeFilterSection(
          title: '身高',
          range: options.heightCm,
          suffix: ' cm',
          selectedMin: filterState.heightMin,
          selectedMax: filterState.heightMax,
          onChanged: (range) => onChanged(
            filterState.copyWith(heightMin: range.$1, heightMax: range.$2),
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        ActorCupFilterSection(
          options: options.cups,
          selectedCups: filterState.cups,
          onChanged: (cups) => onChanged(filterState.copyWith(cups: cups)),
        ),
      ],
    );
  }
}

class ActorNumericRangeFilterSection extends StatefulWidget {
  const ActorNumericRangeFilterSection({
    super.key,
    required this.title,
    required this.range,
    required this.suffix,
    required this.selectedMin,
    required this.selectedMax,
    required this.onChanged,
  });

  final String title;
  final ActorFilterRangeDto range;
  final String suffix;
  final int? selectedMin;
  final int? selectedMax;
  final ValueChanged<(int?, int?)> onChanged;

  @override
  State<ActorNumericRangeFilterSection> createState() =>
      _ActorNumericRangeFilterSectionState();
}

class _ActorNumericRangeFilterSectionState
    extends State<ActorNumericRangeFilterSection> {
  late RangeValues _values;

  bool get _hasValues => widget.range.hasValues;

  @override
  void initState() {
    super.initState();
    _values = _valuesFromWidget();
  }

  @override
  void didUpdateWidget(covariant ActorNumericRangeFilterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range.min != widget.range.min ||
        oldWidget.range.max != widget.range.max ||
        oldWidget.selectedMin != widget.selectedMin ||
        oldWidget.selectedMax != widget.selectedMax) {
      _values = _valuesFromWidget();
    }
  }

  RangeValues _valuesFromWidget() {
    if (!_hasValues) {
      return const RangeValues(0, 0);
    }
    final lower = widget.range.min!;
    final upper = widget.range.max!;
    final start = (widget.selectedMin ?? lower).clamp(lower, upper).toDouble();
    final end = (widget.selectedMax ?? upper).clamp(lower, upper).toDouble();
    return start <= end
        ? RangeValues(start, end)
        : RangeValues(lower.toDouble(), upper.toDouble());
  }

  void _apply(RangeValues values) {
    final lower = widget.range.min!;
    final upper = widget.range.max!;
    final selectedMin = values.start.round() <= lower
        ? null
        : values.start.round();
    final selectedMax = values.end.round() >= upper ? null : values.end.round();
    if (selectedMin != widget.selectedMin ||
        selectedMax != widget.selectedMax) {
      widget.onChanged((selectedMin, selectedMax));
    }
  }

  String _rangeLabel() {
    final lower = _values.start.round();
    final upper = _values.end.round();
    final min = widget.range.min;
    final max = widget.range.max;
    if (min == null || max == null || (lower == min && upper == max)) {
      return '不限';
    }
    if (lower == min) {
      return '≤ $upper${widget.suffix}';
    }
    if (upper == max) {
      return '≥ $lower${widget.suffix}';
    }
    return '$lower ~ $upper${widget.suffix}';
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s14,
      weight: AppTextWeight.regular,
      tone: AppTextTone.primary,
    );
    if (!_hasValues) {
      return Text('${widget.title}暂无可用资料', style: titleStyle);
    }
    if (widget.range.min == widget.range.max) {
      return Text(
        '${widget.title} ${widget.range.min}${widget.suffix}',
        style: titleStyle,
      );
    }
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.title, style: titleStyle),
            Text(
              _rangeLabel(),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                tone: AppTextTone.muted,
              ),
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.xs),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: context.appColors.divider,
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 7,
              disabledThumbRadius: 7,
              elevation: 0,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            overlayColor: colorScheme.primary.withValues(alpha: 0.10),
          ),
          child: RangeSlider(
            key: Key('actor-filter-${widget.title}-slider'),
            min: widget.range.min!.toDouble(),
            max: widget.range.max!.toDouble(),
            values: _values,
            onChanged: (values) => setState(() => _values = values),
            onChangeEnd: _apply,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.appSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.range.min}${widget.suffix}',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s10,
                  tone: AppTextTone.muted,
                ),
              ),
              Text(
                '${widget.range.max}${widget.suffix}',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s10,
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

class ActorCupFilterSection extends StatelessWidget {
  const ActorCupFilterSection({
    super.key,
    required this.options,
    required this.selectedCups,
    required this.onChanged,
  });

  final List<ActorCupFilterOptionDto> options;
  final List<String> selectedCups;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '罩杯',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        if (options.isEmpty)
          Text(
            '暂无可用资料',
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          )
        else
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.sm,
            children: options
                .map(
                  (option) => AppTextButton(
                    label: '${option.value} (${option.count})',
                    size: AppTextButtonSize.xSmall,
                    isSelected: selectedCups.contains(option.value),
                    onPressed: () {
                      final next = Set<String>.of(selectedCups);
                      if (!next.add(option.value)) {
                        next.remove(option.value);
                      }
                      final cups = next.toList()..sort();
                      onChanged(cups);
                    },
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }
}

class ActorFilterChoiceSection<T> extends StatelessWidget {
  const ActorFilterChoiceSection({
    super.key,
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
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        Wrap(
          spacing: context.appSpacing.sm,
          runSpacing: context.appSpacing.sm,
          children: options
              .map(
                (option) => AppTextButton(
                  label: labelBuilder(option),
                  size: AppTextButtonSize.xSmall,
                  isSelected: option == selectedValue,
                  onPressed: () => onSelected(option),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class ActorSortSection extends StatelessWidget {
  const ActorSortSection({
    super.key,
    required this.filterState,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
  });

  final ActorFilterState filterState;
  final ValueChanged<ActorSortField> onSortFieldChanged;
  final ValueChanged<ActorSortDirection> onSortDirectionChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '排序方式',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        Wrap(
          spacing: context.appSpacing.sm,
          runSpacing: context.appSpacing.sm,
          children: ActorSortField.values
              .map(
                (value) => AppTextButton(
                  label: value.label,
                  size: AppTextButtonSize.xSmall,
                  isSelected: value == filterState.sortField,
                  onPressed: () => onSortFieldChanged(value),
                ),
              )
              .toList(growable: false),
        ),
        SizedBox(height: context.appSpacing.md),
        Wrap(
          spacing: context.appSpacing.sm,
          runSpacing: context.appSpacing.sm,
          children: ActorSortDirection.values
              .map(
                (value) => AppTextButton(
                  label: value.label,
                  size: AppTextButtonSize.xSmall,
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
