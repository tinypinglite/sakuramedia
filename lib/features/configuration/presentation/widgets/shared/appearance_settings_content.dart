import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sakuramedia/app/providers/appearance_providers.dart';
import 'package:sakuramedia/features/configuration/presentation/widgets/shared/language_settings_content.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/theme.dart';
import 'package:sakuramedia/widgets/base/layout/cards/app_settings_group.dart';
import 'package:sakuramedia/widgets/base/layout/surface/app_surface_style.dart';

/// 外观设置的共用内容；移动与桌面使用同一份偏好读写逻辑。
class AppearanceSettingsContent extends ConsumerWidget {
  const AppearanceSettingsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.appSpacing;
    final l10n = AppLocalizations.of(context);
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    final themeMode = appearance.themeMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.appearanceDescription,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s12,
            tone: AppTextTone.secondary,
          ),
        ),
        SizedBox(height: spacing.lg),
        Text(
          l10n.appearanceThemeMode,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.medium,
          ),
        ),
        SizedBox(height: spacing.sm),
        AppSettingsGroup(
          children: [
            AppSettingCell(
              key: const Key('appearance-mode-system'),
              icon: Icons.brightness_auto_outlined,
              title: l10n.appearanceSystem,
              trailing: themeMode == ThemeMode.system
                  ? const _SelectionCheckMark()
                  : null,
              onTap: () => unawaited(controller.setThemeMode(ThemeMode.system)),
            ),
            AppSettingCell(
              key: const Key('appearance-mode-light'),
              icon: Icons.light_mode_outlined,
              title: l10n.appearanceLight,
              trailing: themeMode == ThemeMode.light
                  ? const _SelectionCheckMark()
                  : null,
              onTap: () => unawaited(controller.setThemeMode(ThemeMode.light)),
            ),
            AppSettingCell(
              key: const Key('appearance-mode-dark'),
              icon: Icons.dark_mode_outlined,
              title: l10n.appearanceDark,
              trailing: themeMode == ThemeMode.dark
                  ? const _SelectionCheckMark()
                  : null,
              onTap: () => unawaited(controller.setThemeMode(ThemeMode.dark)),
            ),
          ],
        ),
        SizedBox(height: spacing.xl),
        Text(
          l10n.appearanceThemeColor,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.medium,
          ),
        ),
        SizedBox(height: spacing.sm),
        AppSettingsGroup(
          footer: l10n.appearanceThemeColorFooter,
          children: [
            for (final themeColor in AppThemeColor.values)
              AppSettingCell(
                key: Key('appearance-theme-color-${themeColor.id}'),
                title: themeColor.labelFor(l10n),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ThemeColorSwatch(
                      color: themeColor
                          .forBrightness(Theme.of(context).brightness)
                          .primary,
                    ),
                    if (appearance.themeColor.id == themeColor.id) ...[
                      SizedBox(width: spacing.sm),
                      const _SelectionCheckMark(),
                    ],
                  ],
                ),
                onTap: () => unawaited(controller.setThemeColor(themeColor)),
              ),
          ],
        ),
        SizedBox(height: spacing.xl),
        Text(
          l10n.appearanceSurfaceStyle,
          style: resolveAppTextStyle(
            context,
            size: AppTextSize.s14,
            weight: AppTextWeight.medium,
          ),
        ),
        SizedBox(height: spacing.sm),
        AppSettingsGroup(
          footer: l10n.appearanceSurfaceStyleDescription,
          children: [
            AppSettingCell(
              key: const Key('appearance-surface-liquid'),
              icon: Icons.auto_awesome_rounded,
              title: l10n.appearanceSurfaceLiquid,
              subtitle: l10n.appearanceSurfaceLiquidDescription,
              trailing: appearance.surfaceStyle == AppSurfaceStyle.liquid
                  ? const _SelectionCheckMark()
                  : null,
              onTap: () =>
                  unawaited(controller.setSurfaceStyle(AppSurfaceStyle.liquid)),
            ),
            AppSettingCell(
              key: const Key('appearance-surface-flat'),
              icon: Icons.layers_outlined,
              title: l10n.appearanceSurfaceFlat,
              subtitle: l10n.appearanceSurfaceFlatDescription,
              trailing: appearance.surfaceStyle == AppSurfaceStyle.flat
                  ? const _SelectionCheckMark()
                  : null,
              onTap: () =>
                  unawaited(controller.setSurfaceStyle(AppSurfaceStyle.flat)),
            ),
          ],
        ),
        SizedBox(height: spacing.xl),
        const LanguageSettingsContent(),
      ],
    );
  }
}

class _ThemeColorSwatch extends StatelessWidget {
  const _ThemeColorSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = context.appComponentTokens.iconSizeLg;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.appColors.borderSubtle),
      ),
    );
  }
}

class _SelectionCheckMark extends StatelessWidget {
  const _SelectionCheckMark();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.check_circle_rounded,
      size: context.appComponentTokens.iconSizeMd,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}
