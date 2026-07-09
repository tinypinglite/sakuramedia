import 'package:flutter/material.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';

/// 影片筛选的所有 section（状态 / 合集类型 / 番号来源 / 年份 / 排序）的纵向 Column。
///
/// 桌面 `MovieFilterToolbar` 的浮层 panel 和移动 `MobileMovieFilterDrawer` 都用它，
/// 避免双份维护。底栏/重置按钮由调用方自己附加。
class MovieFilterSectionGroup extends StatelessWidget {
  const MovieFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.onChanged,
    this.yearOptions = const <MovieFilterYearOption>[],
    this.isYearOptionsLoading = false,
    this.yearOptionsErrorMessage,
    this.onYearOptionsRetry,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onChanged;
  final List<MovieFilterYearOption> yearOptions;
  final bool isYearOptionsLoading;
  final String? yearOptionsErrorMessage;
  final VoidCallback? onYearOptionsRetry;

  bool get _shouldShowYearSection =>
      yearOptions.isNotEmpty ||
      isYearOptionsLoading ||
      yearOptionsErrorMessage != null ||
      filterState.year != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieFilterChoiceSection<MovieStatusFilter>(
          title: '状态筛选',
          options: MovieStatusFilter.values,
          selectedValue: filterState.status,
          labelBuilder: (value) => value.label,
          onSelected:
              (value) => onChanged(filterState.copyWith(status: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        MovieFilterChoiceSection<MovieCollectionTypeFilter>(
          title: '合集类型',
          options: MovieCollectionTypeFilter.values,
          selectedValue: filterState.collectionType,
          labelBuilder: (value) => value.label,
          onSelected:
              (value) => onChanged(filterState.copyWith(collectionType: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        MovieFilterChoiceSection<MovieNumberSourceFilter>(
          title: '番号来源',
          options: MovieNumberSourceFilter.values,
          selectedValue: filterState.numberSource,
          labelBuilder: (value) => value.label,
          onSelected:
              (value) => onChanged(filterState.copyWith(numberSource: value)),
        ),
        if (_shouldShowYearSection) ...[
          SizedBox(height: context.appSpacing.lg),
          MovieYearFilterSection(
            options: yearOptions,
            selectedYear: filterState.year,
            isLoading: isYearOptionsLoading,
            errorMessage: yearOptionsErrorMessage,
            onRetry: onYearOptionsRetry,
            onSelected: (value) => onChanged(filterState.copyWith(year: value)),
          ),
        ],
        SizedBox(height: context.appSpacing.lg),
        MovieSortSection(
          filterState: filterState,
          onSortFieldChanged:
              (value) => onChanged(filterState.copyWith(sortField: value)),
          onSortDirectionChanged:
              (value) => onChanged(filterState.copyWith(sortDirection: value)),
        ),
      ],
    );
  }
}

class MovieFilterChoiceSection<T> extends StatelessWidget {
  const MovieFilterChoiceSection({
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
          children:
              options
                  .map(
                    (value) => AppTextButton(
                      label: labelBuilder(value),
                      size: AppTextButtonSize.xSmall,
                      isSelected: value == selectedValue,
                      onPressed: () => onSelected(value),
                    ),
                  )
                  .toList(growable: false),
        ),
      ],
    );
  }
}

class MovieYearFilterSection extends StatelessWidget {
  const MovieYearFilterSection({
    super.key,
    required this.options,
    required this.selectedYear,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onSelected,
  });

  final List<MovieFilterYearOption> options;
  final int? selectedYear;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '发行年份',
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.primary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        if (isLoading)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              SizedBox(width: context.appSpacing.sm),
              Text(
                '年份加载中',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
            ],
          )
        else if (errorMessage != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                errorMessage!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              SizedBox(width: context.appSpacing.sm),
              AppTextButton(
                label: '重试',
                size: AppTextButtonSize.xSmall,
                onPressed: onRetry,
              ),
            ],
          )
        else
          Wrap(
            spacing: context.appSpacing.sm,
            runSpacing: context.appSpacing.sm,
            children: [
              AppTextButton(
                label: '全部年份',
                size: AppTextButtonSize.xSmall,
                isSelected: selectedYear == null,
                onPressed: () => onSelected(null),
              ),
              for (final option in options)
                AppTextButton(
                  label: option.label,
                  size: AppTextButtonSize.xSmall,
                  isSelected: option.year == selectedYear,
                  onPressed: () => onSelected(option.year),
                ),
            ],
          ),
      ],
    );
  }
}

class MovieSortSection extends StatelessWidget {
  const MovieSortSection({
    super.key,
    required this.filterState,
    required this.onSortFieldChanged,
    required this.onSortDirectionChanged,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieSortField> onSortFieldChanged;
  final ValueChanged<SortDirection> onSortDirectionChanged;

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
          children:
              MovieSortField.values
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
          children:
              SortDirection.values
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
