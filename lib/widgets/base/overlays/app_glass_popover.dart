import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/features/shared/data/sort_direction.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/forms/app_filter_choice_section.dart';
import 'package:sakuramedia/widgets/base/forms/app_segmented_control.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_chrome_settings.dart';

typedef AppGlassPopoverTriggerBuilder =
    Widget Function(BuildContext context, VoidCallback toggle);
typedef AppGlassPopoverContentBuilder =
    Widget Function(BuildContext context, VoidCallback close);

/// 桌面玻璃筛选 / 排序弹层的通用外壳。
///
/// 只负责触发器、弹层宽度和 footer；筛选或排序的选项内容由调用方提供。
class AppGlassPopover extends StatelessWidget {
  const AppGlassPopover({
    super.key,
    required this.triggerBuilder,
    required this.contentBuilder,
    this.panelKey,
    this.footer,
    this.footerBuilder,
    this.onOpened,
    this.scrollable = false,
    this.scrollViewKey,
  });

  final AppGlassPopoverTriggerBuilder triggerBuilder;
  final AppGlassPopoverContentBuilder contentBuilder;

  /// 内容根节点的 Key，测试用它判断弹层是否已经打开。
  final Key? panelKey;

  final Widget? footer;
  final Widget Function(BuildContext context, VoidCallback close)?
  footerBuilder;
  final VoidCallback? onOpened;

  /// 复杂筛选面板开启：内容区限高并独立滚动，footer 保持固定。
  final bool scrollable;
  final Key? scrollViewKey;

  @override
  Widget build(BuildContext context) {
    return GlassPopover(
      popoverWidth: 468,
      popoverBorderRadius: 24,
      autoAdjustToScreen: true,
      screenPadding: const EdgeInsets.all(16),
      quality: GlassQuality.minimal,
      settings: appGlassPopoverSettings(context),
      triggerBuilder: triggerBuilder,
      onOpen: onOpened,
      contentBuilder: (context, close) => _buildPanel(context, close),
    );
  }

  Widget _buildPanel(BuildContext context, VoidCallback close) {
    final spacing = context.appSpacing;
    final footerWidget = footerBuilder?.call(context, close) ?? footer;
    final body = contentBuilder(context, close);
    final scrollableBody = scrollable
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.65,
            ),
            child: SingleChildScrollView(key: scrollViewKey, child: body),
          )
        : body;
    final content = Padding(
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          scrollableBody,
          if (footerWidget != null) ...[
            SizedBox(height: spacing.lg),
            footerWidget,
          ],
        ],
      ),
    );
    return KeyedSubtree(key: panelKey, child: content);
  }
}

/// 排序字段 + 方向的玻璃分节。
///
/// 桌面弹层和移动抽屉共用；字段可空时由 [allowDefaultOption] 提供「默认」
/// 选项，方向是否显示由 [directionVisibleWhen] 控制。
class AppGlassSortSection<F> extends StatelessWidget {
  const AppGlassSortSection({
    super.key,
    required this.fields,
    required this.selectedField,
    required this.fieldLabelBuilder,
    required this.onFieldChanged,
    required this.selectedDirection,
    required this.onDirectionChanged,
    this.directionVisibleWhen,
    this.allowDefaultOption = false,
    this.defaultOptionLabel,
    this.fieldKeyBuilder,
    this.directionKeyBuilder,
    this.defaultOptionKey,
    this.fieldControlKey,
    this.directionControlKey,
  });

  final List<F> fields;
  final F? selectedField;
  final String Function(F field) fieldLabelBuilder;
  final ValueChanged<F?> onFieldChanged;
  final SortDirection selectedDirection;
  final ValueChanged<SortDirection> onDirectionChanged;
  final bool Function(F? field)? directionVisibleWhen;
  final bool allowDefaultOption;
  final String? defaultOptionLabel;
  final Key? Function(F field)? fieldKeyBuilder;
  final Key? Function(SortDirection direction)? directionKeyBuilder;
  final Key? defaultOptionKey;
  final Key? fieldControlKey;
  final Key? directionControlKey;

  bool get _showDirection => directionVisibleWhen?.call(selectedField) ?? true;

  @override
  Widget build(BuildContext context) {
    final l10n = appL10n(context);
    final spacing = context.appSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFilterChoiceSection<F?>(
          title: l10n.baseSortTitle,
          controlKey: fieldControlKey,
          items: <AppSegmentedItem<F?>>[
            if (allowDefaultOption)
              AppSegmentedItem<F?>(
                value: null,
                label: defaultOptionLabel ?? l10n.baseSortDefault,
                key: defaultOptionKey,
              ),
            for (final field in fields)
              AppSegmentedItem<F?>(
                value: field,
                label: fieldLabelBuilder(field),
                key: fieldKeyBuilder?.call(field),
              ),
          ],
          selected: selectedField,
          onChanged: onFieldChanged,
        ),
        if (_showDirection) ...[
          SizedBox(height: spacing.lg),
          AppFilterChoiceSection<SortDirection>(
            title: l10n.baseSortDirectionTitle,
            controlKey: directionControlKey,
            items: <AppSegmentedItem<SortDirection>>[
              for (final direction in SortDirection.values)
                AppSegmentedItem<SortDirection>(
                  value: direction,
                  label: direction.label(l10n),
                  key: directionKeyBuilder?.call(direction),
                ),
            ],
            selected: selectedDirection,
            onChanged: onDirectionChanged,
          ),
        ],
      ],
    );
  }
}

/// 筛选弹层底栏：左侧即时生效提示，右侧重置。
class AppGlassFilterFooter extends StatelessWidget {
  const AppGlassFilterFooter({
    super.key,
    required this.isDefault,
    required this.onReset,
    this.resetKey,
  });

  final bool isDefault;
  final VoidCallback? onReset;
  final Key? resetKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          appL10n(context).baseFilterAppliesImmediately,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            weight: AppTextWeight.regular,
            tone: AppTextTone.muted,
          ),
        ),
        const Spacer(),
        AppGlassResetButton(
          enabled: !isDefault,
          onPressed: onReset,
          buttonKey: resetKey,
        ),
      ],
    );
  }
}

/// 玻璃弹层里的中性重置按钮。
class AppGlassResetButton extends StatelessWidget {
  const AppGlassResetButton({
    super.key,
    required this.enabled,
    required this.onPressed,
    this.buttonKey,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spacing = context.appSpacing;
    return GlassButton.custom(
      key: buttonKey,
      onTap: onPressed ?? () {},
      enabled: enabled && onPressed != null,
      height: 34,
      shape: const LiquidRoundedRectangle(borderRadius: 17),
      style: GlassButtonStyle.filled,
      settings: LiquidGlassSettings(
        glassColor: context.appColors.highlight.withValues(
          alpha: isDark ? 0.12 : 0.58,
        ),
        thickness: 18,
        frost: 6,
        frostOpacity: 0.5,
        rimLight: 1.4,
        shadowElevation: 0,
        bodyMode: GlassBodyMode.clear,
      ),
      quality: GlassQuality.standard,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: spacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restart_alt_rounded,
              size: context.appComponentTokens.iconSize2xs,
            ),
            SizedBox(width: spacing.xs),
            Text(
              appL10n(context).baseFilterReset,
              style: resolveAppTextStyle(
                context,
                size: AppTextSize.s12,
                weight: AppTextWeight.medium,
                tone: AppTextTone.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
