import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/feedback/app_skeletonizer.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';

/// 筛选面板里的单选分节：小标题 + 分段控件。
///
/// 所有筛选面板统一走这里，避免不同页面各自拼 chip、标题字号和间距。
class AppFilterChoiceSection<T> extends StatelessWidget {
  const AppFilterChoiceSection({
    super.key,
    required this.title,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.isLoading = false,
    this.controlKey,
    this.titleKey,
    this.emptyLabel,
  });

  final String title;
  final List<AppSegmentedItem<T>> items;

  /// `null` 表示当前没有选中项；控件会回退到第一项，但不会触发回调。
  final T? selected;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool isLoading;
  final Key? controlKey;
  final Key? titleKey;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final canInteract = enabled && !isLoading;
    final resolvedItems = items;
    final resolvedSelected = resolvedItems.isEmpty
        ? null
        : resolvedItems
              .firstWhere(
                (item) => item.value == selected,
                orElse: () => resolvedItems.first,
              )
              .value;
    final control = resolvedItems.isEmpty
        ? (isLoading ? _buildEmptyControl(context) : const SizedBox.shrink())
        : AppSegmentedControl<T>(
            key: controlKey,
            items: resolvedItems,
            selected: resolvedSelected as T,
            onChanged: canInteract ? onChanged : (_) {},
            tone: AppSegmentedTone.neutral,
            layout: AppSegmentedLayout.auto,
            enabled: canInteract,
          );
    final trackedControl = Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: context.appColors.mediaOverlaySoft,
        borderRadius: context.appRadius.pillBorder,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
      child: control,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          key: titleKey,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.medium,
            tone: enabled ? AppTextTone.secondary : AppTextTone.muted,
          ),
        ),
        SizedBox(height: spacing.sm),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: isLoading
              ? AppSkeletonizer(enabled: true, child: trackedControl)
              : trackedControl,
        ),
        if (resolvedItems.isEmpty && (emptyLabel?.isNotEmpty ?? false)) ...[
          SizedBox(height: spacing.xs),
          Text(
            emptyLabel!,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              tone: AppTextTone.muted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyControl(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: context.appColors.surfaceMuted,
        borderRadius: context.appRadius.pillBorder,
      ),
    );
  }
}

/// 用枚举 / DTO 选项快速构建筛选单选分节。
///
/// 只负责把 `options + labelBuilder` 映射成 [AppSegmentedItem]，不引入第二种
/// 表面或交互。业务域直接复用这一层，不需要在各自 feature 里再包一份。
class AppFilterOptionSection<T> extends StatelessWidget {
  const AppFilterOptionSection({
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

  final String title;
  final List<T> options;
  final T? selectedValue;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onSelected;
  final Key Function(T value)? optionKeyBuilder;
  final bool enabled;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AppFilterChoiceSection<T>(
      title: title,
      items: <AppSegmentedItem<T>>[
        for (final value in options)
          AppSegmentedItem<T>(
            value: value,
            label: labelBuilder(value),
            key: optionKeyBuilder?.call(value),
          ),
      ],
      selected: selectedValue,
      onChanged: onSelected,
      enabled: enabled,
      isLoading: isLoading,
    );
  }
}
