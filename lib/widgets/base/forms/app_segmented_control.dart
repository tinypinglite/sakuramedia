import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_pill.dart';
import 'package:sakuramedia/widgets/base/layout/glass/app_glass_surface.dart';

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
  final Key? key;
}

enum AppSegmentedSize { compact, regular }

/// 单选分段控件：玻璃凹槽 track + 实色选中 pill。
///
/// - 选项少、需要一眼看到全部时用；选项多到放不下时传 [scrollable]。
/// - 颜色/圆角/高度全部由这里决定，业务只传值和文案。
/// - 选中态用 [AppPillTone.selected] 的实色表面，不和 track 叠玻璃。
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.size = AppSegmentedSize.regular,
    this.scrollable = false,
  });

  final List<AppSegmentedItem<T>> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final AppSegmentedSize size;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    assert(items.isNotEmpty, 'AppSegmentedControl needs at least one item');
    final spacing = context.appSpacing;
    final track = AppGlassSurface(
      tone: AppGlassTone.track,
      borderRadius: context.appRadius.pillBorder,
      padding: EdgeInsets.all(spacing.xs / 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var index = 0; index < items.length; index++) ...<Widget>[
            if (index > 0) SizedBox(width: spacing.xs / 2),
            _AppSegmentedItemButton<T>(
              item: items[index],
              selected: items[index].value == selected,
              size: size,
              onTap: () => onChanged(items[index].value),
            ),
          ],
        ],
      ),
    );

    if (!scrollable) {
      return track;
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: track,
    );
  }
}

class _AppSegmentedItemButton<T> extends StatelessWidget {
  const _AppSegmentedItemButton({
    required this.item,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  final AppSegmentedItem<T> item;
  final bool selected;
  final AppSegmentedSize size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = resolveAppPillColors(context, AppPillTone.selected);
    final spec = _AppSegmentedSizeSpec.resolve(context, size);
    final inheritedFontFamily = DefaultTextStyle.of(context).style.fontFamily;
    final baseTextStyle = resolveAppTextStyle(
      context,
      size: spec.textSize,
      weight: AppTextWeight.regular,
      tone: AppTextTone.primary,
    );
    final foreground = selected
        ? colors.foreground
        : context.appTextPalette.secondary;

    return Semantics(
      button: true,
      selected: selected,
      child: AppInteractiveSurface(
        key: item.key,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: spec.horizontalPadding,
            vertical: spec.verticalPadding,
          ),
          decoration: BoxDecoration(
            color: selected ? colors.background : Colors.transparent,
            borderRadius: context.appRadius.pillBorder,
            border: Border.all(
              color: selected ? colors.border! : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (item.icon != null) ...[
                IconTheme(
                  data: IconThemeData(size: spec.iconSize, color: foreground),
                  child: item.icon!,
                ),
                SizedBox(width: context.appSpacing.xs),
              ],
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                style: baseTextStyle.copyWith(
                  color: foreground,
                  fontFamily: baseTextStyle.fontFamily ?? inheritedFontFamily,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppSegmentedSizeSpec {
  const _AppSegmentedSizeSpec({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.textSize,
    required this.iconSize,
  });

  final double horizontalPadding;
  final double verticalPadding;
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
        horizontalPadding: spacing.sm,
        verticalPadding: spacing.xs / 2,
        textSize: AppTextSize.s12,
        iconSize: tokens.iconSize3xs,
      ),
      AppSegmentedSize.regular => _AppSegmentedSizeSpec(
        horizontalPadding: spacing.md,
        verticalPadding: spacing.xs,
        textSize: AppTextSize.s12,
        iconSize: tokens.iconSize2xs,
      ),
    };
  }
}
