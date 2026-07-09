import 'package:flutter/material.dart';
import 'package:sakuramedia/features/actors/presentation/controllers/listing/actor_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 演员筛选所有 section 的纵向 Column。
///
/// 桌面 `ActorFilterToolbar` 的浮层 panel 和移动 `MobileActorFilterDrawer` 都用它，
/// 避免双份维护。底栏/重置按钮由调用方自己附加。
class ActorFilterSectionGroup extends StatelessWidget {
  const ActorFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.onChanged,
  });

  final ActorFilterState filterState;
  final ValueChanged<ActorFilterState> onChanged;

  @override
  Widget build(BuildContext context) {
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
          onSelected: (value) =>
              onChanged(filterState.copyWith(gender: value)),
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
