import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/app/providers/appearance_providers.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/overlays/app_anchored_popover.dart';

/// 桌面侧栏底部的明暗模式切换 + 主题色小浮窗。
///
/// 明暗模式是单个图标的三态循环（跟随系统 → 浅色 → 深色）；主题色点调色盘
/// 向上弹出小色板，选完自动收起。复用设置页同一份 [appearanceProvider]。
class SidebarAppearanceMenu extends ConsumerStatefulWidget {
  const SidebarAppearanceMenu({super.key});

  @override
  ConsumerState<SidebarAppearanceMenu> createState() =>
      _SidebarAppearanceMenuState();
}

class _SidebarAppearanceMenuState extends ConsumerState<SidebarAppearanceMenu> {
  static const double _themeColorDotSize = 6;

  final AppPopoverController _popoverController = AppPopoverController();

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(appShellSidebarCollapsedProvider, (previous, next) {
      if (next) {
        _popoverController.close();
      }
    });

    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    final l10n = appL10n(context);
    final mode = appearance.themeMode;
    final themeColor = appearance.themeColor
        .forBrightness(Theme.of(context).brightness)
        .primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonFill = context.appColors.surfaceCard.withValues(
      alpha: isDark ? 0.06 : 0.34,
    );
    final buttonBorder = context.appColors.borderSubtle.fadedBy(
      isDark ? 0.75 : 0.55,
    );

    return AppAnchoredPopover(
      controller: _popoverController,
      placement: AppPopoverPlacement.aboveEnd,
      animate: true,
      focusOnOpen: true,
      panelWidthBuilder: (overlayContext, _, _) =>
          overlayContext.appSidebarTokens.expandedWidth -
          overlayContext.appSpacing.sm * 2,
      triggerBuilder: (context, _, toggle) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconButton(
            key: const Key('sidebar-appearance-mode-toggle'),
            icon: Icon(_modeIcon(mode)),
            tooltip: _modeTooltip(mode, l10n),
            semanticLabel: _modeTooltip(mode, l10n),
            iconColor: context.appTextPalette.primary,
            backgroundColor: buttonFill,
            borderColor: buttonBorder,
            onPressed: () =>
                unawaited(controller.setThemeMode(_nextMode(mode))),
          ),
          SizedBox(width: context.appSpacing.sm),
          AppIconButton(
            key: const Key('sidebar-theme-color-button'),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.palette_outlined),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: _themeColorDotSize,
                    height: _themeColorDotSize,
                    decoration: BoxDecoration(
                      color: themeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.appColors.borderSubtle),
                    ),
                  ),
                ),
              ],
            ),
            tooltip: l10n.shellThemeColor,
            semanticLabel: l10n.shellThemeColor,
            iconColor: context.appTextPalette.primary,
            backgroundColor: buttonFill,
            borderColor: buttonBorder,
            onPressed: toggle,
          ),
        ],
      ),
      panelBuilder: (overlayContext, layout, close) =>
          _ThemeColorPanel(width: layout.width, onSelected: close),
    );
  }
}

ThemeMode _nextMode(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => ThemeMode.light,
    ThemeMode.light => ThemeMode.dark,
    ThemeMode.dark => ThemeMode.system,
  };
}

IconData _modeIcon(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => Icons.contrast_rounded,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };
}

String _modeTooltip(ThemeMode mode, AppLocalizations l10n) {
  return switch (mode) {
    ThemeMode.system => l10n.shellThemeModeSystem,
    ThemeMode.light => l10n.shellThemeModeLight,
    ThemeMode.dark => l10n.shellThemeModeDark,
  };
}

class _ThemeColorPanel extends ConsumerWidget {
  const _ThemeColorPanel({required this.width, required this.onSelected});

  final double width;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    final l10n = appL10n(context);
    final spacing = context.appSpacing;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: context.appRadius.lgBorder,
        boxShadow: context.appShadows.panel,
      ),
      child: Material(
        color: context.appColors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: context.appRadius.lgBorder,
          side: BorderSide(color: context.appColors.borderSubtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          key: const Key('sidebar-theme-color-popover'),
          width: width,
          padding: EdgeInsets.all(spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.shellThemeColor,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s12,
                  weight: AppTextWeight.medium,
                  tone: AppTextTone.secondary,
                ),
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  for (final themeColor in AppThemeColor.values)
                    Expanded(
                      child: _ThemeColorOption(
                        themeColor: themeColor,
                        selected: appearance.themeColor.id == themeColor.id,
                        onTap: () {
                          unawaited(controller.setThemeColor(themeColor));
                          onSelected();
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeColorOption extends StatefulWidget {
  const _ThemeColorOption({
    required this.themeColor,
    required this.selected,
    required this.onTap,
  });

  final AppThemeColor themeColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ThemeColorOption> createState() => _ThemeColorOptionState();
}

class _ThemeColorOptionState extends State<_ThemeColorOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    final colors = context.appColors;
    final ringSize = context.appComponentTokens.iconSize2xl;
    final swatchColor = widget.themeColor
        .forBrightness(Theme.of(context).brightness)
        .primary;
    final ringColor = widget.selected
        ? Theme.of(context).colorScheme.primary
        : (_hovered ? colors.borderStrong : Colors.transparent);

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.themeColor.labelFor(AppLocalizations.of(context)),
      child: InkWell(
        key: Key('sidebar-theme-color-${widget.themeColor.id}'),
        onTap: widget.onTap,
        onHover: (hovered) {
          if (_hovered == hovered) {
            return;
          }
          setState(() => _hovered = hovered);
        },
        mouseCursor: SystemMouseCursors.click,
        borderRadius: context.appRadius.mdBorder,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: ringSize,
                height: ringSize,
                padding: EdgeInsets.all(spacing.xs - 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 2),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: swatchColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                ),
              ),
              SizedBox(height: spacing.xs),
              Text(
                widget.themeColor.labelFor(AppLocalizations.of(context)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: resolveAppTextStyle(
                  context,
                  size: AppTextSize.s10,
                  weight: widget.selected
                      ? AppTextWeight.medium
                      : AppTextWeight.regular,
                  tone: widget.selected
                      ? AppTextTone.accent
                      : AppTextTone.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
