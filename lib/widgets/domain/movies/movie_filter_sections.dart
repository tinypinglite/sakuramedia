import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/movies/data/dto/listing/movie_interaction_filter_options_dto.dart';
import 'package:sakuramedia/features/movies/presentation/controllers/listing/movie_filter_state.dart';
import 'package:sakuramedia/features/movies/presentation/movie_placeholders.dart';
import 'package:sakuramedia/features/movies/presentation/providers/movie_interaction_filter_options_provider.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_text_button.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';

/// 影片筛选的所有 section（状态 / 分辨率 / 合集类型 / 番号来源 / 互动数范围 /
/// 出演年龄 / 年份 / 可选标签）的纵向 Column。
///
/// 桌面 `AppListHeader` 的就地浮层 panel 和移动 `MobileMovieFilterDrawer` 都用它，
/// 避免双份维护。底栏/重置按钮由调用方自己附加。
class MovieFilterSectionGroup extends StatelessWidget {
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

  /// 可选的「标签」分节（女优详情传入）。标签云占用空间大，放在面板最末，
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolvedYearOptions =
        yearOptions ?? buildDefaultMovieFilterYearOptions();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MovieFilterChoiceSection<MovieStatusFilter>(
          title: l10n.widgetMovieFilterStatusTitle,
          options: MovieStatusFilter.values,
          selectedValue: filterState.status,
          labelBuilder: (value) => value.labelWith(l10n),
          onSelected: (value) => onChanged(filterState.copyWith(status: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        MovieFilterChoiceSection<PlaylistResolutionFilter?>(
          title: l10n.widgetMovieFilterResolutionTitle,
          options: const [null, ...PlaylistResolutionFilter.values],
          selectedValue: filterState.resolution,
          labelBuilder: (value) => value?.label ?? l10n.widgetMovieFilterAll,
          enabled: filterState.status == MovieStatusFilter.playable,
          onSelected: (value) =>
              onChanged(filterState.copyWith(resolution: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        MovieFilterChoiceSection<MovieCollectionTypeFilter>(
          title: l10n.widgetMovieFilterCollectionTypeTitle,
          options: MovieCollectionTypeFilter.values,
          selectedValue: filterState.collectionType,
          labelBuilder: (value) => value.labelWith(l10n),
          onSelected: (value) =>
              onChanged(filterState.copyWith(collectionType: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        MovieFilterChoiceSection<MovieNumberSourceFilter>(
          title: l10n.widgetMovieFilterNumberSourceTitle,
          options: MovieNumberSourceFilter.values,
          selectedValue: filterState.numberSource,
          labelBuilder: (value) => value.labelWith(l10n),
          onSelected: (value) =>
              onChanged(filterState.copyWith(numberSource: value)),
        ),
        SizedBox(height: context.appSpacing.lg),
        MovieInteractionRangeFilterSectionGroup(
          filter: filterState.interaction,
          onChanged: (interaction) =>
              onChanged(filterState.copyWith(interaction: interaction)),
        ),
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

class MovieFilterChoiceSection<T> extends StatelessWidget {
  const MovieFilterChoiceSection({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.labelBuilder,
    required this.onSelected,
    this.optionKeyBuilder,
    this.enabled = true,
    this.isLoading = false,
  });

  static const Duration _optionsSwitchDuration = Duration(milliseconds: 180);
  static const Duration _optionsResizeDuration = Duration(milliseconds: 200);

  /// 加载态 options 的固定切换 key：占位文案会变，不能拿它当动画签名。
  static const ValueKey<String> _loadingOptionsKey = ValueKey<String>(
    '__movie-filter-choice-loading__',
  );

  final String title;
  final bool enabled;
  final List<T> options;

  /// 可为空：`null` 表示「全选 / 默认」没有任何选项被选中（如榜单周期未选）。
  final T? selectedValue;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;

  /// 给每个选项 chip 生成稳定 Key（测试锚点）。不传则不挂 Key。
  final Key Function(T value)? optionKeyBuilder;

  /// options 是否正在加载。为 `true` 时应传入占位 options，选项区以
  /// [AppSkeletonizer] 骨架显示，并屏蔽点击；就绪后与真实选项交叉淡入。
  final bool isLoading;

  /// 选项集合的动画签名。只改选中态时签名不变，不会触发整组切换动画。
  ValueKey<String> get _optionsKey {
    if (isLoading) {
      return _loadingOptionsKey;
    }
    return ValueKey<String>(options.map(labelBuilder).join('\u0001'));
  }

  static Widget _optionsSwitcherLayout(
    Widget? currentChild,
    List<Widget> previousChildren,
  ) {
    return Stack(
      alignment: Alignment.topLeft,
      children: [...previousChildren, ?currentChild],
    );
  }

  static Widget _optionsSwitcherTransition(
    Widget child,
    Animation<double> animation,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

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
            tone: enabled ? AppTextTone.primary : AppTextTone.muted,
          ),
        ),
        SizedBox(height: context.appSpacing.sm),
        AnimatedSize(
          duration: _optionsResizeDuration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: _optionsSwitchDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: _optionsSwitcherLayout,
            transitionBuilder: _optionsSwitcherTransition,
            child: KeyedSubtree(
              key: _optionsKey,
              // AppSkeletonizer 放在 AnimatedSwitcher 内部：骨架淡出期间
              // 旧子树仍持有 enabled=true，不会露出占位文案。
              child: AppSkeletonizer(
                enabled: isLoading,
                child: Wrap(
                  spacing: context.appSpacing.sm,
                  runSpacing: context.appSpacing.sm,
                  children: options
                      .map(
                        (value) => AppTextButton(
                          key: optionKeyBuilder?.call(value),
                          label: labelBuilder(value),
                          size: AppTextButtonSize.xSmall,
                          isSelected: value == selectedValue,
                          onPressed: enabled ? () => onSelected(value) : null,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ),
        ),
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
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.primary,
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

class MovieInteractionRangeFilterSection extends StatefulWidget {
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

  @override
  State<MovieInteractionRangeFilterSection> createState() =>
      _MovieInteractionRangeFilterSectionState();
}

class _MovieInteractionRangeFilterSectionState
    extends State<MovieInteractionRangeFilterSection> {
  late RangeValues _values;

  @override
  void initState() {
    super.initState();
    _values = _valuesFrom(widget.range);
  }

  @override
  void didUpdateWidget(covariant MovieInteractionRangeFilterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.range?.min != widget.range?.min ||
        oldWidget.range?.max != widget.range?.max ||
        oldWidget.metric != widget.metric ||
        oldWidget.maxValue != widget.maxValue) {
      // 外部状态变化（重置筛选 / 其他入口改条件）时同步滑块位置；
      // onChangeEnd 应用后回传的值与此处推导一致，不会闪烁。
      _values = _valuesFrom(widget.range);
    }
  }

  RangeValues _valuesFrom(MovieInteractionRange? range) => RangeValues(
    (range?.min?.toDouble() ?? 0).clamp(0.0, widget.maxValue),
    (range?.max?.toDouble() ?? widget.maxValue).clamp(0.0, widget.maxValue),
  );

  void _apply(RangeValues values) {
    final min = widget.metric.minFromSlider(values.start);
    final max = widget.metric.maxFromSlider(values.end, widget.maxValue);
    if (min != widget.range?.min || max != widget.range?.max) {
      widget.onChanged(min, max);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final min = widget.metric.minFromSlider(_values.start);
    final max = widget.metric.maxFromSlider(_values.end, widget.maxValue);
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.metric.localizedLabel(l10n),
              key: Key('movie-filter-${widget.metric.apiValue}-section-title'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.primary,
              ),
            ),
            Text(
              movieInteractionRangeLabel(widget.metric, min, max, l10n),
              key: Key('movie-filter-${widget.metric.apiValue}-range-label'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.xs),
        // 桌面筛选面板内的滑块保持克制的体量：3px 细轨道 + 小扁平 thumb，
        // 拖动反馈用 10% 品牌色的浅晕圈。
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
            key: Key('movie-filter-${widget.metric.apiValue}-slider'),
            min: 0,
            max: widget.maxValue,
            divisions: widget.metric.isDecimal
                ? (widget.maxValue * 10).round()
                : null,
            values: _values,
            onChanged: (values) => setState(() => _values = values),
            onChangeEnd: _apply,
          ),
        ),
        // 两端刻度与 thumb 中心对齐（轨道两端各内缩一个 overlay 半径）。
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.appSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s10,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              Text(
                widget.metric.sliderMaxLabel(widget.maxValue),
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

/// 出演年龄双滑块筛选：18 ~ 50 岁，按最老女优在影片发行日（拍摄时间近似）
/// 的周岁过滤。
///
/// - 左滑块拖到 18 = 下限不限（数据域最小 18 岁）；右滑块拖到顶 = 无上界
///   （50 岁及以上都包含），两者都映射为接口参数的 `null`（不传）。
/// - 拖动中只更新面板内的值显示，松手（onChangeEnd）才应用请求。
class MovieActorAgeRangeFilterSection extends StatefulWidget {
  const MovieActorAgeRangeFilterSection({
    super.key,
    required this.actorAgeMin,
    required this.actorAgeMax,
    required this.onChanged,
  });

  final int? actorAgeMin;
  final int? actorAgeMax;
  final ValueChanged<(int?, int?)> onChanged;

  @override
  State<MovieActorAgeRangeFilterSection> createState() =>
      _MovieActorAgeRangeFilterSectionState();
}

class _MovieActorAgeRangeFilterSectionState
    extends State<MovieActorAgeRangeFilterSection> {
  late RangeValues _values;

  @override
  void initState() {
    super.initState();
    _values = _valuesFrom(widget.actorAgeMin, widget.actorAgeMax);
  }

  @override
  void didUpdateWidget(covariant MovieActorAgeRangeFilterSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actorAgeMin != widget.actorAgeMin ||
        oldWidget.actorAgeMax != widget.actorAgeMax) {
      // 外部状态变化（重置筛选 / 其他入口改条件）时同步滑块位置；
      // onChangeEnd 应用后回传的值与此处推导一致，不会闪烁。
      _values = _valuesFrom(widget.actorAgeMin, widget.actorAgeMax);
    }
  }

  static RangeValues _valuesFrom(int? actorAgeMin, int? actorAgeMax) =>
      RangeValues(
        (actorAgeMin ?? movieFilterActorAgeSliderMin).toDouble(),
        (actorAgeMax ?? movieFilterActorAgeSliderMax).toDouble(),
      );

  void _apply(RangeValues values) {
    final actorAgeMin = movieActorAgeMinFromSlider(values.start.round());
    final actorAgeMax = movieActorAgeMaxFromSlider(values.end.round());
    if (actorAgeMin != widget.actorAgeMin ||
        actorAgeMax != widget.actorAgeMax) {
      widget.onChanged((actorAgeMin, actorAgeMax));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actorAgeMin = movieActorAgeMinFromSlider(_values.start.round());
    final actorAgeMax = movieActorAgeMaxFromSlider(_values.end.round());
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.widgetMovieFilterActorAgeTitle,
              key: const Key('movie-filter-actor-age-section-title'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s14,
                weight: AppTextWeight.regular,
                tone: AppTextTone.primary,
              ),
            ),
            Text(
              movieActorAgeRangeLabel(actorAgeMin, actorAgeMax, l10n),
              key: const Key('movie-filter-actor-age-range-label'),
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.regular,
                tone: AppTextTone.muted,
              ),
            ),
          ],
        ),
        SizedBox(height: context.appSpacing.xs),
        // 与热度条同款的克制体量：3px 细轨道 + 小扁平 thumb，
        // 拖动反馈用 10% 品牌色的浅晕圈；年龄按整数年吸附。
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
            key: const Key('movie-filter-actor-age-slider'),
            min: movieFilterActorAgeSliderMin.toDouble(),
            max: movieFilterActorAgeSliderMax.toDouble(),
            divisions:
                movieFilterActorAgeSliderMax - movieFilterActorAgeSliderMin,
            values: _values,
            onChanged: (values) => setState(() => _values = values),
            onChangeEnd: _apply,
          ),
        ),
        // 两端刻度与 thumb 中心对齐（轨道两端各内缩一个 overlay 半径）。
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.appSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '18',
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s10,
                  weight: AppTextWeight.regular,
                  tone: AppTextTone.muted,
                ),
              ),
              Text(
                '50+',
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

    final componentTokens = context.appComponentTokens;
    final gap = context.appSpacing.sm;
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
      final choiceWidth =
          (painter.width + componentTokens.buttonHorizontalPaddingXs * 2)
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
            size: AppTextSize.s14,
            weight: AppTextWeight.regular,
            tone: AppTextTone.primary,
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
              AppTextButton(
                key: Key(
                  choice.value == null
                      ? 'movie-filter-year-all'
                      : 'movie-filter-year-${choice.value}',
                ),
                label: choice.label,
                size: AppTextButtonSize.xSmall,
                isSelected: choice.value == null
                    ? widget.selectedYears.isEmpty
                    : widget.selectedYears.contains(choice.value),
                onPressed: interactive
                    ? () => _toggleChoice(choice.value)
                    : null,
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
