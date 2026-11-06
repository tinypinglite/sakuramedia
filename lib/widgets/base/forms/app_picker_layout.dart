import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/media/images/masked_image.dart';
import 'package:sakuramedia/widgets/base/overlays/app_adaptive_modal.dart';

/// 选择器列表的尺寸壳。
///
/// 抽屉里占满剩余高度；桌面弹窗按内容收缩，最高 400。
/// 列表本身仍由调用方构建，保留各自的数据、分页和滚动控制器。
class AppPickerListFrame extends StatelessWidget {
  const AppPickerListFrame({super.key, required this.child, this.isDrawer});

  final Widget child;
  final bool? isDrawer;

  @override
  Widget build(BuildContext context) {
    final drawer =
        isDrawer ?? AppAdaptiveModalShellScope.maybeIsDrawer(context);
    final clippedChild = ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppPickerIosSection.surfaceRadius),
      ),
      child: child,
    );
    if (drawer) {
      return Expanded(child: clippedChild);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 400),
      child: clippedChild,
    );
  }
}

/// iOS grouped list section used by picker bodies.
///
/// The picker chrome is Liquid Glass; the list itself is the opaque,
/// inset-grouped surface iOS uses inside sheets. Separators are inserted here
/// so they can align to the text column even though rows are wrapped by
/// [AppPickerIosRow].
class AppPickerIosSection extends StatelessWidget {
  const AppPickerIosSection({
    super.key,
    required this.children,
    this.header,
    this.dividerIndent,
  });

  final List<Widget> children;
  final Widget? header;
  final double? dividerIndent;

  static const double surfaceRadius = 26;

  @override
  Widget build(BuildContext context) {
    final fontFamily = resolveAppFontFamily(context);
    final childrenWithDividers = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      final child = children[index];
      childrenWithDividers.add(child);
      if (index == children.length - 1 ||
          child is GlassDivider ||
          children[index + 1] is GlassDivider) {
        continue;
      }
      final hasLeading = child is AppPickerIosRow && child.leading != null;
      childrenWithDividers.add(
        GlassDivider(
          indent: hasLeading ? (dividerIndent ?? 56) : 16,
          endIndent: 16,
        ),
      );
    }
    return GlassGroupedSection(
      header: header == null
          ? null
          : DefaultTextStyle.merge(
              style: TextStyle(fontFamily: fontFamily),
              child: header!,
            ),
      surfaceStyle: GlassSurfaceStyle.solid,
      children: childrenWithDividers,
    );
  }
}

/// An iOS grouped-list row with an optional trailing checkmark or accessory.
///
/// Tapping the row toggles it, a tinted checkmark appears at the trailing edge,
/// and the row gives native press feedback with a selection haptic. There is no
/// Material checkbox or card background.
class AppPickerIosRow extends StatelessWidget {
  const AppPickerIosRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailingText,
    this.selected = false,
    this.showCheckmark = false,
    this.trailingIcon,
    this.busy = false,
    this.busyKey,
    this.enabled = true,
    this.onTap,
    this.optionKey,
    this.titleColor,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final String? trailingText;
  final bool selected;
  final bool showCheckmark;
  final Widget? trailingIcon;
  final bool busy;
  final Key? busyKey;
  final bool enabled;
  final VoidCallback? onTap;
  final Key? optionKey;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final mutedColor = context.appTextPalette.muted;
    final accent = Theme.of(context).colorScheme.primary;
    final fontFamily = resolveAppFontFamily(context);
    final trailing = <Widget>[];
    if (trailingText != null && trailingText!.isNotEmpty) {
      trailing.add(
        Text(
          trailingText!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.muted,
          ).copyWith(fontFamily: fontFamily),
        ),
      );
    }
    if (busy) {
      trailing.add(
        cupertino.CupertinoActivityIndicator(
          key: busyKey,
          radius: 8,
          color: mutedColor,
        ),
      );
    } else if (showCheckmark) {
      trailing.add(
        SizedBox(
          width: 20,
          child: selected
              ? Icon(Icons.check_rounded, size: 20, color: accent)
              : null,
        ),
      );
    } else if (trailingIcon != null) {
      trailing.add(trailingIcon!);
    }

    Widget? trailingWidget;
    if (trailing.isNotEmpty) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < trailing.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            trailing[index],
          ],
        ],
      );
    }

    final resolvedSubtitle =
        subtitleWidget ??
        (subtitle != null && subtitle!.trim().isNotEmpty
            ? Text(subtitle!)
            : null);
    return Semantics(
      selected: showCheckmark ? selected : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: GlassListTile(
          key: optionKey,
          leading: leading,
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: resolvedSubtitle,
          trailing: trailingWidget,
          onTap: enabled && !busy
              ? () {
                  HapticFeedback.selectionClick();
                  onTap?.call();
                }
              : null,
          titleStyle:
              resolveAppTextStyle(
                context,
                size: AppTextSize.s16,
                weight: AppTextWeight.regular,
                tone: AppTextTone.primary,
              ).copyWith(
                fontFamily: fontFamily,
                color: enabled
                    ? (titleColor ?? context.appTextPalette.primary)
                    : context.appTextPalette.muted,
              ),
          subtitleStyle: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ).copyWith(fontFamily: fontFamily),
        ),
      ),
    );
  }
}

/// iOS grouped picker 里的行内动作，例如“新建合集并加入”。
class AppPickerIosActionRow extends StatelessWidget {
  const AppPickerIosActionRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.add_circle_outline_rounded,
    this.optionKey,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final Key? optionKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AppPickerIosRow(
      leading: Icon(icon, color: accent),
      title: label,
      titleColor: accent,
      enabled: enabled,
      onTap: onTap,
      optionKey: optionKey,
    );
  }
}

/// Fixed-size cover thumbnail for an iOS grouped picker row.
class AppPickerIosCover extends StatelessWidget {
  const AppPickerIosCover({
    super.key,
    this.url,
    this.width = 56,
    this.height = 32,
  });

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = url?.trim();
    return ClipRRect(
      borderRadius: context.appRadius.smBorder,
      child: SizedBox(
        width: width,
        height: height,
        child: resolvedUrl != null && resolvedUrl.isNotEmpty
            ? MaskedImage(url: resolvedUrl, fit: BoxFit.cover)
            : ColoredBox(color: context.appColors.surfaceMuted),
      ),
    );
  }
}

/// iOS-style loading / empty / error state for picker bodies.
class AppPickerIosState extends StatelessWidget {
  const AppPickerIosState({
    super.key,
    this.title,
    this.message,
    this.loading = false,
    this.onRetry,
    this.retryKey,
    this.actionLabel,
  });

  final String? title;
  final String? message;
  final bool loading;
  final VoidCallback? onRetry;
  final Key? retryKey;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 160,
        child: const Center(
          child: cupertino.CupertinoActivityIndicator(radius: 12),
        ),
      );
    }
    final accent = Theme.of(context).colorScheme.primary;
    final fontFamily = resolveAppFontFamily(context);
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title!.trim().isNotEmpty) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s16,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.primary,
                ).copyWith(fontFamily: fontFamily),
              ),
              if (message != null && message!.trim().isNotEmpty)
                const SizedBox(height: 4),
            ],
            if (message != null)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s14,
                  tone: AppTextTone.secondary,
                ).copyWith(fontFamily: fontFamily),
              ),
            if (onRetry != null) ...[
              const SizedBox(height: 6),
              cupertino.CupertinoButton(
                key: retryKey,
                minimumSize: const Size(0, 44),
                padding: EdgeInsets.symmetric(
                  horizontal: context.appSpacing.md,
                ),
                onPressed: onRetry,
                child: Text(
                  actionLabel ?? appL10n(context).commonRetry,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s16,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.primary,
                  ).copyWith(fontFamily: fontFamily, color: accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Picker 空态/错误态 + 底部行内动作，例如“新建合集并加入”。
class AppPickerIosStateWithAction extends StatelessWidget {
  const AppPickerIosStateWithAction({
    super.key,
    required this.state,
    required this.action,
  });

  final Widget state;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          state,
          AppPickerIosSection(children: <Widget>[action]),
        ],
      ),
    );
  }
}

/// Compact Cupertino action used inside picker section headers.
class AppPickerIosActionButton extends StatelessWidget {
  const AppPickerIosActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.primary;
    final fontFamily = resolveAppFontFamily(context);
    final spacing = context.appSpacing;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          IconTheme(
            data: IconThemeData(size: 18, color: foreground),
            child: icon!,
          ),
          SizedBox(width: spacing.xs),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s14,
              weight: AppTextWeight.medium,
              tone: AppTextTone.primary,
            ).copyWith(fontFamily: fontFamily, color: foreground),
          ),
        ),
      ],
    );
    return cupertino.CupertinoButton(
      minimumSize: const Size(0, 36),
      padding: EdgeInsets.symmetric(horizontal: spacing.xs),
      foregroundColor: foreground,
      onPressed: onPressed,
      child: child,
    );
  }
}

/// Compact iOS filter chip used in the picker header.
class AppPickerIosChip extends StatelessWidget {
  const AppPickerIosChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final labelColor = selected ? accent : context.appTextPalette.primary;
    final fontFamily = resolveAppFontFamily(context);
    final spacing = context.appSpacing;
    return cupertino.CupertinoButton(
      minimumSize: const Size(0, 32),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.md,
        vertical: spacing.xs,
      ),
      color: selected
          ? accent.withValues(alpha: 0.14)
          : cupertino.CupertinoColors.tertiarySystemFill.resolveFrom(context),
      foregroundColor: labelColor,
      borderRadius: context.appRadius.lgBorder,
      onPressed: onPressed,
      child: Text(
        label,
        maxLines: 1,
        style: resolveAppTextStyle(
          context,
          size: AppTextSize.s14,
          weight: selected ? AppTextWeight.semibold : AppTextWeight.regular,
          tone: AppTextTone.primary,
        ).copyWith(fontFamily: fontFamily, color: labelColor),
      ),
    );
  }
}
