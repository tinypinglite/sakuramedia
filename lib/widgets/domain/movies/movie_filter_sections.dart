import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_interaction_filter_options_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_interaction_filter_options_provider.dart';
import 'package:sakuramedia/features/plugins/presentation/providers/plugin_capabilities_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_chip.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_range_section.dart';

/// 影片筛选的所有 section（状态 / 分辨率 / 合集类型 / 番号来源 / 互动数范围 /
/// 出演年龄 / 年份 / 可选标签）的纵向 Column。
///
/// 桌面玻璃筛选浮层和移动 `MobileMovieFilterDrawer` 都用它，
/// 避免双份维护。底栏/重置按钮由调用方自己附加。
class MovieFilterSectionGroup extends ConsumerWidget {
  const MovieFilterSectionGroup({
    super.key,
    required this.filterState,
    required this.onChanged,
    this.tagSection,
    this.mediaTagSection,
    this.showActorAgeSection = true,
    this.yearOptions,
    this.isYearOptionsLoading = false,
    this.yearOptionsErrorMessage,
    this.onYearOptionsRetry,
  });

  final MovieFilterState filterState;
  final ValueChanged<MovieFilterState> onChanged;

  /// 可选的目录「标签」分节。标签云占用空间大，放在面板最末，
  /// 不前置挤压其它筛选维度；为空时不渲染。
  final Widget? tagSection;
  final Widget? mediaTagSection;

  /// 女优详情页的影片全部属于同一位女优，再按出演年龄筛选没有意义，
  /// 显式关闭该分节；普通影片列表保持默认展示。
  final bool showActorAgeSection;

  /// `null` 表示普通影片库，使用前端生成的 2008 年至当前年的固定范围；
  /// 女优详情传入非空列表，以展示接口返回的影片数量。
  final List<MovieFilterYearOption>? yearOptions;
  final bool isYearOptionsLoading;
  final String? yearOptionsErrorMessage;
  final VoidCallback? onYearOptionsRetry;

  bool get _shouldShowYearSection =>
      yearOptions == null ||
      yearOptions!.isNotEmpty ||
      isYearOptionsLoading ||
      yearOptionsErrorMessage != null ||
      filterState.years.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final statsEnabled = ref.watch(statsFeaturesEnabledProvider);
    final resolvedYearOptions =
        yearOptions ?? buildDefaultMovieFilterYearOptions();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFilterOptionSection<MovieStatusFilter>(
          title: l10n.widgetMovieFilterStatusTitle,
          options: MovieStatusFilter.values,
          selectedValue: filterState.status,
          labelBuilder: (value) => value.labelWith(l10n),
          onSelected: (value) => onChanged(filterState.copyWith(status: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterOptionSection<PlaylistResolutionFilter?>(
          title: l10n.widgetMovieFilterResolutionTitle,
          options: const [null, ...PlaylistResolutionFilter.values],
          selectedValue: filterState.resolution,
          labelBuilder: (value) => value?.label ?? l10n.widgetMovieFilterAll,
          enabled: filterState.status == MovieStatusFilter.playable,
          onSelected: (value) =>
              onChanged(filterState.copyWith(resolution: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterOptionSection<MovieCollectionTypeFilter>(
          title: l10n.widgetMovieFilterCollectionTypeTitle,
          options: MovieCollectionTypeFilter.values,
          selectedValue: filterState.collectionType,
          labelBuilder: (value) => value.labelWith(l10n),
          onSelected: (value) =>
              onChanged(filterState.copyWith(collectionType: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        AppFilterOptionSection<MovieNumberSourceFilter>(
          title: l10n.widgetMovieFilterNumberSourceTitle,
          options: MovieNumberSourceFilter.values,
          selectedValue: filterState.numberSource,
          labelBuilder: (value) => value.labelWith(l10n),
          onSelected: (value) =>
              onChanged(filterState.copyWith(numberSource: value)),
        ),
        if (statsEnabled) ...[
          SizedBox(height: context.appSpacing.lg),
          MovieInteractionRangeFilterSectionGroup(
            filter: filterState.interaction,
            onChanged: (interaction) =>
                onChanged(filterState.copyWith(interaction: interaction)),
          ),
        ],
        if (showActorAgeSection) ...[
          SizedBox(height: context.appSpacing.lg),
          MovieActorAgeRangeFilterSection(
            actorAgeMin: filterState.actorAgeMin,
            actorAgeMax: filterState.actorAgeMax,
            onChanged: (range) => onChanged(
              filterState.copyWith(
                actorAgeMin: range.$1,
                actorAgeMax: range.$2,
              ),
            ),
          ),
        ],
        if (_shouldShowYearSection) ...[
          SizedBox(height: context.appSpacing.lg),
          MovieYearFilterSection(
            options: resolvedYearOptions,
            selectedYears: filterState.years,
            isLoading: isYearOptionsLoading,
            errorMessage: yearOptionsErrorMessage,
            onRetry: onYearOptionsRetry,
            onChanged: (value) => onChanged(filterState.copyWith(years: value)),
          ),
        ],
        if (tagSection != null) ...[
          SizedBox(height: context.appSpacing.lg),
          tagSection!,
        ],
        if (mediaTagSection != null) ...[
          SizedBox(height: context.appSpacing.lg),
          mediaTagSection!,
        ],
      ],
    );
  }
}

/// 6 个互动数字段的平铺式范围筛选：每个字段一个标题 + 双滑块。
///
/// 左滑块拖到 0 = 下限不限；右滑块拖到顶 = 无上界；两者都映射为接口参数的
/// `null`（不传）。拖动中只更新面板内的值显示，松手（onChangeEnd）才应用请求。
class MovieInteractionRangeFilterSectionGroup extends ConsumerWidget {
  const MovieInteractionRangeFilterSectionGroup({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final MovieInteractionFilter filter;
  final ValueChanged<MovieInteractionFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final options = ref.watch(movieInteractionFilterOptionsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.widgetMovieFilterInteractionTitle,
              key: const Key('movie-filter-interaction-group-title'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.medium,
                tone: AppTextTone.secondary,
              ),
            ),
            if (!filter.isDefault)
              AppTextButton(
                key: const Key('movie-filter-interaction-clear'),
                label: l10n.widgetMovieFilterClear,
                size: AppTextButtonSize.xSmall,
                onPressed: () => onChanged(filter.clear()),
              ),
          ],
        ),
        SizedBox(height: context.appSpacing.sm),
        options.when(
          // 面板每次打开都会重新拉取范围；用同形占位滑块撑住高度，
          // 避免加载期间整组分节塌陷成一行文案。
          loading: () => AppSkeletonizer(
            child: _buildSections(
              context,
              movieInteractionFilterOptionsPlaceholder(),
            ),
          ),
          error: (_, _) => _buildStatus(
            context,
            l10n.widgetMovieFilterInteractionLoadFailed,
            onRetry: () =>
                ref.invalidate(movieInteractionFilterOptionsProvider),
          ),
          data: (value) => _buildSections(context, value),
        ),
      ],
    );
  }

  Widget _buildSections(
    BuildContext context,
    MovieInteractionFilterOptionsDto options,
  ) {
    final children = <Widget>[];
    for (final metric in MovieInteractionMetric.values) {
      final maxValue = options.sliderMaxFor(metric);
      if (maxValue == null || maxValue <= 0) {
        continue;
      }
      if (children.isNotEmpty) {
        children.add(SizedBox(height: context.appSpacing.md));
      }
      children.add(
        MovieInteractionRangeFilterSection(
          metric: metric,
          maxValue: maxValue.toDouble(),
          range: filter.rangeFor(metric),
          onChanged: (min, max) =>
              onChanged(filter.withRange(metric, min: min, max: max)),
        ),
      );
    }
    if (children.isEmpty) {
      return _buildStatus(
        context,
        AppLocalizations.of(context).widgetMovieFilterInteractionEmpty,
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildStatus(
    BuildContext context,
    String message, {
    VoidCallback? onRetry,
  }) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        if (onRetry != null) ...[
          SizedBox(width: context.appSpacing.sm),
          AppTextButton(
            label: l10n.commonRetry,
            size: AppTextButtonSize.xSmall,
            onPressed: onRetry,
          ),
        ],
      ],
    );
  }
}

class MovieInteractionRangeFilterSection extends StatelessWidget {
  const MovieInteractionRangeFilterSection({
    super.key,
    required this.metric,
    required this.maxValue,
    required this.range,
    required this.onChanged,
  });

  final MovieInteractionMetric metric;
  final double maxValue;
  final MovieInteractionRange? range;
  final void Function(num? min, num? max) onChanged;

  RangeValues get _values => RangeValues(
    (range?.min?.toDouble() ?? 0).clamp(0.0, maxValue),
    (range?.max?.toDouble() ?? maxValue).clamp(0.0, maxValue),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFilterRangeSection(
      title: metric.localizedLabel(l10n),
      titleKey: Key('movie-filter-${metric.apiValue}-section-title'),
      valueLabelBuilder: (values) {
        final min = metric.minFromSlider(values.start);
        final max = metric.maxFromSlider(values.end, maxValue);
        return movieInteractionRangeLabel(metric, min, max, l10n);
      },
      valueLabelKey: Key('movie-filter-${metric.apiValue}-range-label'),
      values: _values,
      min: 0,
      max: maxValue,
      divisions: metric.isDecimal ? (maxValue * 10).round() : null,
      minLabel: '0',
      maxLabel: metric.sliderMaxLabel(maxValue),
      sliderKey: Key('movie-filter-${metric.apiValue}-slider'),
      onChangeEnd: (values) {
        final min = metric.minFromSlider(values.start);
        final max = metric.maxFromSlider(values.end, maxValue);
        if (min != range?.min || max != range?.max) {
          onChanged(min, max);
        }
      },
    );
  }
}

/// 出演年龄双滑块筛选：18 ~ 50 岁，按最老女优在影片发行日（拍摄时间近似）
/// 的周岁过滤。
///
/// - 左滑块拖到 18 = 下限不限（数据域最小 18 岁）；右滑块拖到顶 = 无上界
///   （50 岁及以上都包含），两者都映射为接口参数的 `null`（不传）。
/// - 拖动中只更新面板内的值显示，松手（onChangeEnd）才应用请求。
class MovieActorAgeRangeFilterSection extends StatelessWidget {
  const MovieActorAgeRangeFilterSection({
    super.key,
    required this.actorAgeMin,
    required this.actorAgeMax,
    required this.onChanged,
  });

  final int? actorAgeMin;
  final int? actorAgeMax;
  final ValueChanged<(int?, int?)> onChanged;

  RangeValues get _values => RangeValues(
    (actorAgeMin ?? movieFilterActorAgeSliderMin).toDouble(),
    (actorAgeMax ?? movieFilterActorAgeSliderMax).toDouble(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppFilterRangeSection(
      title: l10n.widgetMovieFilterActorAgeTitle,
      titleKey: const Key('movie-filter-actor-age-section-title'),
      valueLabelBuilder: (values) => movieActorAgeRangeLabel(
        movieActorAgeMinFromSlider(values.start.round()),
        movieActorAgeMaxFromSlider(values.end.round()),
        l10n,
      ),
      valueLabelKey: const Key('movie-filter-actor-age-range-label'),
      values: _values,
      min: movieFilterActorAgeSliderMin.toDouble(),
      max: movieFilterActorAgeSliderMax.toDouble(),
      divisions: movieFilterActorAgeSliderMax - movieFilterActorAgeSliderMin,
      minLabel: '18',
      maxLabel: '50+',
      sliderKey: const Key('movie-filter-actor-age-slider'),
      onChangeEnd: (values) {
        final nextMin = movieActorAgeMinFromSlider(values.start.round());
        final nextMax = movieActorAgeMaxFromSlider(values.end.round());
        if (nextMin != actorAgeMin || nextMax != actorAgeMax) {
          onChanged((nextMin, nextMax));
        }
      },
    );
  }
}

class MovieYearFilterSection extends StatefulWidget {
  const MovieYearFilterSection({
    super.key,
    required this.options,
    required this.selectedYears,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.onChanged,
  });

  final List<MovieFilterYearOption> options;
  final Set<int> selectedYears;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<Set<int>> onChanged;

  @override
  State<MovieYearFilterSection> createState() => _MovieYearFilterSectionState();
}

class _MovieYearFilterSectionState extends State<MovieYearFilterSection> {
  static const int _collapsedRowCount = 2;

  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    // 当前已选年份可能在两行之外；首次打开时直接展开，避免筛选条件不可见。
    _isExpanded = widget.selectedYears.isNotEmpty;
  }

  @override
  void didUpdateWidget(covariant MovieYearFilterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedYears.isNotEmpty &&
        !setEquals(widget.selectedYears, oldWidget.selectedYears)) {
      _isExpanded = true;
    }
  }

  /// 点「全部年份」清空；点年份 chip 在选中集合里切换。
  void _toggleChoice(int? year) {
    final next = Set<int>.of(widget.selectedYears);
    if (year == null) {
      next.clear();
    } else if (!next.remove(year)) {
      next.add(year);
    }
    widget.onChanged(next);
  }

  int _collapsedChoiceCount(
    BuildContext context,
    List<_MovieYearChoice> choices,
    double maxWidth,
  ) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return choices.length;
    }

    final gap = context.appSpacing.sm;
    final horizontalPadding = context.appSpacing.md * 2 + 2;
    final labelStyle = resolveAppTextStyle(
      context,
      size: AppTextSize.s12,
      tone: AppTextTone.muted,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    var visibleCount = 0;
    var row = 1;
    var rowWidth = 0.0;

    for (final choice in choices) {
      final painter = TextPainter(
        text: TextSpan(text: choice.label, style: labelStyle),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final choiceWidth = (painter.width + horizontalPadding)
          .clamp(0.0, maxWidth)
          .toDouble();
      final nextWidth = rowWidth == 0
          ? choiceWidth
          : rowWidth + gap + choiceWidth;
      if (rowWidth > 0 && nextWidth > maxWidth) {
        row += 1;
        if (row > _collapsedRowCount) {
          break;
        }
        rowWidth = choiceWidth;
      } else {
        rowWidth = nextWidth;
      }
      visibleCount += 1;
    }
    return visibleCount;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.widgetMovieFilterYearTitle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        if (widget.isLoading)
          // 首次打开面板时年份选项还在加载：用同形年份药丸撑住两行高度，
          // 避免整节塌陷成一行「年份加载中」再展开。
          AppSkeletonizer(
            child: LayoutBuilder(
              builder: (context, constraints) => _buildYearChoices(
                context,
                constraints,
                // 刷新时沿用已有年份，保持与加载前完全同形；首次加载才用占位项。
                options: widget.options.isNotEmpty
                    ? widget.options
                    : movieFilterYearPlaceholders(),
                interactive: false,
              ),
            ),
          )
        else if (widget.errorMessage != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.errorMessage!,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              SizedBox(width: context.appSpacing.sm),
              AppTextButton(
                label: l10n.commonRetry,
                size: AppTextButtonSize.xSmall,
                onPressed: widget.onRetry,
              ),
            ],
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => _buildYearChoices(
              context,
              constraints,
              options: widget.options,
              interactive: true,
            ),
          ),
      ],
    );
  }

  Widget _buildYearChoices(
    BuildContext context,
    BoxConstraints constraints, {
    required List<MovieFilterYearOption> options,
    required bool interactive,
  }) {
    final l10n = AppLocalizations.of(context);
    final choices = <_MovieYearChoice>[
      _MovieYearChoice(value: null, label: l10n.widgetMovieFilterAllYears),
      for (final option in options)
        _MovieYearChoice(value: option.year, label: option.label),
    ];
    final collapsedCount = _collapsedChoiceCount(
      context,
      choices,
      constraints.maxWidth,
    );
    final hasHiddenChoices = choices.length > collapsedCount;
    final visibleChoices = _isExpanded || !hasHiddenChoices
        ? choices
        : choices.take(collapsedCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: context.appSpacing.sm,
          runSpacing: context.appSpacing.sm,
          children: [
            for (final choice in visibleChoices)
              AppFilterChip(
                key: Key(
                  choice.value == null
                      ? 'movie-filter-year-all'
                      : 'movie-filter-year-${choice.value}',
                ),
                label: choice.label,
                selected: choice.value == null
                    ? widget.selectedYears.isEmpty
                    : widget.selectedYears.contains(choice.value),
                onPressed: interactive
                    ? () => _toggleChoice(choice.value)
                    : null,
                enabled: interactive,
              ),
          ],
        ),
        if (hasHiddenChoices) ...[
          SizedBox(height: context.appSpacing.sm),
          AppTextButton(
            key: const Key('movie-filter-year-expand-toggle'),
            label: _isExpanded
                ? l10n.widgetMovieFilterCollapseYears
                : l10n.widgetMovieFilterExpandAllYears,
            size: AppTextButtonSize.xSmall,
            trailingIcon: Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
            onPressed: interactive
                ? () => setState(() {
                    _isExpanded = !_isExpanded;
                  })
                : null,
          ),
        ],
      ],
    );
  }
}

class _MovieYearChoice {
  const _MovieYearChoice({required this.value, required this.label});

  final int? value;
  final String label;
}
