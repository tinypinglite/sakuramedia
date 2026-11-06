import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/features/actors/data/dto/actor_filter_options_dto.dart';
import 'package:sakuramedia/features/actors/presentation/actor_placeholders.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/features/actors/presentation/providers/actor_filter_options_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_range_section.dart';

/// 演员筛选所有 section 的纵向 Column。
///
/// 桌面玻璃筛选浮层和移动 `MobileActorFilterDrawer` 都用它，
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
    final l10n = AppLocalizations.of(context);
    final optionsScope = ActorFilterOptionsScope(
      subscriptionStatus: filterState.subscriptionStatus,
      gender: filterState.gender,
    );
    final options = ref.watch(actorFilterOptionsProvider(optionsScope));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterOptionSection<ActorSubscriptionStatus>(
          title: l10n.widgetActorFilterSubscriptionTitle,
          options: ActorSubscriptionStatus.values,
          selectedValue: filterState.subscriptionStatus,
          labelBuilder: (value) => value.label(AppLocalizations.of(context)),
          onSelected: (value) =>
              onChanged(filterState.copyWith(subscriptionStatus: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterOptionSection<ActorGender>(
          title: l10n.widgetActorFilterGenderTitle,
          options: ActorGender.values,
          selectedValue: filterState.gender,
          labelBuilder: (value) => value.label(AppLocalizations.of(context)),
          onSelected: (value) => onChanged(filterState.copyWith(gender: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterOptionSection<bool>(
          title: l10n.widgetActorFilterPlayableTitle,
          options: const [false, true],
          selectedValue: filterState.hasPlayableMovies,
          labelBuilder: (value) => value
              ? l10n.widgetActorFilterHasPlayable
              : l10n.widgetActorFilterAll,
          optionKeyBuilder: (value) => Key(
            value ? 'actor-filter-playable-only' : 'actor-filter-playable-all',
          ),
          onSelected: (value) =>
              onChanged(filterState.copyWith(hasPlayableMovies: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        _ActorProfileFilterSectionsAsync(
          options: options,
          filterState: filterState,
          onChanged: onChanged,
          onRetry: () =>
              ref.invalidate(actorFilterOptionsProvider(optionsScope)),
        ),
      ],
    );
  }
}

class _ActorProfileFilterSectionsAsync extends StatefulWidget {
  const _ActorProfileFilterSectionsAsync({
    required this.options,
    required this.filterState,
    required this.onChanged,
    required this.onRetry,
  });

  final AsyncValue<ActorFilterOptionsDto> options;
  final ActorFilterState filterState;
  final ValueChanged<ActorFilterState> onChanged;
  final VoidCallback onRetry;

  @override
  State<_ActorProfileFilterSectionsAsync> createState() =>
      _ActorProfileFilterSectionsAsyncState();
}

class _ActorProfileFilterSectionsAsyncState
    extends State<_ActorProfileFilterSectionsAsync> {
  /// 上一次成功加载的 options。切换订阅 / 性别会创建新的 family 实例，
  /// 新实例没有缓存；沿用旧数据渲染骨架，可以保持与真实内容完全同形。
  ActorFilterOptionsDto? _lastOptions;

  @override
  Widget build(BuildContext context) {
    final data = widget.options.value;
    if (data != null) {
      _lastOptions = data;
    }
    return widget.options.when(
      data: (value) => ActorProfileFilterSections(
        filterState: widget.filterState,
        options: value,
        onChanged: widget.onChanged,
      ),
      loading: () => AppSkeletonizer(
        child: ActorProfileFilterSections(
          filterState: widget.filterState,
          options: _lastOptions ?? actorFilterOptionsPlaceholder(),
          onChanged: (_) {},
        ),
      ),
      error: (_, _) => _ActorProfileFilterOptionsMessage(
        message: AppLocalizations.of(
          context,
        ).widgetActorFilterOptionsLoadFailed,
        onRetry: widget.onRetry,
      ),
    );
  }
}

class _ActorProfileFilterOptionsMessage extends StatelessWidget {
  const _ActorProfileFilterOptionsMessage({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
            label: AppLocalizations.of(context).commonRetry,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActorNumericRangeFilterSection(
          title: l10n.widgetActorAgeLabel,
          range: options.age,
          suffix: l10n.widgetActorAgeUnit,
          selectedMin: filterState.ageMin,
          selectedMax: filterState.ageMax,
          onChanged: (range) => onChanged(
            filterState.copyWith(ageMin: range.$1, ageMax: range.$2),
          ),
        ),
        SizedBox(height: context.appSpacing.lg),
        ActorNumericRangeFilterSection(
          title: l10n.widgetActorHeightLabel,
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

class ActorNumericRangeFilterSection extends StatelessWidget {
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

  bool get _hasValues => range.hasValues;

  RangeValues get _values {
    if (!_hasValues) {
      return const RangeValues(0, 0);
    }
    final lower = range.min!;
    final upper = range.max!;
    final start = (selectedMin ?? lower).clamp(lower, upper).toDouble();
    final end = (selectedMax ?? upper).clamp(lower, upper).toDouble();
    return start <= end
        ? RangeValues(start, end)
        : RangeValues(lower.toDouble(), upper.toDouble());
  }

  void _apply(RangeValues values) {
    final lower = range.min!;
    final upper = range.max!;
    final nextMin = values.start.round() <= lower ? null : values.start.round();
    final nextMax = values.end.round() >= upper ? null : values.end.round();
    if (nextMin != selectedMin || nextMax != selectedMax) {
      onChanged((nextMin, nextMax));
    }
  }

  String _rangeLabel(AppLocalizations l10n, RangeValues values) {
    final lower = values.start.round();
    final upper = values.end.round();
    final min = range.min;
    final max = range.max;
    if (min == null || max == null || (lower == min && upper == max)) {
      return l10n.widgetActorFilterUnlimited;
    }
    if (lower == min) {
      return '≤ $upper$suffix';
    }
    if (upper == max) {
      return '≥ $lower$suffix';
    }
    return '$lower ~ $upper$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_hasValues) {
      return Text(
        l10n.widgetActorFilterNoProfileData(title),
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.medium,
          tone: AppTextTone.muted,
        ),
      );
    }
    if (range.min == range.max) {
      return Text(
        '$title ${range.min}$suffix',
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s12,
          weight: AppTextWeight.medium,
          tone: AppTextTone.secondary,
        ),
      );
    }
    return AppFilterRangeSection(
      title: title,
      values: _values,
      min: range.min!.toDouble(),
      max: range.max!.toDouble(),
      valueLabelBuilder: (values) => _rangeLabel(l10n, values),
      minLabel: '${range.min}$suffix',
      maxLabel: '${range.max}$suffix',
      sliderKey: Key('actor-filter-$title-slider'),
      onChangeEnd: _apply,
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
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.widgetActorCupLabel,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        if (options.isEmpty)
          Text(
            l10n.widgetActorFilterNoData,
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
                  (option) => AppFilterChip(
                    label: '${option.value} (${option.count})',
                    selected: selectedCups.contains(option.value),
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
