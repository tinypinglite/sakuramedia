import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/app/providers/appearance_providers.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/interaction/app_interactive_surface.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';
import 'package:sakuramedia/widgets/base/overlays/app_glass_anchored_menu.dart';

/// 账户卡里的明暗模式三态切换和主题色菜单。
class SidebarAppearanceMenu extends ConsumerStatefulWidget {
  const SidebarAppearanceMenu({super.key});

  @override
  ConsumerState<SidebarAppearanceMenu> createState() =>
      _SidebarAppearanceMenuState();
}

class _SidebarAppearanceMenuState extends ConsumerState<SidebarAppearanceMenu> {
  final AppGlassAnchoredMenuController _menuController =
      AppGlassAnchoredMenuController();

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(appShellSidebarCollapsedProvider, (_, next) {
      if (next) {
        _menuController.close();
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
    final fill = context.appColors.surfaceCard.withValues(
      alpha: isDark ? 0.06 : 0.34,
    );
    final border = context.appColors.borderSubtle.fadedBy(isDark ? 0.75 : 0.55);
    final buttonSize =
        context.appComponentTokens.iconSizeMd + context.appSpacing.xs * 2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIconButton(
          key: const Key('sidebar-appearance-mode-toggle'),
          icon: Icon(_modeIcon(mode)),
          tooltip: _modeTooltip(mode, l10n),
          semanticLabel: _modeTooltip(mode, l10n),
          iconColor: context.appTextPalette.primary,
          backgroundColor: fill,
          borderColor: border,
          onPressed: () => unawaited(controller.setThemeMode(_nextMode(mode))),
        ),
        SizedBox(width: context.appSpacing.sm),
        AppGlassAnchoredMenu(
          key: const Key('sidebar-theme-color-button'),
          controller: _menuController,
          width: 220,
          minWidth: 220,
          maxWidth: 220,
          estimatedHeight: 40 + AppThemeColor.values.length * 40.0,
          maxHeight: 360,
          borderRadius: context.appRadius.lgBorder,
          triggerBuilder: (context, isOpen, toggle) => Semantics(
            label: l10n.shellThemeColor,
            child: Tooltip(
              message: l10n.shellThemeColor,
              child: AppInteractiveSurface(
                onTap: toggle,
                focusRingRadius: context.appRadius.smBorder,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: context.appRadius.smBorder,
                    border: Border.all(color: border),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: Icon(
                          Icons.palette_outlined,
                          size: context.appComponentTokens.iconSizeMd,
                          color: context.appTextPalette.primary,
                        ),
                      ),
                      Positioned(
                        right: 3,
                        bottom: 3,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: themeColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.appColors.borderSubtle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          panelKey: const Key('sidebar-theme-color-popover'),
          contentBuilder: (context, close) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.appSpacing.md,
                  context.appSpacing.sm,
                  context.appSpacing.md,
                  context.appSpacing.xs,
                ),
                child: Text(
                  l10n.shellThemeColor,
                  style: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: AppTextWeight.medium,
                    tone: AppTextTone.secondary,
                  ),
                ),
              ),
              for (final themeColor in AppThemeColor.values)
                AppGlassMenuRow(
                  key: Key('sidebar-theme-color-${themeColor.id}'),
                  leading: Container(
                    width: context.appComponentTokens.iconSizeLg,
                    height: context.appComponentTokens.iconSizeLg,
                    decoration: BoxDecoration(
                      color: themeColor
                          .forBrightness(Theme.of(context).brightness)
                          .primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.appColors.borderSubtle),
                    ),
                  ),
                  title: Text(themeColor.labelFor(l10n)),
                  titleStyle: resolveAppTextStyle(
                    context,
                    size: AppTextSize.s12,
                    weight: appearance.themeColor.id == themeColor.id
                        ? AppTextWeight.medium
                        : AppTextWeight.regular,
                    tone: appearance.themeColor.id == themeColor.id
                        ? AppTextTone.accent
                        : AppTextTone.secondary,
                  ),
                  selected: appearance.themeColor.id == themeColor.id,
                  showCheckmark: true,
                  minHeight: 40,
                  onTap: () {
                    close();
                    unawaited(controller.setThemeColor(themeColor));
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

ThemeMode _nextMode(ThemeMode mode) => switch (mode) {
  ThemeMode.system => ThemeMode.light,
  ThemeMode.light => ThemeMode.dark,
  ThemeMode.dark => ThemeMode.system,
};

IconData _modeIcon(ThemeMode mode) => switch (mode) {
  ThemeMode.system => Icons.contrast_rounded,
  ThemeMode.light => Icons.light_mode_outlined,
  ThemeMode.dark => Icons.dark_mode_outlined,
};

String _modeTooltip(ThemeMode mode, AppLocalizations l10n) => switch (mode) {
  ThemeMode.system => l10n.shellThemeModeSystem,
  ThemeMode.light => l10n.shellThemeModeLight,
  ThemeMode.dark => l10n.shellThemeModeDark,
};
