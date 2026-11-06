import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/providers/app_shell_providers.dart';
import 'package:sakuramedia/app/providers/appearance_providers.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/actions/app_icon_button.dart';
import 'package:sakuramedia/widgets/base/l10n/app_l10n.dart';

/// 账户卡里的明暗模式三态切换和主题色菜单。
class SidebarAppearanceMenu extends ConsumerStatefulWidget {
  const SidebarAppearanceMenu({super.key});

  @override
  ConsumerState<SidebarAppearanceMenu> createState() =>
      _SidebarAppearanceMenuState();
}

class _SidebarAppearanceMenuState extends ConsumerState<SidebarAppearanceMenu> {
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(appShellSidebarCollapsedProvider, (_, next) {
      if (next && _menuOpen) {
        _menuOpen = false;
        Navigator.of(context, rootNavigator: true).maybePop();
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
        PopupMenuButton<AppThemeColor>(
          key: const Key('sidebar-theme-color-button'),
          tooltip: l10n.shellThemeColor,
          color: context.appColors.surfaceCard,
          surfaceTintColor: Colors.transparent,
          elevation: 12,
          constraints: const BoxConstraints.tightFor(width: 220),
          shape: RoundedRectangleBorder(
            borderRadius: context.appRadius.lgBorder,
            side: BorderSide(color: context.appColors.borderSubtle),
          ),
          onOpened: () => _menuOpen = true,
          onCanceled: () => _menuOpen = false,
          onSelected: (color) {
            _menuOpen = false;
            unawaited(controller.setThemeColor(color));
          },
          itemBuilder: (context) => [
            PopupMenuItem<AppThemeColor>(
              key: const Key('sidebar-theme-color-popover'),
              enabled: false,
              height: 40,
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
              PopupMenuItem<AppThemeColor>(
                key: Key('sidebar-theme-color-${themeColor.id}'),
                value: themeColor,
                child: _ThemeColorRow(
                  color: themeColor,
                  selected: appearance.themeColor.id == themeColor.id,
                ),
              ),
          ],
          child: Semantics(
            label: l10n.shellThemeColor,
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
      ],
    );
  }
}

class _ThemeColorRow extends StatelessWidget {
  const _ThemeColorRow({required this.color, required this.selected});

  final AppThemeColor color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final swatch = color.forBrightness(Theme.of(context).brightness).primary;
    return Row(
      children: [
        Container(
          width: context.appComponentTokens.iconSizeLg,
          height: context.appComponentTokens.iconSizeLg,
          decoration: BoxDecoration(
            color: swatch,
            shape: BoxShape.circle,
            border: Border.all(color: context.appColors.borderSubtle),
          ),
        ),
        SizedBox(width: context.appSpacing.sm),
        Expanded(
          child: Text(
            color.labelFor(l10n),
            style: resolveAppTextStyle(
              context,
              size: AppTextSize.s12,
              weight: selected ? AppTextWeight.medium : AppTextWeight.regular,
              tone: selected ? AppTextTone.accent : AppTextTone.secondary,
            ),
          ),
        ),
        if (selected)
          Icon(
            Icons.check_rounded,
            size: context.appComponentTokens.iconSizeSm,
            color: Theme.of(context).colorScheme.primary,
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
